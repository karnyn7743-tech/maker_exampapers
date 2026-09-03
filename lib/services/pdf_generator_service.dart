import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class PdfGeneratorService {
  
  /// الحصول على المسار المباشر لحفظ الملف (تتم في Main Thread)
  static Future<String> _getPublicFolderPath() async {
    Directory? externalDir = await getExternalStorageDirectory();
    String newPath = "";
    List<String> paths = externalDir!.path.split("/");
    for (int x = 1; x < paths.length; x++) {
      String folder = paths[x];
      if (folder != "Android") {
        newPath += "/$folder";
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

  /// الدالة الرئيسية والوحيدة الآمنة للاستدعاء من الهوم سكرين
  static Future<String> generatePapersInIsolate({
    required String excelPath,       // تم تغييرها إلى مسار نصي لحماية الذاكرة
    required String qrFolderPath,    // مسار مجلد صور الـ QR المختار
    required String selectedClass,
    required String selectedSubject, // رقم المادة (من 1 إلى 15)
  }) async {
    
    // 1. استخراج مسار الحفظ والخط في الـ Main Thread
    final String folderPath = await _getPublicFolderPath();
    
    // تحميل الخط العربي كبايتات صريحة لتمريرها بأمان للـ Isolate
    final ByteData fontData = await rootBundle.load("assets/fonts/HacenTunisia.ttf"); // استبدله باسم ملف الخط لديك
    final Uint8List fontBytes = fontData.buffer.asUint8List();

    // 2. تشغيل التوليد بالكامل (قراءة، تصفية، وبناء الـ PDF) في خيط معزول تماماً
    final Map<String, dynamic> result = await compute(_heavyPdfGenerationTask, {
      'excelPath': excelPath,
      'qrFolderPath': qrFolderPath,
      'selectedClass': selectedClass,
      'selectedSubject': selectedSubject,
      'fontBytes': fontBytes,
    });

    if (result['success'] == false) {
      throw Exception(result['error'] ?? "حدث خطأ غير معروف أثناء التوليد");
    }

    final List<Map<String, dynamic>> studentsList = List<Map<String, dynamic>>.from(result['studentsList']);
    final String subjectNameString = result['subjectNameString'];

    // في حال عدم وجود طلاب مطابقين للمعيار المختار
    if (studentsList.isEmpty) {
      throw Exception("لا يوجد طلاب مسجلين في هذا الصف المختار!");
    }

    // 3. بناء وتوليد الـ PDF من بايتات المستند التي تم إعدادها بالخلفية
    final pdf = pw.Document();
    final ttfFont = pw.Font.ttf(fontBytes.buffer.asByteData());

    for (var student in studentsList) {
      // قراءة صورة الـ QR كبايتات إذا كانت موجودة، وإلا نعتمد على دالة الرسم التلقائية كبديل آمن
      pw.MemoryImage? qrImageProvider;
      if (student['qrImageBytes'] != null) {
        qrImageProvider = pw.MemoryImage(student['qrImageBytes'] as Uint8List);
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          theme: pw.ThemeData.withFont(base: ttfFont),
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl, // دعم التوجيه العربي الصحيح
              child: pw.Column(
                cross: pw.CrossAxisAlignment.stretch,
                children: [
                  // ---- الهيدر العلوي الممتد بحسب الصورة المرسلة ----
                  pw.Container(
                    border: pw.Border.all(color: PdfColors.black, width: 1.2),
                    padding: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text("اسم الطالب: ${student['studentName']}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        pw.Text("رقم الجلوس: ${student['studentId']}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),

                  pw.Spacer(), // دفع الفوتر إلى نهاية الصفحة تماماً

                  // ---- الفوتر السفلي (يبدأ من اليسار بفضل الـ RTL) ----
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.start,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      // المربع 1: رقم المادة
                      pw.Container(
                        width: 50,
                        height: 50,
                        alignment: pw.Alignment.center,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.black, width: 1.5),
                        ),
                        child: pw.Text(
                          selectedSubject,
                          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.SizedBox(width: 15),

                      // المربع 2: رمز الاستجابة السريع QR Code المجلوب من المجلد
                      pw.Container(
                        width: 50,
                        height: 50,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.black, width: 1.2),
                        ),
                        child: qrImageProvider != null
                            ? pw.Image(qrImageProvider, fit: pw.BoxFit.fill)
                            : pw.BarcodeWidget( // حل بديل في حال فقدان الصورة من المجلد
                                barcode: pw.Barcode.qrCode(),
                                data: student['qrData']!,
                                drawText: false,
                              ),
                      ),
                      pw.SizedBox(width: 15),

                      // المربع 3: المربع الفارغ الملون بالأزرق الفاتح جداً
                      pw.Container(
                        width: 50,
                        height: 50,
                        decoration: pw.BoxDecoration(
                          color: const PdfColor.fromInt(0xFFE3F2FD), // لون أزرق فاتح جداً مطابق للصورة
                          border: pw.Border.all(color: PdfColors.black, width: 1.2),
                        ),
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

    // 4. حفظ وتسمية ملف الـ PDF النهائي في المجلد المخصص
    final String cleanSubject = subjectNameString.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final String finalFilePath = "$folderPath/امتحانات_${selectedClass}_$cleanSubject.pdf";
    
    final file = File(finalFilePath);
    await file.writeAsBytes(await pdf.save(), flush: true);

    return finalFilePath;
  }

  /// هذه الدالة تنفذ بالكامل في الخلفية المعزولة (Isolate Background) لتقرأ الأكسيل وتجهز مصفوفة الطلاب دون حظر الـ UI
  static Map<String, dynamic> _heavyPdfGenerationTask(Map<String, dynamic> params) {
    try {
      final String excelPath = params['excelPath'];
      final String qrFolderPath = params['qrFolderPath'];
      final String selectedClass = params['selectedClass'];
      final String selectedSubject = params['selectedSubject'];

      // قراءة ملف الأكسيل بأمان داخل الخلفية
      var bytes = File(excelPath).readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);
      String sheetName = excel.tables.keys.first;
      var sheet = excel.tables[sheetName]!;

      List<Map<String, dynamic>> studentsList = [];
      String subjectNameString = "مادة_$selectedSubject";

      // حساب رقم عمود المادة (المواد تبدأ من العمود e وهو الفهرس 4)
      // المعادلة: الفهرس = 4 + (رقم المادة - 1)
      int targetSubjectColumn = 4 + (int.parse(selectedSubject) - 1);

      if (sheet.maxRows > 0 && targetSubjectColumn < sheet.maxColumns) {
        var headerValue = sheet.rows.first[targetSubjectColumn]?.value;
        if (headerValue != null && headerValue.toString().trim().isNotEmpty) {
          subjectNameString = headerValue.toString().trim();
        }
      }

      // معالجة وحصر الطلاب المطابقين للشروط
      for (int i = 1; i < sheet.maxRows; i++) {
        var row = sheet.rows[i];
        if (row.isEmpty) continue;

        // استخراج البيانات بحسب تحديد الأعمدة المطلوبة
        String seatNumber = row.length > 0 && row[0]?.value != null ? row[0]!.value.toString().trim() : ""; // العمود A (رقم الجلوس)
        String studentName = row.length > 1 && row[1]?.value != null ? row[1]!.value.toString().trim() : "طالب مجهول"; // العمود B
        String className = row.length > 2 && row[2]?.value != null ? row[2]!.value.toString().trim() : ""; // العمود C (الصف)

        // التحقق من شرط الصف المختار وتوفر رقم الجلوس
        if (className != selectedClass || seatNumber.isEmpty) continue;

        // محاولة جلب بايتات صورة الـ QR من المجلد المخصص
        Uint8List? qrImageBytes;
        File qrFile = File("$qrFolderPath/$seatNumber.png");
        if (!qrFile.existsSync()) {
          qrFile = File("$qrFolderPath/$seatNumber.jpg"); // تجربة امتداد آخر
        }

        if (qrFile.existsSync()) {
          qrImageBytes = qrFile.readAsBytesSync();
        }

        studentsList.add({
          'studentId': seatNumber,
          'studentName': studentName,
          'qrData': seatNumber,
          'qrImageBytes': qrImageBytes, 
        });
      }

      return {
        'success': true,
        'studentsList': studentsList,
        'subjectNameString': subjectNameString,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
