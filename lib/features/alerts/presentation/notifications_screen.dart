import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart' as intl;

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('سجل الإشعارات 🔔', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'مسح كل الإشعارات',
            onPressed: () {
              _showClearDialog(context);
            },
          )
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box('notifications_box').listenable(),
        builder: (context, Box box, _) {
          if (box.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('لا توجد إشعارات سابقة حتى الآن.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          // عكس القائمة لعرض الإشعارات الأحدث في الأعلى
          final notifications = box.values.toList().reversed.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index] as Map<dynamic, dynamic>;
              final String title = notif['title'] ?? 'تنبيه جديد';
              final String body = notif['body'] ?? '';
              final String timeString = notif['timestamp'] ?? '';

              String displayTime = '';
              if (timeString.isNotEmpty) {
                try {
                  DateTime dt = DateTime.parse(timeString);
                  displayTime = intl.DateFormat('yyyy-MM-dd – kk:mm').format(dt);
                } catch (e) {
                  displayTime = timeString;
                }
              }

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: const CircleAvatar(
                    backgroundColor: Colors.orangeAccent,
                    child: Icon(Icons.notifications_active, color: Colors.white),
                  ),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text(body, style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 8),
                      Text(displayTime, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // نافذة تأكيد قبل مسح الإشعارات
  void _showClearDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مسح الإشعارات'),
        content: const Text('هل أنت متأكد أنك تريد مسح جميع الإشعارات المسجلة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Hive.box('notifications_box').clear();
              Navigator.pop(context);
            },
            child: const Text('مسح الكل'),
          )
        ],
      ),
    );
  }
}
