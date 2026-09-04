import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/activation_service.dart';
import 'home_screen.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final TextEditingController _codeController = TextEditingController();
  String _deviceId = "جاري التحميل...";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
  }

  Future<void> _loadDeviceId() async {
    String id = await ActivationService.getDeviceId();
    setState(() {
      _deviceId = id;
    });
  }

  Future<void> _activate() async {
    if (_codeController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    bool success = await ActivationService.verifyAndActivate(_codeController.text);

    setState(() => _isLoading = false);

    if (success) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("كود التفعيل غير صحيح!", textAlign: TextAlign.center),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("تفعيل التطبيق"),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 70, color: Colors.blue),
              const SizedBox(height: 20),
              const Text(
                "هذا التطبيق يتطلب تفعيلاً للعمل على هذا الجهاز",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 25),

              // عرض معرف الجهاز
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[400]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        "معرّف الجهاز:\n$_deviceId",
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _deviceId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("تم نسخ معرّف الجهاز")),
                        );
                      },
                    )
                  ],
                ),
              ),

              const SizedBox(height: 25),

              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: "أدخل مفتاح التفعيل",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.key),
                ),
              ),

              const SizedBox(height: 25),

              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _activate,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Colors.blue,
                      ),
                      child: const Text(
                        "تفعيل التطبيق",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
