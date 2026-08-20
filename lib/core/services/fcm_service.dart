import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart'; // 👈 تمت إضافة مكتبة Hive

// 1. الدالة المسؤولة عن استقبال الإشعارات والتطبيق مغلق (Top-Level Function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  
  // 👉 تهيئة Hive وفتح الصندوق لأن هذه الدالة تعمل بمعزل عن التطبيق (في الخلفية)
  await Hive.initFlutter();
  var box = await Hive.openBox('notifications_box');

  // 👉 حفظ الإشعار محلياً إذا كان يحتوي على بيانات
  if (message.notification != null) {
    await box.add({
      'title': message.notification!.title ?? 'تنبيه جديد',
      'body': message.notification!.body ?? '',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  debugPrint("📩 تم استلام وحفظ إشعار في الخلفية: ${message.messageId}");
}

class FCMService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  static Future<void> initializeFCM() async {
    // 2. تسجيل دالة الخلفية
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // طلب صلاحيات الإشعارات من المستخدم
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) {
        print('✅ User granted permission');
      }
      
      String? token = await _firebaseMessaging.getToken();
      if (kDebugMode) {
        print('🔑 FCM Token: $token');
      }

      // 3. الاشتراك في القناة العامة (ليصل إشعار لكل المستخدمين)
      await _firebaseMessaging.subscribeToTopic('all_alerts');
      debugPrint('📢 تم الاشتراك في قناة: all_alerts');

      // 4. الاستماع للإشعارات والتطبيق يعمل في الواجهة
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        if (kDebugMode) {
          print('🔔 Got a message whilst in the foreground: ${message.notification?.title}');
        }
        
        // 👉 حفظ الإشعار محلياً في وضع الاتصال المباشر
        if (message.notification != null) {
          var box = Hive.box('notifications_box'); // الصندوق مفتوح مسبقاً في ملف main
          await box.add({
            'title': message.notification!.title ?? 'تنبيه جديد',
            'body': message.notification!.body ?? '',
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
      });
    }
  }
}
