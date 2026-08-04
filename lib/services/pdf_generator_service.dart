import 'dart:io';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfGeneratorService {
  static Future<String> generatePapers({
    required Excel excelData,
    required String qrFolderPath,
    required String selectedClass,
    required String selectedSubject,
    required String outputPath,
  }) async {
    final pdf = pw.Document();

    final fontData = await rootBundle.load("assets/fonts/Amiri_Regular.ttf");
    final ttfFont = pw.Font.ttf(fontData);

    String sheetName = excelData.tables.keys.first;
    var sheet = excelData.tables[sheetName]!;

    String subjectNameString = "مادة";
    try {
      int colIndex = int.parse(selectedSubject) + 3;
      // استخدام maxColumns بدلاً من maxCols
      if (sheet.maxRows > 0 && colIndex < sheet.maxColumns) {
        var headerCellValue = sheet.rows.first[colIndex]?.value;
        if (headerCellValue != null) {
          subjectNameString = headerCellValue.toString().trim();
        }
      }
    } catch (_) {
      subjectNameString = "مادة_$selectedSubject";
    }

    for (int i = 1; i < sheet.maxRows; i++) {
      var row = sheet.rows[i];
      if (row.isEmpty || row[0]?.value == null) continue;

      String studentName = row[0]?.value?.toString().trim() ?? "طالب مجهول";
      String studentId = row[1]?.value?.toString().trim() ?? "0000";

      final qrFile = File("$qrFolderPath/$studentId.png");
      pw.MemoryImage? qrImage;
      if (await qrFile.exists()) {
        qrImage = pw.MemoryImage(await qrFile.readAsBytes());
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
                            border: pw.Border.all(color: PdfColors.grey300, width: 1),
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
                                style: pw.TextStyle(font: ttfFont, fontSize: 16, fontWeight: pw.FontWeight.bold),
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

    final String finalFileName = "$outputPath/امتحانات_${selectedClass}_$subjectNameString.pdf";
    final file = File(finalFileName);
    await file.writeAsBytes(await pdf.save());

    return finalFileName;
  }
}
