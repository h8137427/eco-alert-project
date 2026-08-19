import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart' as intl;

class UserChatScreen extends StatefulWidget {
  const UserChatScreen({Key? key}) : super(key: key);

  @override
  State<UserChatScreen> createState() => _UserChatScreenState();
}

class _UserChatScreenState extends State<UserChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || currentUser == null) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    try {
      final chatRef = FirebaseFirestore.instance
          .collection('support_chats')
          .doc(currentUser!.uid)
          .collection('messages');

      await chatRef.add({
        'text': messageText,
        'senderId': currentUser!.uid,
        'senderEmail': currentUser!.email ?? 'مستخدم',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // تحديث آخر رسالة وتاريخها في المستند الرئيسي لتسهيل عرضها للأدمن لاحقاً
      await FirebaseFirestore.instance.collection('support_chats').doc(currentUser!.uid).set({
        'lastMessage': messageText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'userEmail': currentUser!.email ?? 'مستخدم',
        'userId': currentUser!.uid,
      }, SetOptions(merge: true));

    } catch (e) {
      debugPrint("خطأ في إرسال الرسالة: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('الدعم الفني')),
        body: const Center(child: Text('الرجاء تسجيل الدخول أولاً للمحادثة')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('التحدث مع الإدارة 💬', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('support_chats')
                  .doc(currentUser!.uid)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('مرحباً بك! كيف يمكننا مساعدتك اليوم؟ أرسل رسالتك وسيرد عليك المسؤولون قريباً.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 16)),
                  );
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final bool isMe = data['senderId'] == currentUser!.uid;
                    final String text = data['text'] ?? '';
                    
                    String timeStr = '';
                    if (data['timestamp'] != null) {
                      DateTime dt = (data['timestamp'] as Timestamp).toDate();
                      timeStr = intl.DateFormat('kk:mm').format(dt);
                    }

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.green[700] : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2, offset: const Offset(0, 1))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(text, style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(timeStr, style: TextStyle(color: isMe ? Colors.white70 : Colors.grey, fontSize: 10)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'اكتب رسالتك هنا...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.indigo),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
