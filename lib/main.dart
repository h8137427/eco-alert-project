import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // إضافة مصادقة فايربيس
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart'; 
import 'features/alerts/presentation/dashboard_screen.dart';
import 'features/auth/presentation/login_screen.dart'; // استيراد شاشة تسجيل الدخول

void main() async {
  // 1. التأكد من تهيئة فلاتر قبل تنفيذ أي عمليات غير متزامنة
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. تهيئة قاعدة البيانات المحلية (Hive)
  await Hive.initFlutter();
  await Hive.openBox('alerts_cache_box');

  // 3. تهيئة خدمات فايربيس بشكل صحيح باستخدام ملف الإعدادات
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("تنبيه: حدث خطأ أثناء تهيئة Firebase: $e");
  }
  
  // تشغيل واجهة التطبيق
  runApp(const EcoAlertApp());
}

class EcoAlertApp extends StatelessWidget {
  const EcoAlertApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eco Alert',
      debugShowCheckedModeBanner: false, 
      
      // ضبط الثيم الخاص بالتطبيق
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2,
          foregroundColor: Colors.white,
        ),
      ),
      
      // هنا التغيير: نستخدم StreamBuilder لمراقبة حالة المستخدم تلقائياً
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // إذا كان هناك مستخدم مسجل الدخول، اذهب للوحة القيادة
          if (snapshot.hasData) {
            return const DashboardScreen();
          }
          // إذا لم يكن هناك مستخدم، اذهب لشاشة تسجيل الدخول
          return const LoginScreen();
        },
      ),
    );
  }
}