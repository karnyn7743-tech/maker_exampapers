import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart';
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

  /// دالة تشغيل التوليد في الخفاء لمنع تعليق الواجهة
  static Future<String> generatePapersInIsolate({
    required Excel excelData,
    required String qrFolderPath,
    required String selectedClass,
    required String selectedSubject,
    required ByteData fontData,
  }) async {
    return compute(_generateProcess, {
      'excelData': excelData,
      'qrFolderPath': qrFolderPath,
      'selectedClass': selectedClass,
      'selectedSubject': selectedSubject,
      'fontByteData': fontData,
      'targetFolderPath': (await _getPublicDirectory()).path,
    });
  }

  static Future<String> _generateProcess(Map<String, dynamic> params) async {
    final Excel excelData = params['excelData'];
    final String qrFolderPath = params['qrFolderPath'];
    final String selectedClass = params['selectedClass'];
    final String selectedSubject = params['selectedSubject'];
    final ByteData fontByteData = params['fontByteData'];
    final String targetFolderPath = params['targetFolderPath'];

    final pdf = pw.Document();
    final ttfFont = pw.Font.ttf(fontByteData);

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

      if (studentId.isEmpty) continue;

      final qrFile = File("$qrFolderPath/$studentId.png");
      pw.MemoryImage? qrImage;
      if (qrFile.existsSync()) {
        try {
          qrImage = pw.MemoryImage(qrFile.readAsBytesSync());
        } catch (_) {}
      }

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
                              width: 40,
                              height: 40,
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                              ),
                              child: qrImage != null
                                  ? pw.Image(qrImage, fit: pw.BoxFit.cover)
                                  : pw.SizedBox(),
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

    final String cleanSubject = subjectNameString.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final String finalFilePath = "$targetFolderPath/امتحانات_${selectedClass}_$cleanSubject.pdf";

    final file = File(finalFilePath);
    final bytes = await pdf.save();
    await file.writeAsBytes(bytes, flush: true);

    return finalFilePath;
  }
}
