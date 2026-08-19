import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../alerts/presentation/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isLoginMode = true; // للتبديل بين تسجيل الدخول وإنشاء حساب جديد

  // دالة تسجيل الدخول للحسابات الموجودة
  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // إذا نجح الدخول، سيتولى main.dart (StreamBuilder) توجيهه تلقائياً للـ Dashboard
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'حدث خطأ في تسجيل الدخول')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // دالة إنشاء حساب جديد (هنا السر: ربط المصادقة بـ Firestore)
  Future<void> _signUp() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      // 1. إنشاء الحساب في نظام المصادقة (Auth)
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = userCredential.user;
      if (user != null) {
        // 2. إنشاء مستند المستخدم في قاعدة البيانات (Firestore)
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email,
          'name': user.email?.split('@').first.toUpperCase(),
          'role': 'user', // الصلاحية الافتراضية مستخدم عادي
          'trustScore': 50, // نقاط بداية عادلة
          'createdAt': FieldValue.serverTimestamp(),
          'avatarUrl': 'https://ui-avatars.com/api/?name=${user.email?.split('@').first}&background=random',
        });
      }
      // سيتولى main.dart التوجيه التلقائي
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'حدث خطأ في إنشاء الحساب')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.eco, size: 100, color: Colors.green),
              const SizedBox(height: 20),
              const Text(
                'Eco Alert',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const Text(
                'نظام الإنذار المبكر للمخاطر البيئية',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 40),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 24),

              if (_isLoading)
                const CircularProgressIndicator()
              else
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: _isLoginMode ? _login : _signUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: Text(_isLoginMode ? 'تسجيل الدخول' : 'إنشاء حساب جديد'),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLoginMode = !_isLoginMode;
                        });
                      },
                      child: Text(
                        _isLoginMode ? 'لا تملك حساباً؟ أنشئ واحداً الآن' : 'لديك حساب بالفعل؟ سجل دخولك',
                        style: const TextStyle(color: Colors.green),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
