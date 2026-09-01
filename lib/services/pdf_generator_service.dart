import 'dart:io';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class PdfGeneratorService {
  /// استخراج مسار مجلد الحفظ العام المباشر (Download/درجات الطلاب)
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

  static Future<String> generatePapers({
    required Excel excelData,
    required String qrFolderPath,
    required String selectedClass,
    required String selectedSubject,
    String? outputPath,
  }) async {
    final pdf = pw.Document();

    // تحميل الخط العربي مع معالجة الاستثناء في حال عدم وجود الملف
    pw.Font ttfFont;
    try {
      final fontData = await rootBundle.load("assets/fonts/Amiri_Regular.ttf");
      ttfFont = pw.Font.ttf(fontData);
    } catch (e) {
      // استخدام خط نسبي افتراضي عند تعذر تحميل خط الملفات
      ttfFont = pw.Font.ttf(await rootBundle.load("packages/pdf/fonts/Roboto-Regular.ttf"));
    }

    String sheetName = excelData.tables.keys.first;
    var sheet = excelData.tables[sheetName]!;

    String subjectNameString = "مادة_$selectedSubject";
    try {
      int colIndex = int.parse(selectedSubject) + 3; // العمود المخصص للمادة
      if (sheet.maxRows > 0 && colIndex < sheet.maxColumns) {
        var headerCellValue = sheet.rows.first[colIndex]?.value;
        if (headerCellValue != null && headerCellValue.toString().trim().isNotEmpty) {
          subjectNameString = headerCellValue.toString().trim();
        }
      }
    } catch (_) {}

    // التكرار على جميع صفوف الطلاب (ابتداءً من الصف الثاني)
    for (int i = 1; i < sheet.maxRows; i++) {
      var row = sheet.rows[i];
      if (row.isEmpty) continue;

      // قراءة العمود 0 (رقم القيد/ID) والعمود 1 (اسم الطالب)
      String studentId = row.length > 0 && row[0]?.value != null ? row[0]!.value.toString().trim() : "";
      String studentName = row.length > 1 && row[1]?.value != null ? row[1]!.value.toString().trim() : "طالب مجهول";

      // تجاوز الصفوف الفارغة من رقم القيد
      if (studentId.isEmpty) continue;

      // جلب صورة הـ QR بالاعتماد على رقم القيد (ID)
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
                    // شريط بيانات الطالب في أعلى الورقة
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

                    // شريط مربعات الكنترول والـ QR في أسفل الورقة
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.start,
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            // مربع رقم المادة
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

                            // مربع رمز الـ QR
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

                            // مربع إدخال الدرجة الشفاف
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

    // تحديد مسار الحفظ المباشر النهائي في مجلد درجات الطلاب
    final Directory targetFolder = await _getPublicDirectory();
    final String cleanSubjectName = subjectNameString.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final String finalFileName = "${targetFolder.path}/امتحانات_${selectedClass}_$cleanSubjectName.pdf";
    
    final file = File(finalFileName);
    final pdfBytes = await pdf.save();
    await file.writeAsBytes(pdfBytes, flush: true);

    return finalFileName;
  }
}
