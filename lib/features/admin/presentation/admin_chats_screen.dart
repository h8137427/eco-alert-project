import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart' as intl;

// ============================================================================
// 1. شاشة قائمة المحادثات (تعرض كل المستخدمين الذين تواصلوا مع الإدارة)
// ============================================================================
class AdminChatsScreen extends StatelessWidget {
  const AdminChatsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: StreamBuilder<QuerySnapshot>(
        // جلب المحادثات وترتيبها حسب الأحدث
        stream: FirebaseFirestore.instance
            .collection('support_chats')
            .orderBy('lastMessageTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('لا توجد رسائل دعم فني حالياً.', style: TextStyle(fontSize: 18, color: Colors.grey)),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final String userId = docs[index].id;
              final String userEmail = data['userEmail'] ?? 'مستخدم غير معروف';
              final String lastMessage = data['lastMessage'] ?? '';
              
              String timeString = '';
              if (data['lastMessageTime'] != null) {
                DateTime dt = (data['lastMessageTime'] as Timestamp).toDate();
                timeString = intl.DateFormat('yyyy-MM-dd kk:mm').format(dt);
              }

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.indigo[100],
                    child: const Icon(Icons.person, color: Colors.indigo),
                  ),
                  title: Text(userEmail, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text(timeString, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  onTap: () {
                    // فتح المحادثة الخاصة بهذا المستخدم
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminChatDetailScreen(
                          userId: userId,
                          userEmail: userEmail,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// 2. شاشة المحادثة الفردية (حيث يرد الأدمن على المستخدم المختار)
// ============================================================================
class AdminChatDetailScreen extends StatefulWidget {
  final String userId;
  final String userEmail;

  const AdminChatDetailScreen({Key? key, required this.userId, required this.userEmail}) : super(key: key);

  @override
  State<AdminChatDetailScreen> createState() => _AdminChatDetailScreenState();
}

class _AdminChatDetailScreenState extends State<AdminChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser; // هذا هو الأدمن الحالي

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || currentUser == null) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    try {
      final db = FirebaseFirestore.instance;
      
      // إضافة الرسالة إلى مجموعة رسائل هذا المستخدم
      await db.collection('support_chats').doc(widget.userId).collection('messages').add({
        'text': messageText,
        'senderId': currentUser!.uid, // UID الخاص بالأدمن
        'senderEmail': 'الإدارة',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // تحديث آخر رسالة في المستند الرئيسي للمستخدم ليظهر في القائمة
      await db.collection('support_chats').doc(widget.userId).update({
        'lastMessage': messageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

    } catch (e) {
      debugPrint("خطأ في إرسال الرد: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('محادثة: ${widget.userEmail.split('@')[0]}', style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('support_chats')
                  .doc(widget.userId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('لا توجد رسائل بعد.'));
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    // إذا كان المُرسل هو الأدمن نفسه
                    final bool isAdmin = data['senderId'] == currentUser?.uid;
                    final String text = data['text'] ?? '';
                    
                    String timeStr = '';
                    if (data['timestamp'] != null) {
                      DateTime dt = (data['timestamp'] as Timestamp).toDate();
                      timeStr = intl.DateFormat('kk:mm').format(dt);
                    }

                    return Align(
                      alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isAdmin ? Colors.indigo[100] : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isAdmin ? Colors.indigo[200]! : Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAdmin ? 'الإدارة' : widget.userEmail.split('@')[0], 
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isAdmin ? Colors.indigo[800] : Colors.grey[700])
                            ),
                            const SizedBox(height: 4),
                            Text(text, style: const TextStyle(color: Colors.black87, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(timeStr, style: const TextStyle(color: Colors.black54, fontSize: 10)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // صندوق إدخال الرسالة
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'اكتب رد الإدارة هنا...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      fillColor: Colors.grey[200],
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.indigo,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
