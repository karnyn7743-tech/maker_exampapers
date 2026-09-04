import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ActivationService {
  static const String _activationKey = "is_app_activated";
  // مفتاح سري خاص بك لتشفير كود التفعيل (لا تشاركه مع أحد)
  static const String _secretSalt = "ZulQarnain_Exam_App_2026_SecretKey";

  /// الحصول على معرّف الجهاز الفريد
  static Future<String> getDeviceId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String deviceId = "UNKNOWN_DEVICE";

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id; // معرّف الأندرويد الفريد
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? "UNKNOWN_IOS";
      }
    } catch (e) {
      deviceId = "ERROR_GETTING_ID";
    }

    return deviceId;
  }

  /// توليد كود التفعيل الصحيح بناءً على معرّف الجهاز والمفتاح السري
  static Future<String> generateActivationCode(String deviceId) async {
    final bytes = utf8.encode("$deviceId$_secretSalt");
    final digest = sha256.convert(bytes);
    // اقتطاع أول 8 أرقام/حروف وتحويلها لأحرف كبيرة لسهولة كتابتها
    return digest.toString().substring(0, 8).toUpperCase();
  }

  /// التحقق مما إذا كان التطبيق مفاعلاً مسبقاً
  static Future<bool> isActivated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_activationKey) ?? false;
  }

  /// تفعيل التطبيق وتخزين الحالة
  static Future<bool> verifyAndActivate(String inputCode) async {
    String deviceId = await getDeviceId();
    String correctCode = await generateActivationCode(deviceId);

    if (inputCode.trim().toUpperCase() == correctCode) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_activationKey, true);
      return true;
    }
    return false;
  }
}
