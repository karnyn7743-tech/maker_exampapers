import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class PdfGeneratorService {
  /// الحصول على المسار المباشر (تتم في Main Thread حصراً)
  static Future<String> _getPublicFolderPath() async {
    Directory? externalDir = await getExternalStorageDirectory();
    String newPath = "";
    List<String> paths = externalDir!.path.split("/");
    for (int x = 1; x < paths.length; x++) {
      String folder = paths[x];
      if (folder != "Android") {
        newPath += "/" + folder;
      } else {
        break;
      }
    }

    Directory targetDir = Directory("$newPath/Download/درجات الطلاب");
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    return targetDir.path;
  }

  static Future<String> generatePapersInIsolate({
    required Excel excelData,
    required String selectedClass,
    required String selectedSubject,
    required ByteData fontData,
  }) async {
    // 1. استخراج المسار الأساسي في Main Thread لتجنب الانهيار الصامت للـ Isolate
    final String folderPath = await _getPublicFolderPath();

    // 2. قراءة بيانات الأكسيل كنصوص خفيفة جداً بدلاً من إرسال كائنات معقدة
    String sheetName = excelData.tables.keys.first;
    var sheet = excelData.tables[sheetName]!;

    List<Map<String, String>> studentsList = [];
    String subjectNameString = "مادة_$selectedSubject";

    try {
      int colIndex = int.parse(selectedSubject) + 3;
      if (sheet.maxRows > 0 && colIndex < sheet.maxColumns) {
        var headerCellValue = sheet.rows.first[colIndex]?.value;
        if (headerCellValue != null && headerCellValue.toString().trim().isNotEmpty) {
          subjectNameString = headerCellValue.toString().trim();
        }
      }
    } catch (_) {}

    for (int i = 1; i < sheet.maxRows; i++) {
      var row = sheet.rows[i];
      if (row.isEmpty) continue;

      String studentId = row.length > 0 && row[0]?.value != null ? row[0]!.value.toString().trim() : "";
      String studentName = row.length > 1 && row[1]?.value != null ? row[1]!.value.toString().trim() : "طالب مجهول";
      String secretCode = row.length > 3 && row[3]?.value != null ? row[3]!.value.toString().trim() : "";

      String qrData = secretCode.isNotEmpty ? secretCode : studentId;
      if (qrData.isEmpty) continue;

      studentsList.add({
        'studentId': studentId,
        'studentName': studentName,
        'qrData': qrData,
      });
    }

    final String cleanSubject = subjectNameString.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final String finalFilePath = "$folderPath/امتحانات_${selectedClass}_$cleanSubject.pdf";

    // 3. إرسال بيانات نصية وبايتات صريحة فقط للـ Isolate
    final Uint8List pdfBytes = await compute(_generatePdfBytes, {
      'studentsList': studentsList,
      'selectedSubject': selectedSubject,
      'fontBytes': fontData.buffer.asUint8List(),
    });

    // 4. كتابة الملف وحفظه على القرص يتم في Main Thread
    final file = File(finalFilePath);
    await file.writeAsBytes(pdfBytes, flush: true);

    return finalFilePath;
  }

  /// دالة توليد البايتات فقط داخل الـ Isolate
  static Future<Uint8List> _generatePdfBytes(Map<String, dynamic> params) async {
    final List<Map<String, String>> studentsList = List<Map<String, String>>.from(params['studentsList']);
    final String selectedSubject = params['selectedSubject'];
    final Uint8List fontBytes = params['fontBytes'];

    final pdf = pw.Document();
    final ttfFont = pw.Font.ttf(fontBytes.buffer.asByteData());

    for (var student in studentsList) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: ttfFont),
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Container(
                padding: const pw.EdgeInsets.all(20),
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    // أعلى الورقة
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.start,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey400, width: 1),
                          ),
                          child: pw.Row(
                            children: [
                              pw.Text("اسم الطالب: ${student['studentName']}", style: const pw.TextStyle(fontSize: 12)),
                              pw.SizedBox(width: 20),
                              pw.Text("رقم القيد: ${student['studentId']}", style: const pw.TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),

                    pw.Spacer(),

                    // أسفل الورقة
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.start,
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Container(
                              width: 40,
                              height: 40,
                              alignment: pw.Alignment.center,
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: PdfColors.black, width: 1.5),
                              ),
                              child: pw.Text(
                                selectedSubject,
                                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                              ),
                            ),
                            pw.SizedBox(width: 10),

                            pw.Container(
                              width: 45,
                              height: 45,
                              padding: const pw.EdgeInsets.all(2),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                              ),
                              child: pw.BarcodeWidget(
                                barcode: pw.Barcode.qrCode(),
                                data: student['qrData']!,
                                drawText: false,
                              ),
                            ),
                            pw.SizedBox(width: 10),

                            pw.Container(
                              width: 40,
                              height: 40,
                              decoration: pw.BoxDecoration(
                                color: const PdfColor.fromInt(0xFFEBF3F9),
                                border: pw.Border.all(color: PdfColors.blueAccent, width: 1.5),
                              ),
                              child: pw.SizedBox(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    return await pdf.save();
  }
}
