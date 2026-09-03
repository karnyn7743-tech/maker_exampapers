import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class PdfGeneratorService {
  static Future<Directory> _getPublicDirectory() async {
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
    return targetDir;
  }

  static Future<String> generatePapersInIsolate({
    required Excel excelData,
    required String selectedClass,
    required String selectedSubject,
    required ByteData fontData,
  }) async {
    // تحويل الأكسيل والخط إلى Uint8List لضمان سهولة نقلها عبر الـ Isolate
    final Uint8List excelBytes = Uint8List.fromList(excelData.encode() ?? []);
    final Uint8List fontBytes = fontData.buffer.asUint8List();
    final String targetPath = (await _getPublicDirectory()).path;

    return compute(_generateProcess, {
      'excelBytes': excelBytes,
      'selectedClass': selectedClass,
      'selectedSubject': selectedSubject,
      'fontBytes': fontBytes,
      'targetFolderPath': targetPath,
    });
  }

  static Future<String> _generateProcess(Map<String, dynamic> params) async {
    final Uint8List excelBytes = params['excelBytes'];
    final String selectedClass = params['selectedClass'];
    final String selectedSubject = params['selectedSubject'];
    final Uint8List fontBytes = params['fontBytes'];
    final String targetFolderPath = params['targetFolderPath'];

    // إعادة فك ملف الأكسيل والخط داخل الـ Isolate المستقل
    final Excel excelData = Excel.decodeBytes(excelBytes);
    final pdf = pw.Document();
    final ttfFont = pw.Font.ttf(fontBytes.buffer.asByteData());

    String sheetName = excelData.tables.keys.first;
    var sheet = excelData.tables[sheetName]!;

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
                    // أعلى الورقة: بيانات الطالب
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
                              pw.Text("اسم الطالب: $studentName", style: const pw.TextStyle(fontSize: 12)),
                              pw.SizedBox(width: 20),
                              pw.Text("رقم القيد: $studentId", style: const pw.TextStyle(fontSize: 12)),
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
                            // مربع المادة
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

                            // رمز ה-QR
                            pw.Container(
                              width: 45,
                              height: 45,
                              padding: const pw.EdgeInsets.all(2),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                              ),
                              child: pw.BarcodeWidget(
                                barcode: pw.Barcode.qrCode(),
                                data: qrData,
                                drawText: false,
                              ),
                            ),
                            pw.SizedBox(width: 10),

                            // مربع إدخال الدرجة
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

    final String cleanSubject = subjectNameString.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final String finalFilePath = "$targetFolderPath/امتحانات_${selectedClass}_$cleanSubject.pdf";

    final file = File(finalFilePath);
    final bytes = await pdf.save();
    await file.writeAsBytes(bytes, flush: true);

    return finalFilePath;
  }
}
