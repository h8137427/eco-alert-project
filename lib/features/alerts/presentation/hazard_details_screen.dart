import 'package:flutter/material.dart';

class HazardDetailsScreen extends StatefulWidget {
  final Map<dynamic, dynamic> alert;
  const HazardDetailsScreen({Key? key, required this.alert}) : super(key: key);

  @override
  State<HazardDetailsScreen> createState() => _HazardDetailsScreenState();
}

class _HazardDetailsScreenState extends State<HazardDetailsScreen> {
  final TextEditingController _chatController = TextEditingController();

  List<String> _getSafetyInstructions(String type) {
    if (type.toLowerCase().contains('earthquake') || type == 'زلزال') {
      return [
        'ابتعد عن النوافذ والجدران الخارجية.',
        'انزل على الأرض واختبئ تحت طاولة متينة.',
        'لا تستخدم المصاعد أبداً.'
      ];
    } else if (type == 'حريق') {
      return [
        'ابقَ منخفضاً لتجنب الدخان.',
        'ضع قطعة قماش مبللة على أنفك.',
        'لا تستخدم المصعد، استخدم السلالم.'
      ];
    } else if (type == 'تلوث' || type == 'تلوث غازي') {
      return [
        'ابق في الداخل وأغلق النوافذ والأبواب.',
        'استخدم أجهزة تنقية الهواء إن وجدت.',
        'ارتدِ كمامة مخصصة عند الخروج للضرورة.'
      ];
    }
    return ['يرجى توخي الحذر والابتعاد عن منطقة الخطر. اتبع تعليمات الجهات الرسمية.'];
  }

  void _handleChatSubmit(String query) {
    if (query.trim().isEmpty) return;
    
    String response = "يرجى مراجعة الإرشادات أعلاه. إذا كنت في خطر مباشر، اتصل بالطوارئ فوراً!";
    if (query.contains('حريق') || query.contains('نار') || query.contains('دخان')) {
      response = 'بخصوص الحريق: ابقَ منخفضاً لتجنب استنشاق الدخان، غطِ أنفك بقطعة قماش مبللة، واخرج فوراً عبر السلالم، لا تستخدم المصعد!';
    } else if (query.contains('زلزال') || query.contains('هزة')) {
      response = 'بخصوص الزلزال: اختبئ فوراً تحت طاولة متينة، تمسك جيداً، ولا تتحرك من مكانك حتى يتوقف الاهتزاز!';
    }
    
    showDialog(
      context: context, 
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.smart_toy, color: Colors.blue), 
            SizedBox(width: 10), 
            Text('المساعد الذكي')
          ]
        ),
        content: Text(response, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('فهمت'))
        ],
      )
    );
    _chatController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.alert['title'] ?? 'تفاصيل التنبيه';
    final String type = widget.alert['type'] ?? 'غير معروف';
    final String severity = widget.alert['severity'] ?? 'low';
    final String location = widget.alert['location_name'] ?? 'موقع غير معروف';
    final String source = widget.alert['source'] ?? 'غير محدد';
    
    Color severityColor = Colors.green;
    if (severity == 'high') severityColor = Colors.red;
    if (severity == 'medium') severityColor = Colors.orange;

    List<String> instructions = _getSafetyInstructions(type);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('تفاصيل الخطر', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: severityColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: severityColor, size: 40),
                        const SizedBox(width: 10),
                        Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const Divider(height: 30),
                    _buildInfoRow(Icons.category, 'النوع:', type),
                    const SizedBox(height: 10),
                    _buildInfoRow(Icons.location_on, 'الموقع:', location),
                    const SizedBox(height: 10),
                    _buildInfoRow(Icons.satellite, 'المصدر:', source),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            const Text('🛡️ إرشادات السلامة:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...instructions.map((inst) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(inst, style: const TextStyle(fontSize: 16))),
                ],
              ),
            )).toList(),

            const SizedBox(height: 30),
            
            const Divider(),
            const Text('🤖 مساعد الطوارئ (Chatbot):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            TextField(
              controller: _chatController,
              decoration: InputDecoration(
                hintText: 'اسأل عن إجراءات السلامة (مثال: ماذا أفعل في الحريق؟)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.chat_bubble_outline),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: () => _handleChatSubmit(_chatController.text),
                ),
              ),
              onSubmitted: _handleChatSubmit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[700]),
        const SizedBox(width: 8),
        Text('$label ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
      ],
    );
  }
}