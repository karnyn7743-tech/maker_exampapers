import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/home_screen.dart'; // استيراد الشاشة الرئيسية المستقلة الجديدة
import 'screens/activation_screen.dart'; // استيراد شاشة التفعيل
import 'services/activation_service.dart'; // استيراد خدمة التفعيل

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // طلب صلاحيات الوصول إلى الذاكرة والتخزين عند بدء التشغيل
  await _requestPermissions();

  // فحص حالة التفعيل المسبق للتطبيق
  bool isActivated = await ActivationService.isActivated();
  
  runApp(MyApp(isActivated: isActivated));
}

class MyApp extends StatelessWidget {
  final bool isActivated;
  const MyApp({super.key, required this.isActivated});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ذو القرنين الهاشمي لتوليد أوراق الاختبارات',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true, // تم تعديل الخيار هنا لدعم إصدارات Flutter الحديثة
      ),
      debugShowCheckedModeBanner: false,
      // التوجيه الشفاف: فتح الواجهة الرئيسية مباشرة إذا كان مفصّلاً، أو التوجيه لشاشة التفعيل
      home: isActivated ? const HomeScreen() : const ActivationScreen(),
    );
  }
}

// دالة فحص وتأكيد الصلاحيات لضمان حفظ الـ PDF بدون قيود النظام
Future<void> _requestPermissions() async {
  var status = await Permission.storage.status;
  if (!status.isGranted) {
    await Permission.storage.request();
  }
}
