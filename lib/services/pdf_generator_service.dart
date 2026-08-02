import 'dart:io';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfGeneratorService {
  static Future<String> generatePapers({
    required Excel excelData,
    required String qrFolderPath,
    required String selectedClass,      // الصف المختار (مثلاً: "خامس")
    required String selectedSubject,    // رقم المادة الترتيبي كـ String (مثلاً: "1")
    required String outputPath,         // مسار المجلد الرئيسي للدرجات
    required String outputFileName,     // اسم الملف المخصص تلقائياً (مثلاً: "خامس - اللغة العربية")
  }) async {
    final pdf = pw.Document();

    // 1. تحميل خط الأميري لضمان ظهور العربية بشكل سليم وثابت
    final fontData = await rootBundle.load("assets/fonts/Amiri_Regular.ttf");
    final ttfFont = pw.Font.ttf(fontData);

    String sheetName = excelData.tables.keys.first;
    var sheet = excelData.tables[sheetName]!;

    // 2. تحسين السرعة: قراءة أسماء ملفات الـ QR مرة واحدة في الذاكرة
    final Directory qrDir = Directory(qrFolderPath);
    Set<String> availableQrFiles = {};
    if (await qrDir.exists()) {
      availableQrFiles = qrDir
          .listSync()
          .map((entity) => entity.path.split('/').last.toLowerCase())
          .toSet();
    }

    int generatedCount = 0;
    final String targetClass = selectedClass.trim().toLowerCase();

    for (int i = 1; i < sheet.maxRows; i++) {
      var row = sheet.rows[i];
      if (row.isEmpty || row.length < 3 || row[0]?.value == null) continue;

      // قراءة الصف الدراسي من العمود C للفلترة
      String studentClass = row[2]?.value?.toString().trim().toLowerCase() ?? "";

      // الفلترة بحسب الصف المحدد
      if (studentClass != targetClass) continue;

      // قراءة بيانات الطالب
      String studentId = row[0]?.value?.toString().trim() ?? "0000";
      String studentName = row[1]?.value?.toString().trim() ?? "طالب مجهول";

      // التحقق الفوري من صورة الـ QR
      pw.MemoryImage? qrImage;
      if (availableQrFiles.contains("${studentId.toLowerCase()}.png")) {
        final qrFile = File("$qrFolderPath/$studentId.png");
        qrImage = pw.MemoryImage(await qrFile.readAsBytes());
      }

      generatedCount++;

      // إضافة الصفحة بالتصميم المطلوب
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.copyWith(
            marginTop: 4 * PdfPageFormat.mm,
            marginBottom: 4 * PdfPageFormat.mm,
            marginLeft: 4 * PdfPageFormat.mm,
            marginRight: 4 * PdfPageFormat.mm,
          ),
          theme: pw.ThemeData.withFont(
            base: ttfFont,
            bold: ttfFont,
          ).copyWith(
            defaultTextStyle: pw.TextStyle(font: ttfFont, fontSize: 14),
          ),
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // ====== أعلى يمين الصفحة (بيانات الطالب) ======
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.start,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey400, width: 1),
                        ),
                        child: pw.Row(
                          children: [
                            pw.Text("اسم الطالب: $studentName", style: pw.TextStyle(font: ttfFont, fontSize: 14)),
                            pw.SizedBox(width: 25),
                            pw.Text("رقم القيد: $studentId", style: pw.TextStyle(font: ttfFont, fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  pw.Spacer(),

                  // ====== أسفل يسار الصفحة (المربعات الخاصة بالرصد والـ QR) ======
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      // 1. [مربع رقم المادة الترتيبي 40x40]
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

                      // 2. [منطقة الـ QR بمقاس 40x40]
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

                      // 3. [مربع رصد الدرجة أزرق فاتح بمقاس 40x40]
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
            );
          },
        ),
      );
    }

    if (generatedCount == 0) {
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Center(
            child: pw.Text(
              "لم يتم العثور على طلاب مسجلين في صف: $selectedClass",
              style: pw.TextStyle(font: ttfFont, fontSize: 18),
              textDirection: pw.TextDirection.rtl,
            ),
          ),
        ),
      );
    }

    // بناء مسار الحفظ المباشر بالتنسيق المحدد: /Download/درجات الطلاب/اسم الصف - اسم المادة.pdf
    final String finalFileName = "$outputPath/$outputFileName.pdf";
    final file = File(finalFileName);
    await file.writeAsBytes(await pdf.save());

    return finalFileName;
  }
}
