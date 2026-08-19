import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // إضافة مكتبة المصادقة للوصول للمستخدم الحالي

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // متغيرات التصفية (Filters)
  String _selectedSeverity = 'الكل'; // 'الكل', 'high', 'medium', 'low'
  String _selectedType = 'الكل';     // 'الكل', 'حريق', 'زلزال', 'فيضان', 'تلوث'
  bool _showVerifiedOnly = true;     // إظهار الموثق فقط (إخفاء المعلق)
  
  // المتغيرات الجديدة الخاصة بفلتر "المواقع المفضلة"
  bool _showNearFavoritesOnly = false; 
  final Distance _distanceCalc = const Distance(); // أداة حساب المسافة الجغرافية

  // دالة للتحقق من خلو قائمة المواقع المفضلة وتنبيه المستخدم
  void _checkFavoritesEmpty() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final List<dynamic> locs = doc.data()?['savedLocations'] ?? [];
    
    if (locs.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد مواقع مفضلة محفوظة حالياً. يمكنك إضافتها من ملفك الشخصي.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // دالة لجلب ودمج البيانات من فايربيز مع تطبيق الفلاتر
  Stream<List<Marker>> _getFilteredMarkers() {
    // نجلب البيانات من مجموعة المخاطر الرسمية
    Stream<QuerySnapshot> hazardsStream = FirebaseFirestore.instance.collection('environmental_hazards').snapshots();
    // نجلب البيانات من مجموعة بلاغات المجتمع
    Stream<QuerySnapshot> reportsStream = FirebaseFirestore.instance.collection('community_reports').snapshots();

    // ندمج وندير البيانات
    return hazardsStream.asyncMap((hazardsSnapshot) async {
      final reportsSnapshot = await reportsStream.first;
      
      // جلب المواقع المفضلة للمستخدم إذا كان الفلتر مفعلاً
      List<dynamic> savedLocations = [];
      final user = FirebaseAuth.instance.currentUser;
      if (_showNearFavoritesOnly && user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          savedLocations = userDoc.data()?['savedLocations'] ?? [];
        }
      }

      List<Marker> markers = [];
      List<QueryDocumentSnapshot> allDocs = [];
      
      allDocs.addAll(hazardsSnapshot.docs);
      allDocs.addAll(reportsSnapshot.docs);

      for (var doc in allDocs) {
        final data = doc.data() as Map<String, dynamic>;
        
        final String type = data['type'] ?? '';
        final String severity = data['severity'] ?? 'low';
        final String status = data['status'] ?? 'verified'; // الافتراضي للمخاطر الرسمية أنها موثقة
        final geo = data['coordinates'];

        if (geo == null || geo['latitude'] == null || geo['longitude'] == null) continue;
        
        final double lat = (geo['latitude'] as num).toDouble();
        final double lng = (geo['longitude'] as num).toDouble();

        // 1. تطبيق فلتر التوثيق (Verified Only)
        if (_showVerifiedOnly && status == 'pending_verification') continue;
        
        // 2. تطبيق فلتر الشدة (Severity)
        if (_selectedSeverity != 'الكل' && severity != _selectedSeverity) continue;

        // 3. تطبيق فلتر النوع (Type)
        if (_selectedType != 'الكل' && type != _selectedType && !(type == 'Earthquake' && _selectedType == 'زلزال')) continue;

        // 4. تطبيق فلتر المواقع المفضلة (ضمن شعاع 50 كيلومتر)
        if (_showNearFavoritesOnly) {
          if (savedLocations.isEmpty) continue; // إخفاء الكل إذا لم تكن هناك مفضلة
          
          bool isNear = false;
          for (var loc in savedLocations) {
            double locLat = (loc['latitude'] as num).toDouble();
            double locLng = (loc['longitude'] as num).toDouble();
            
            double distInMeters = _distanceCalc.distance(LatLng(lat, lng), LatLng(locLat, locLng));
            if (distInMeters <= 50000) { // 50 كيلومتر
              isNear = true;
              break;
            }
          }
          if (!isNear) continue; // استبعاد الخطر إذا لم يكن قريباً من أي موقع
        }

        // تحديد شكل وألوان الأيقونات بناءً على الشدة
        Color markerColor = Colors.green;
        IconData markerIcon = Icons.location_on;
        double iconSize = 30.0;

        if (severity == 'high') { markerColor = Colors.red; markerIcon = Icons.warning; iconSize = 40.0; }
        else if (severity == 'medium') { markerColor = Colors.orange; markerIcon = Icons.warning_amber; iconSize = 35.0; }

        if (type == 'حريق') markerIcon = Icons.local_fire_department;
        if (type == 'زلزال' || type == 'Earthquake') markerIcon = Icons.waves;

        markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: iconSize,
            height: iconSize,
            child: GestureDetector(
              onTap: () {
                _showMarkerDetails(context, data);
              },
              child: Icon(markerIcon, color: markerColor, size: iconSize),
            ),
          ),
        );
      }
      return markers;
    });
  }

  // نافذة منبثقة عند الضغط على العلامة في الخريطة
  void _showMarkerDetails(BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('نوع الخطر: ${data['type']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text('الشدة: ${data['severity']}', style: const TextStyle(fontSize: 16)),
              Text('المصدر: ${data['source'] ?? 'غير معروف'}', style: const TextStyle(fontSize: 16, color: Colors.blue)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إغلاق'),
                ),
              )
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('خريطة المخاطر الحية 🗺️', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // 1. طبقة الخريطة السفلية
          StreamBuilder<List<Marker>>(
            stream: _getFilteredMarkers(),
            builder: (context, snapshot) {
              List<Marker> markers = snapshot.data ?? [];
              
              return FlutterMap(
                options: const MapOptions(
                  initialCenter: LatLng(24.0, 45.0), // إحداثيات افتراضية مركزية
                  initialZoom: 5.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.eco_alert',
                  ),
                  MarkerLayer(markers: markers),
                ],
              );
            },
          ),

          // 2. طبقة شريط التصفية العلوي (Floating Filter Bar)
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                children: [
                  // فلتر القرب من المواقع المفضلة الجديد
                  FilterChip(
                    label: const Text('قريب من مفضلتي 📍', style: TextStyle(fontWeight: FontWeight.bold)),
                    selected: _showNearFavoritesOnly,
                    selectedColor: Colors.purple[200],
                    onSelected: (bool value) {
                      setState(() => _showNearFavoritesOnly = value);
                      if (value) {
                        _checkFavoritesEmpty(); // التحقق التلقائي عند تفعيل الفلتر
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  // فلتر البلاغات الموثقة
                  FilterChip(
                    label: const Text('موثقة فقط ✅'),
                    selected: _showVerifiedOnly,
                    selectedColor: Colors.green[200],
                    onSelected: (bool value) {
                      setState(() => _showVerifiedOnly = value);
                    },
                  ),
                  const SizedBox(width: 8),
                  // فلتر الشدة (خطر عالي)
                  ChoiceChip(
                    label: const Text('خطر عالي 🔴'),
                    selected: _selectedSeverity == 'high',
                    selectedColor: Colors.red[200],
                    onSelected: (bool selected) {
                      setState(() => _selectedSeverity = selected ? 'high' : 'الكل');
                    },
                  ),
                  const SizedBox(width: 8),
                  // فلتر الشدة (متوسط)
                  ChoiceChip(
                    label: const Text('متوسط 🟠'),
                    selected: _selectedSeverity == 'medium',
                    selectedColor: Colors.orange[200],
                    onSelected: (bool selected) {
                      setState(() => _selectedSeverity = selected ? 'medium' : 'الكل');
                    },
                  ),
                  const SizedBox(width: 8),
                  // فلتر النوع (زلازل)
                  ChoiceChip(
                    label: const Text('زلازل 🌊'),
                    selected: _selectedType == 'زلزال',
                    selectedColor: Colors.blue[200],
                    onSelected: (bool selected) {
                      setState(() => _selectedType = selected ? 'زلزال' : 'الكل');
                    },
                  ),
                  const SizedBox(width: 8),
                  // فلتر النوع (حرائق)
                  ChoiceChip(
                    label: const Text('حرائق 🔥'),
                    selected: _selectedType == 'حريق',
                    selectedColor: Colors.deepOrange[200],
                    onSelected: (bool selected) {
                      setState(() => _selectedType = selected ? 'حريق' : 'الكل');
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
