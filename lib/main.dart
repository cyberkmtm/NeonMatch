import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
    ),
  );
  runApp(const NeonDatingApp());
}

// ==========================================
// GLOBAL STATE & THEME
// ==========================================
class AppState extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.dark;
  void toggleTheme() {
    themeMode = themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}

final appState = AppState();

class AppColors {
  static const Color cyan = Color(0xFF00F5FF);
  static const Color blue = Color(0xFF0066FF);
  static const Color purple = Color(0xFF8A2BE2);
  static const Color pink = Color(0xFFFF2D78);
  static const Color red = Color(0xFFFF0055);
  static const Color darkBg = Color(0xFF07090F);
  static const Color darkSurface = Color(0xFF0F1520);
  static const Color darkCard = Color(0xFF151C2E);
  static const Color lightBg = Color(0xFFF0F2F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
}

class AppTheme {
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBg,
    primaryColor: AppColors.cyan,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.cyan,
      secondary: AppColors.purple,
      surface: AppColors.darkSurface,
    ),
    textTheme: const TextTheme(bodyMedium: TextStyle(fontFamily: 'sans-serif')),
  );
  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBg,
    primaryColor: AppColors.blue,
    colorScheme: const ColorScheme.light(
      primary: AppColors.blue,
      secondary: AppColors.purple,
      surface: AppColors.lightSurface,
    ),
  );
}

bool isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

// ==========================================
// APP ROOT
// ==========================================
class NeonDatingApp extends StatelessWidget {
  const NeonDatingApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, child) => MaterialApp(
        title: 'GEN Ƶ',
        debugShowCheckedModeBanner: false,
        themeMode: appState.themeMode,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.darkBg,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.cyan),
            ),
          );
        }
        if (snapshot.hasData) return const MainNavigator();
        return const AuthScreen();
      },
    );
  }
}

// ==========================================
// AUTH SCREEN
// ==========================================
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool isLogin = true;
  bool _obscurePassword = true;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  String gender = 'Male';
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  void _switchMode() {
    setState(() => isLogin = !isLogin);
    _animCtrl.reset();
    _animCtrl.forward();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text.trim(),
        );
      } else {
        UserCredential cred = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _emailCtrl.text.trim(),
              password: _passwordCtrl.text.trim(),
            );
        await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .set({
              'uid': cred.user!.uid,
              'name': _nameCtrl.text.trim(),
              'age': int.parse(_ageCtrl.text.trim()),
              'gender': gender,
              'bio': '',
              'interests': [],
              'images': [],
              'discoverySettings': {
                'minAge': 18,
                'maxAge': 40,
                'maxDistance': 50,
              },
              'location': 'New York',
              'createdAt': FieldValue.serverTimestamp(),
            });
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Something went wrong. Please try again.';
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        msg = 'Incorrect email or password.';
      } else if (e.code == 'email-already-in-use') {
        msg = 'An account with this email already exists.';
      } else if (e.code == 'weak-password') {
        msg = 'Password must be at least 6 characters.';
      } else if (e.code == 'invalid-email') {
        msg = 'Please enter a valid email address.';
      } else if (e.code == 'too-many-requests') {
        msg = 'Too many attempts. Please try again later.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    if (_emailCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Enter your email above first.'),
          backgroundColor: AppColors.purple,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailCtrl.text.trim(),
      );
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => _ResetEmailDialog(email: _emailCtrl.text.trim()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Could not send reset email.';
      if (e.code == 'user-not-found') msg = 'No account found with that email.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        children: [
          Positioned(
            top: -80,
            left: -60,
            child: _GlowOrb(color: AppColors.cyan, size: 280, opacity: 0.12),
          ),
          Positioned(
            top: size.height * 0.3,
            right: -80,
            child: _GlowOrb(color: AppColors.purple, size: 220, opacity: 0.10),
          ),
          Positioned(
            bottom: -60,
            left: size.width * 0.2,
            child: _GlowOrb(color: AppColors.pink, size: 200, opacity: 0.09),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      // Logo / Brand (Updated to GEN Ƶ with Caption)
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [AppColors.cyan, AppColors.purple],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.cyan.withOpacity(0.4),
                                    blurRadius: 24,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.bolt,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [AppColors.cyan, AppColors.purple],
                              ).createShader(bounds),
                              child: const Text(
                                'GEN Ƶ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'dating app'.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4.0,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isLogin ? 'Welcome back ✦' : 'Find your spark ✦',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 44),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.darkSurface,
                          borderRadius: BorderRadius.circular(40),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          children: [
                            _TabPill(
                              label: 'Sign In',
                              active: isLogin,
                              onTap: () {
                                if (!isLogin) _switchMode();
                              },
                            ),
                            _TabPill(
                              label: 'Create Account',
                              active: !isLogin,
                              onTap: () {
                                if (isLogin) _switchMode();
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      if (!isLogin) ...[
                        _NeonField(
                          controller: _nameCtrl,
                          hint: 'First Name',
                          icon: Icons.person_outline,
                          validator: (v) =>
                              v!.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _NeonField(
                                controller: _ageCtrl,
                                hint: 'Age',
                                icon: Icons.cake_outlined,
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  int? p = int.tryParse(v ?? '');
                                  if (p == null || p < 18) return '18+ only';
                                  if (p > 80) return 'Invalid';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _GenderDropdown(
                                value: gender,
                                onChanged: (v) => setState(() => gender = v!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      _NeonField(
                        controller: _emailCtrl,
                        hint: 'Email',
                        icon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _NeonField(
                        controller: _passwordCtrl,
                        hint: 'Password',
                        icon: Icons.lock_outline,
                        obscure: _obscurePassword,
                        suffix: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.white38,
                            size: 20,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (!isLogin && v.length < 6)
                            return 'Min 6 characters';
                          return null;
                        },
                      ),
                      if (isLogin) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: _forgotPassword,
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(
                                color: AppColors.cyan,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 36),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.cyan,
                                ),
                              )
                            : _GradientButton(
                                label: isLogin ? 'Sign In' : 'Create Account',
                                onTap: _submit,
                              ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: GestureDetector(
                          onTap: _switchMode,
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 14,
                              ),
                              children: [
                                TextSpan(
                                  text: isLogin
                                      ? "Don't have an account? "
                                      : 'Already have an account? ',
                                ),
                                TextSpan(
                                  text: isLogin ? 'Sign up' : 'Sign in',
                                  style: const TextStyle(
                                    color: AppColors.cyan,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  const _GlowOrb({
    required this.color,
    required this.size,
    required this.opacity,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(opacity),
          blurRadius: size * 0.8,
          spreadRadius: size * 0.1,
        ),
      ],
      color: color.withOpacity(opacity * 0.3),
    ),
  );
}

class _TabPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabPill({
    required this.label,
    required this.active,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(36),
          gradient: active
              ? const LinearGradient(colors: [AppColors.cyan, AppColors.purple])
              : null,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.cyan.withOpacity(0.3),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : Colors.white38,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    ),
  );
}

class _NeonField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffix;
  const _NeonField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.suffix,
  });
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    obscureText: obscure,
    keyboardType: keyboardType,
    validator: validator,
    style: const TextStyle(color: Colors.white, fontSize: 15),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 15),
      prefixIcon: Icon(icon, color: Colors.white24, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.darkSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.cyan, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.red, width: 1.2),
      ),
      errorStyle: const TextStyle(color: AppColors.red, fontSize: 11),
    ),
  );
}

class _GenderDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;
  const _GenderDropdown({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    value: value,
    dropdownColor: AppColors.darkCard,
    style: const TextStyle(color: Colors.white),
    icon: const Icon(Icons.expand_more, color: Colors.white38),
    decoration: InputDecoration(
      hintText: 'Gender',
      hintStyle: const TextStyle(color: Colors.white24),
      prefixIcon: const Icon(
        Icons.wc_outlined,
        color: Colors.white24,
        size: 20,
      ),
      filled: true,
      fillColor: AppColors.darkSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.cyan, width: 1.2),
      ),
    ),
    items: ['Male', 'Female']
        .map(
          (g) => DropdownMenuItem(
            value: g,
            child: Text(g, style: const TextStyle(color: Colors.white)),
          ),
        )
        .toList(),
    onChanged: onChanged,
  );
}

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GradientButton({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [AppColors.cyan, AppColors.purple],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyan.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ),
    ),
  );
}

class _ResetEmailDialog extends StatelessWidget {
  final String email;
  const _ResetEmailDialog({required this.email});
  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.darkSurface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: const Text(
      'Check your inbox',
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cyan.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            color: AppColors.cyan,
            size: 40,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'A password reset link has been sent to\n$email',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
      ],
    ),
    actions: [
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.cyan,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Got it',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    ],
  );
}

// ==========================================
// USER PROFILE VIEW SCREEN
// ==========================================
class UserProfileScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  const UserProfileScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    List images = [];
    if (user['images'] != null)
      images = List.from(
        user['images'],
      ).where((u) => u.toString().isNotEmpty).toList();
    if (images.isEmpty)
      images = [
        'https://images.unsplash.com/photo-1557683316-973673baf926?q=80&w=800',
      ];
    List interests = user['interests'] ?? [];
    String location = user['location'] ?? 'Unknown';
    final PageController pageCtrl = PageController();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.62,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: pageCtrl,
                    itemCount: images.length,
                    itemBuilder: (_, i) => Image.network(
                      images[i],
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                  if (images.length > 1)
                    Positioned(
                      top: 60,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          images.length,
                          (i) => AnimatedBuilder(
                            animation: pageCtrl,
                            builder: (_, __) {
                              bool active =
                                  (pageCtrl.hasClients &&
                                      pageCtrl.page?.round() == i) ||
                                  (!pageCtrl.hasClients && i == 0);
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                width: active ? 20 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  color: active
                                      ? AppColors.cyan
                                      : Colors.white38,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${user['name'] ?? 'Unknown'}, ${user['age'] ?? '?'}',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: isDark(context)
                                ? Colors.white
                                : Colors.black,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.verified,
                        color: AppColors.cyan,
                        size: 26,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.grey,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        location,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Divider(color: Colors.white12),
                  ),
                  const Text(
                    'About',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.cyan,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    user['bio'] ?? 'This person is a mystery.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: isDark(context) ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  if (interests.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    const Text(
                      'Interests',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.cyan,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: interests
                          .map(
                            (i) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.cyan.withOpacity(0.08),
                                border: Border.all(
                                  color: AppColors.cyan,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                i,
                                style: TextStyle(
                                  color: isDark(context)
                                      ? Colors.white
                                      : Colors.black,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// MAIN NAVIGATOR
// ==========================================
class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});
  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _currentIndex = 0;
  final List<Widget> _screens = const [
    SwipeTab(),
    DiscoverTab(),
    MatchesTab(),
    ChatListTab(),
    ProfileTab(),
  ];

  late Stream<QuerySnapshot> _matchStream;
  final Set<String> _seenMatchIds = {};

  @override
  void initState() {
    super.initState();
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    _matchStream = FirebaseFirestore.instance
        .collection('matches')
        .where('users', arrayContains: myUid)
        .snapshots();

    _matchStream.listen((snap) {
      for (var doc in snap.docs) {
        if (_seenMatchIds.contains(doc.id)) continue;
        _seenMatchIds.add(doc.id);
        if (!snap.metadata.hasPendingWrites && snap.metadata.isFromCache)
          continue;
        final data = doc.data() as Map<String, dynamic>;
        final lastMsg = data['lastMessage'] ?? '';
        if (lastMsg == 'Matched!' && mounted) {
          _showMatchBanner(doc.id, data);
        }
      }
    });
  }

  Future<void> _showMatchBanner(
    String chatId,
    Map<String, dynamic> matchData,
  ) async {
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    final otherUid = (matchData['users'] as List).firstWhere(
      (id) => id != myUid,
    );
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(otherUid)
          .get();
      if (!userDoc.exists || !mounted) return;
      final user = userDoc.data() as Map<String, dynamic>;
      final images = List<String>.from(
        user['images'] ?? [],
      ).where((u) => u.isNotEmpty).toList();
      final img = images.isNotEmpty ? images[0] : null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.all(12),
          content: GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ChatDetailScreen(chatId: chatId, otherUser: user),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.purple, AppColors.cyan],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cyan.withOpacity(0.3),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (img != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.network(
                        img,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    const CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "It's a Match! 🔥",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'You and ${user['name'] ?? 'someone'} liked each other',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white70),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark(context)
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.06),
            ),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          currentIndex: _currentIndex,
          selectedItemColor: isDark(context) ? AppColors.cyan : AppColors.blue,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          onTap: (i) {
            HapticFeedback.selectionClick();
            setState(() => _currentIndex = i);
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.style), label: 'Swipe'),
            BottomNavigationBarItem(
              icon: Icon(Icons.travel_explore),
              label: 'Discover',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite),
              label: 'Matches',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble),
              label: 'Chat',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// SWIPE TAB
// ==========================================
class SwipeTab extends StatefulWidget {
  final Map<String, dynamic>? specificUser;
  final String? filterInterest;
  const SwipeTab({super.key, this.specificUser, this.filterInterest});

  @override
  State<SwipeTab> createState() => _SwipeTabState();
}

class _SwipeTabState extends State<SwipeTab>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> deck = [];
  Offset _position = Offset.zero;
  bool _isDragging = false, isLoading = true;
  double _angle = 0;

  @override
  void initState() {
    super.initState();
    _loadLiveUsers();
  }

  Future<void> _loadLiveUsers() async {
    if (widget.specificUser != null) {
      setState(() {
        deck = [widget.specificUser!];
        isLoading = false;
      });
      return;
    }

    String myUid = FirebaseAuth.instance.currentUser!.uid;
    DocumentSnapshot myDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(myUid)
        .get();
    if (!myDoc.exists) {
      setState(() => isLoading = false);
      return;
    }

    Map<String, dynamic> myData = myDoc.data() as Map<String, dynamic>;
    String myGender = myData['gender'] ?? 'Male';
    String targetGender = myGender == 'Male' ? 'Female' : 'Male';

    Map<String, dynamic> settings =
        myData['discoverySettings'] ??
        {'minAge': 18, 'maxAge': 80, 'maxDistance': 50};
    int minAge = settings['minAge'] ?? 18;
    int maxAge = settings['maxAge'] ?? 80;
    int maxDist = settings['maxDistance'] ?? 50;

    QuerySnapshot usersQuery = await FirebaseFirestore.instance
        .collection('users')
        .get();

    List<String> swipedIds = [];
    try {
      QuerySnapshot mySwipes = await FirebaseFirestore.instance
          .collection('swipes')
          .doc(myUid)
          .collection('interactions')
          .get();
      swipedIds = mySwipes.docs.map((d) => d.id).toList();
    } catch (_) {}

    List<Map<String, dynamic>> loadedDeck = [];
    for (var doc in usersQuery.docs) {
      if (doc.id == myUid) continue;
      if (swipedIds.contains(doc.id)) continue;

      Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
      userData['uid'] = doc.id;

      String? theirGender = userData['gender'];
      if (theirGender != null &&
          theirGender.isNotEmpty &&
          theirGender != targetGender) {
        continue;
      }

      int userAge = userData['age'] ?? 25;
      if (userAge < minAge || userAge > maxAge) continue;

      int mockDistance = (doc.id.hashCode.abs() % 100);
      if (mockDistance > maxDist) continue;
      userData['calculatedDistance'] = mockDistance;

      if (widget.filterInterest != null) {
        List interests = userData['interests'] ?? [];
        if (!interests.contains(widget.filterInterest)) continue;
      }

      loadedDeck.add(userData);
    }

    loadedDeck.sort((a, b) {
      int scoreA = NeonMatchAI.compatibilityScore(myData, a);
      int scoreB = NeonMatchAI.compatibilityScore(myData, b);
      return scoreB.compareTo(scoreA);
    });

    setState(() {
      deck = loadedDeck;
      isLoading = false;
    });
  }

  void _swipe(bool isLike) async {
    if (deck.isEmpty) return;
    isLike ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact();
    String targetUid = deck.first['uid'];
    String myUid = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance
        .collection('swipes')
        .doc(myUid)
        .collection('interactions')
        .doc(targetUid)
        .set({'liked': isLike, 'timestamp': FieldValue.serverTimestamp()});

    if (isLike) {
      await FirebaseFirestore.instance
          .collection('likes')
          .doc('${myUid}_$targetUid')
          .set({'from': myUid, 'to': targetUid});

      DocumentSnapshot tSwipe = await FirebaseFirestore.instance
          .collection('swipes')
          .doc(targetUid)
          .collection('interactions')
          .doc(myUid)
          .get();

      if (tSwipe.exists && tSwipe['liked'] == true) {
        String chatId = myUid.compareTo(targetUid) < 0
            ? '${myUid}_$targetUid'
            : '${targetUid}_$myUid';
        await FirebaseFirestore.instance.collection('matches').doc(chatId).set({
          'users': [myUid, targetUid],
          'timestamp': FieldValue.serverTimestamp(),
          'lastMessage': 'Matched!',
        });
        if (mounted) {
          _showMatchDialog(deck.first);
        }
      }
    }

    setState(() {
      deck.removeAt(0);
      _position = Offset.zero;
      _angle = 0;
    });

    if ((widget.specificUser != null || widget.filterInterest != null) &&
        deck.isEmpty) {
      if (mounted) Navigator.pop(context);
    }
  }

  void _showMatchDialog(Map<String, dynamic> matchedUser) {
    List images = matchedUser['images'] != null
        ? List.from(
            matchedUser['images'],
          ).where((u) => u.toString().isNotEmpty).toList()
        : [];
    String img = images.isNotEmpty
        ? images[0]
        : 'https://images.unsplash.com/photo-1557683316-973673baf926?q=80&w=800';

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [AppColors.cyan, AppColors.purple],
              ).createShader(bounds),
              child: const Text(
                "It's a Match! 🔥",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You and ${matchedUser['name']} liked each other',
              style: const TextStyle(color: Colors.white60, fontSize: 15),
            ),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                img,
                width: 160,
                height: 160,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 28),
            _GradientButton(
              label: 'Send a Message',
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Keep Swiping',
                style: TextStyle(color: Colors.white38),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onPanUpdate(DragUpdateDetails d) => setState(() {
    _position += d.delta;
    _angle = 45 * (_position.dx / MediaQuery.of(context).size.width);
    _isDragging = true;
  });

  void _onPanEnd(DragEndDetails _) {
    setState(() => _isDragging = false);
    if (_position.dx > 100)
      _swipe(true);
    else if (_position.dx < -100)
      _swipe(false);
    else
      setState(() {
        _position = Offset.zero;
        _angle = 0;
      });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading)
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.cyan)),
      );

    bool isModal = widget.specificUser != null || widget.filterInterest != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: isModal ? const BackButton(color: Colors.white) : null,
        title: Text(
          widget.filterInterest != null ? widget.filterInterest! : 'GEN Ƶ',
          style: TextStyle(
            color: isDark(context) ? AppColors.cyan : AppColors.blue,
            fontWeight: FontWeight.bold,
            fontSize: 26,
          ),
        ),
        actions: [
          if (!isModal)
            IconButton(
              icon: const Icon(Icons.tune, color: Colors.white54),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: deck.isEmpty
                ? _EmptyDeckView()
                : Stack(
                    alignment: Alignment.center,
                    children: deck.reversed.indexed.map((entry) {
                      int index = deck.length - 1 - entry.$1;
                      Map<String, dynamic> user = entry.$2;
                      bool isTop = index == 0;
                      return isTop
                          ? _buildTopCard(user)
                          : Transform.scale(
                              scale: 1.0 - (index * 0.04),
                              child: Transform.translate(
                                offset: Offset(0, index * 12.0),
                                child: _buildCardUI(user, isTop: false),
                              ),
                            );
                    }).toList(),
                  ),
          ),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _EmptyDeckView() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.explore_off,
          size: 64,
          color: Colors.white.withOpacity(0.15),
        ),
        const SizedBox(height: 16),
        const Text(
          'No more profiles',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Try adjusting your discovery settings',
          style: TextStyle(color: Colors.white30, fontSize: 14),
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: () {
            setState(() => isLoading = true);
            _loadLiveUsers();
          },
          child: const Text('Refresh', style: TextStyle(color: AppColors.cyan)),
        ),
      ],
    ),
  );

  Widget _buildActionButtons() => Padding(
    padding: const EdgeInsets.fromLTRB(0, 8, 0, 28),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ActionBtn(
          icon: Icons.close,
          color: AppColors.red,
          size: 66,
          onTap: () => _swipe(false),
        ),
        const SizedBox(width: 24),
        _ActionBtn(
          icon: Icons.star,
          color: AppColors.purple,
          size: 50,
          onTap: () {},
        ),
        const SizedBox(width: 24),
        _ActionBtn(
          icon: Icons.favorite,
          color: AppColors.cyan,
          size: 66,
          onTap: () => _swipe(true),
        ),
      ],
    ),
  );

  Widget _buildTopCard(Map<String, dynamic> user) => GestureDetector(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileScreen(user: user)),
    ),
    onPanUpdate: _onPanUpdate,
    onPanEnd: _onPanEnd,
    child: AnimatedContainer(
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 300),
      transform: Matrix4.identity()
        ..translate(_position.dx, _position.dy)
        ..rotateZ(_angle * (pi / 180)),
      child: _buildCardUI(user, isTop: true),
    ),
  );

  Widget _buildCardUI(Map<String, dynamic> user, {required bool isTop}) {
    double lOp = (isTop && _position.dx > 0)
        ? (_position.dx / 100).clamp(0.0, 1.0)
        : 0.0;
    double nOp = (isTop && _position.dx < 0)
        ? (_position.dx.abs() / 100).clamp(0.0, 1.0)
        : 0.0;

    Color glow = lOp > 0
        ? AppColors.cyan.withOpacity(lOp * 0.7)
        : nOp > 0
        ? AppColors.red.withOpacity(nOp * 0.7)
        : Colors.black26;

    List images = user['images'] != null
        ? List.from(
            user['images'],
          ).where((u) => u.toString().isNotEmpty).toList()
        : [];
    String imgUrl = images.isNotEmpty
        ? images[0]
        : 'https://images.unsplash.com/photo-1557683316-973673baf926?q=80&w=800';

    List interests = user['interests'] ?? [];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: MediaQuery.of(context).size.width * 0.9,
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: glow, blurRadius: 24, spreadRadius: 4)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                imgUrl,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(color: AppColors.darkCard),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.92),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.45, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${user['name'] ?? 'Unknown'}, ${user['age'] ?? '?'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: AppColors.cyan,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${user['calculatedDistance'] ?? 10} miles away',
                          style: const TextStyle(
                            color: AppColors.cyan,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (user['bio'] != null &&
                        (user['bio'] as String).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        user['bio'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (interests.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: (interests.take(3)).map<Widget>((i) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              i,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 6),
                    const Row(
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          color: Colors.white30,
                          size: 13,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Tap to view full profile',
                          style: TextStyle(color: Colors.white30, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (lOp > 0)
              Positioned(
                top: 50,
                left: 28,
                child: Transform.rotate(
                  angle: -0.2,
                  child: Opacity(
                    opacity: lOp,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.cyan, width: 3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'LIKE',
                        style: TextStyle(
                          color: AppColors.cyan,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (nOp > 0)
              Positioned(
                top: 50,
                right: 28,
                child: Transform.rotate(
                  angle: 0.2,
                  child: Opacity(
                    opacity: nOp,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.red, width: 3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'NOPE',
                        style: TextStyle(
                          color: AppColors.red,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.darkSurface,
        border: Border.all(color: color.withOpacity(0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(icon, color: color, size: size * 0.46),
    ),
  );
}

// ==========================================
// DISCOVER TAB
// ==========================================
class DiscoverTab extends StatelessWidget {
  const DiscoverTab({super.key});

  static const _tiles = [
    _DiscoverTileData(
      title: 'Movie Night',
      emoji: '🎬',
      img:
          'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=800&q=80',
      color: AppColors.cyan,
      tag: 'Movies 🎬',
    ),
    _DiscoverTileData(
      title: 'Coffee Date',
      emoji: '☕️',
      img:
          'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=800&q=80',
      color: AppColors.purple,
      tag: 'Coffee ☕️',
    ),
    _DiscoverTileData(
      title: 'Music Event',
      emoji: '🎵',
      img:
          'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?w=800&q=80',
      color: AppColors.blue,
      tag: 'Music 🎵',
    ),
    _DiscoverTileData(
      title: 'Gamer Buddy',
      emoji: '🎮',
      img:
          'https://images.unsplash.com/photo-1511285560929-80b456fea0bc?w=800&q=80',
      color: AppColors.red,
      tag: 'Gaming 🎮',
    ),
    _DiscoverTileData(
      title: 'Gym Partner',
      emoji: '💪',
      img:
          'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=800&q=80',
      color: AppColors.pink,
      tag: 'Gym 💪',
    ),
    _DiscoverTileData(
      title: 'Art Lover',
      emoji: '🎨',
      img:
          'https://images.unsplash.com/photo-1541961017774-22349e4a1262?w=800&q=80',
      color: AppColors.purple,
      tag: 'Art 🎨',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Discover',
          style: TextStyle(
            color: isDark(context) ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 26,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.78,
        ),
        itemCount: _tiles.length,
        itemBuilder: (context, i) {
          final t = _tiles[i];
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SwipeTab(filterInterest: t.tag),
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: t.color.withOpacity(0.5), width: 1.5),
                image: DecorationImage(
                  image: NetworkImage(t.img),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.88),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.4, 1.0],
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 6),
                    Text(
                      t.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Find your match',
                      style: TextStyle(
                        color: t.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DiscoverTileData {
  final String title, emoji, img, tag;
  final Color color;
  const _DiscoverTileData({
    required this.title,
    required this.emoji,
    required this.img,
    required this.color,
    required this.tag,
  });
}

// ==========================================
// MATCHES TAB
// ==========================================
class MatchesTab extends StatelessWidget {
  const MatchesTab({super.key});
  @override
  Widget build(BuildContext context) {
    String myUid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Likes You',
          style: TextStyle(
            color: isDark(context) ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 26,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('likes')
            .where('to', isEqualTo: myUid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(
              child: CircularProgressIndicator(color: AppColors.cyan),
            );
          var likes = snapshot.data!.docs;
          if (likes.isEmpty)
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 60,
                    color: Colors.white.withOpacity(0.15),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'No likes yet',
                    style: TextStyle(color: Colors.white54, fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Keep swiping to get noticed!',
                    style: TextStyle(color: Colors.white30, fontSize: 14),
                  ),
                ],
              ),
            );
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.73,
            ),
            itemCount: likes.length,
            itemBuilder: (context, index) {
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(likes[index]['from'])
                    .get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData || !userSnap.data!.exists)
                    return const SizedBox();
                  var user = userSnap.data!.data() as Map<String, dynamic>;
                  user['uid'] = likes[index]['from'];
                  List images = user['images'] != null
                      ? List.from(
                          user['images'],
                        ).where((u) => u.toString().isNotEmpty).toList()
                      : [];
                  String img = images.isNotEmpty
                      ? images[0]
                      : 'https://images.unsplash.com/photo-1557683316-973673baf926?q=80&w=800';
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SwipeTab(specificUser: user),
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.purple.withOpacity(0.4),
                        ),
                        image: DecorationImage(
                          image: NetworkImage(img),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(17),
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.82),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        padding: const EdgeInsets.all(12),
                        alignment: Alignment.bottomLeft,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user['name'] ?? 'Unknown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${user['age'] ?? '?'} years old',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ==========================================
// CHAT LIST TAB
// ==========================================
class ChatListTab extends StatelessWidget {
  const ChatListTab({super.key});
  @override
  Widget build(BuildContext context) {
    String myUid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chats',
          style: TextStyle(
            color: isDark(context) ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 26,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('matches')
            .where('users', arrayContains: myUid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          if (!snapshot.hasData)
            return const Center(
              child: CircularProgressIndicator(color: AppColors.cyan),
            );
          var matches = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final aTs = (a.data() as Map)['timestamp'];
              final bTs = (b.data() as Map)['timestamp'];
              if (aTs == null && bTs == null) return 0;
              if (aTs == null) return 1;
              if (bTs == null) return -1;
              return (bTs as Timestamp).compareTo(aTs as Timestamp);
            });
          if (matches.isEmpty)
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 60,
                    color: Colors.white.withOpacity(0.15),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'No matches yet',
                    style: TextStyle(color: Colors.white54, fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Start swiping to find your spark!',
                    style: TextStyle(color: Colors.white30, fontSize: 14),
                  ),
                ],
              ),
            );
          return ListView.separated(
            itemCount: matches.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: Colors.white.withOpacity(0.04)),
            itemBuilder: (context, index) {
              var matchData = matches[index].data() as Map<String, dynamic>;
              String otherUid = (matchData['users'] as List).firstWhere(
                (id) => id != myUid,
              );
              String lastMsg = matchData['lastMessage'] ?? 'Tap to chat!';
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(otherUid)
                    .get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData || !userSnap.data!.exists)
                    return const SizedBox();
                  var user = userSnap.data!.data() as Map<String, dynamic>;
                  List images = user['images'] != null
                      ? List.from(
                          user['images'],
                        ).where((u) => u.toString().isNotEmpty).toList()
                      : [];
                  String img = images.isNotEmpty
                      ? images[0]
                      : 'https://images.unsplash.com/photo-1557683316-973673baf926?q=80&w=800';
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserProfileScreen(user: user),
                        ),
                      ),
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundImage: NetworkImage(img),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: AppColors.cyan,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.darkBg,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    title: Text(
                      user['name'] ?? 'Unknown',
                      style: TextStyle(
                        color: isDark(context) ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      lastMsg,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatDetailScreen(
                          chatId: matches[index].id,
                          otherUser: user,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ==========================================
// NEON MATCH AI — LOCAL ML ENGINE
// ==========================================
class NeonMatchAI {
  static const Map<String, List<String>> _interestGroups = {
    'visual_arts': ['Art 🎨', 'Movies 🎬', 'Photography'],
    'music': ['Music 🎵', 'Concerts', 'Guitar', 'DJ'],
    'fitness': ['Gym 💪', 'Running', 'Yoga', 'Sports'],
    'food_social': ['Foodie 🍕', 'Coffee ☕️', 'Cooking', 'Brunch'],
    'digital': ['Gaming 🎮', 'Tech', 'Anime', 'Coding'],
  };

  static const List<String> _sharedTemplates = [
    "We both love {interest} — taste test, who wins? {emoji}",
    "Finally someone else into {interest} 👀 what got you into it?",
    "{interest} fan spotted! We might actually get along 😄",
    "Is your {interest} taste as good as it looks? 😏",
  ];

  static const List<String> _curiosityTemplates = [
    "What's the most random thing you're proud of? 🤔",
    "Coffee order reveals personality. What's yours? ☕️",
    "Rate your cooking on a scale of toast to Michelin star 🍳",
    "What's the last thing that genuinely surprised you? ✨",
  ];

  static const List<String> _playfulTemplates = [
    "Okay but who has better music taste, us or the algorithm? 🎵",
    "Hot take incoming — what's yours? 🔥",
    "What's something you're weirdly passionate about? 😂",
    "If your friends described you in 3 words, what would they say? 👀",
  ];

  static const List<String> _boldTemplates = [
    "I already think we'd have a great time. Prove me wrong 😏",
    "Best conversation I'm going to have today. I can feel it 💫",
    "Okay, I'll admit it — your profile caught me off guard 👋",
    "You look like you have good stories. I'm here for it 🎭",
  ];

  static List<String> generateIceBreakers({
    required Map<String, dynamic> myProfile,
    required Map<String, dynamic> theirProfile,
  }) {
    List<String> myInterests = List<String>.from(myProfile['interests'] ?? []);
    List<String> theirInterests = List<String>.from(
      theirProfile['interests'] ?? [],
    );
    String theirName = theirProfile['name'] ?? 'you';

    List<String> shared = myInterests
        .where((i) => theirInterests.contains(i))
        .toList();

    List<String> groupMatches = [];
    if (shared.isEmpty) {
      for (var entry in _interestGroups.entries) {
        bool iHaveGroup = myInterests.any((i) => entry.value.contains(i));
        bool theyHaveGroup = theirInterests.any((i) => entry.value.contains(i));
        if (iHaveGroup && theyHaveGroup) {
          String theirGroupInterest = theirInterests.firstWhere(
            (i) => entry.value.contains(i),
            orElse: () => '',
          );
          if (theirGroupInterest.isNotEmpty) {
            groupMatches.add(theirGroupInterest);
          }
        }
      }
    }

    List<String> result = [];
    final rng = Random(theirProfile['uid']?.hashCode ?? 42);

    String? topInterest = shared.isNotEmpty
        ? shared[rng.nextInt(shared.length)]
        : groupMatches.isNotEmpty
        ? groupMatches[rng.nextInt(groupMatches.length)]
        : null;

    if (topInterest != null) {
      String emoji = _emojiForInterest(topInterest);
      String template = _sharedTemplates[rng.nextInt(_sharedTemplates.length)];
      result.add(
        template
            .replaceAll('{interest}', topInterest.split(' ').first)
            .replaceAll('{emoji}', emoji)
            .replaceAll('{name}', theirName),
      );
    } else {
      result.add(_curiosityTemplates[rng.nextInt(_curiosityTemplates.length)]);
    }

    result.add(_curiosityTemplates[rng.nextInt(_curiosityTemplates.length)]);
    result.add(_playfulTemplates[rng.nextInt(_playfulTemplates.length)]);
    result.add(_boldTemplates[rng.nextInt(_boldTemplates.length)]);

    return result.toSet().toList().take(4).toList();
  }

  static int compatibilityScore(
    Map<String, dynamic> myProfile,
    Map<String, dynamic> theirProfile,
  ) {
    int score = 0;

    List myInterests = myProfile['interests'] ?? [];
    List theirInterests = theirProfile['interests'] ?? [];

    int directMatches = myInterests
        .where((i) => theirInterests.contains(i))
        .length;
    score += (directMatches * 15).clamp(0, 60);

    for (var group in _interestGroups.values) {
      bool iHave = myInterests.any((i) => group.contains(i));
      bool theyHave = theirInterests.any((i) => group.contains(i));
      if (iHave && theyHave) score += 8;
    }

    int dist = theirProfile['calculatedDistance'] ?? 50;
    score += (10 - (dist / 10).floor()).clamp(0, 10);

    if ((theirProfile['bio'] ?? '').toString().length > 10) score += 5;

    List images = theirProfile['images'] ?? [];
    if (images.isNotEmpty) score += 5;

    return score.clamp(0, 100);
  }

  static Map<String, dynamic> generateCinemaSuggestion({
    required Map<String, dynamic> myProfile,
    required Map<String, dynamic> theirProfile,
    required Map<String, dynamic>? mockoonData,
  }) {
    if (mockoonData != null) {
      List myInterests = myProfile['interests'] ?? [];
      List theirInterests = theirProfile['interests'] ?? [];
      List shared = myInterests
          .where((i) => theirInterests.contains(i))
          .toList();

      String reason = shared.isNotEmpty
          ? 'You both love ${shared.first.toString().split(' ').first} — '
                'this one is perfect for you 🎬'
          : 'Hot pick for tonight — you\'re both going to love it 🍿';

      return {...mockoonData, 'aiReason': reason};
    }

    List myInterests = myProfile['interests'] ?? [];
    List theirInterests = theirProfile['interests'] ?? [];

    bool likesAction =
        myInterests.any((i) => i.toString().contains('Gaming')) ||
        theirInterests.any((i) => i.toString().contains('Gaming'));
    bool likesArt =
        myInterests.any((i) => i.toString().contains('Art')) ||
        theirInterests.any((i) => i.toString().contains('Art'));

    String movie, genre, reason;

    if (likesAction) {
      movie = 'Mad Max: Fury Road';
      genre = 'Action';
      reason = 'You both love adrenaline — this one delivers 🔥';
    } else if (likesArt) {
      movie = 'Everything Everywhere All at Once';
      genre = 'Drama / Sci-Fi';
      reason = 'A visually stunning film for curious minds 🎨';
    } else {
      movie = 'La La Land';
      genre = 'Romance / Music';
      reason = 'A perfect first movie date pick 💫';
    }

    return {
      'movie': movie,
      'genre': genre,
      'time': '8:00 PM',
      'location': 'City Cinema',
      'rating': '8.5/10',
      'message': reason,
      'aiReason': reason,
    };
  }

  static String _emojiForInterest(String interest) {
    const map = {
      'Gaming': '🎮',
      'Coffee': '☕️',
      'Music': '🎵',
      'Foodie': '🍕',
      'Gym': '💪',
      'Art': '🎨',
      'Movies': '🎬',
      'Running': '🏃',
      'Yoga': '🧘',
      'Tech': '💻',
      'Anime': '⛩️',
      'Cooking': '👨‍🍳',
    };
    for (var entry in map.entries) {
      if (interest.contains(entry.key)) return entry.value;
    }
    return '✨';
  }

  static List<String> fallbackIceBreakers() => [
    "You look like you have good stories 🎭",
    "What's your ideal Saturday? ☀️",
    "Rate your cooking: toast to Michelin star 🍳",
    "Hot take — what's yours? 🔥",
  ];
}

// ==========================================
// CHAT DETAIL SCREEN — AI POWERED
// ==========================================
class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final Map<String, dynamic> otherUser;
  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.otherUser,
  });
  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  Map<String, dynamic>? _pendingProposal;
  Map<String, dynamic>? _incomingProposal;
  String? _incomingProposalId;
  bool _proposalHandled = false;

  List<String> _aiIcebreakers = [];
  bool _loadingIcebreakers = false;
  bool _icebreakersLoaded = false;
  bool _icebreakersDismissed = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    String message = text.trim();
    _msgCtrl.clear();
    await FirebaseFirestore.instance
        .collection('matches')
        .doc(widget.chatId)
        .collection('messages')
        .add({
          'senderId': FirebaseAuth.instance.currentUser!.uid,
          'text': message,
          'timestamp': FieldValue.serverTimestamp(),
        });
    await FirebaseFirestore.instance
        .collection('matches')
        .doc(widget.chatId)
        .update({'lastMessage': message});
  }

  Future<void> _loadAiIcebreakers() async {
    if (_loadingIcebreakers) return;
    setState(() => _loadingIcebreakers = true);

    try {
      String myUid = FirebaseAuth.instance.currentUser!.uid;
      DocumentSnapshot myDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .get();

      Map<String, dynamic> myData = myDoc.exists
          ? (myDoc.data() as Map<String, dynamic>)
          : {};

      List<String> breakers = NeonMatchAI.generateIceBreakers(
        myProfile: myData,
        theirProfile: widget.otherUser,
      );

      if (mounted) {
        setState(() {
          _aiIcebreakers = breakers;
          _loadingIcebreakers = false;
          _icebreakersLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiIcebreakers = NeonMatchAI.fallbackIceBreakers();
          _loadingIcebreakers = false;
          _icebreakersLoaded = true;
        });
      }
    }
  }

  Future<void> _buildMovieSuggestion() async {
    String myUid = FirebaseAuth.instance.currentUser!.uid;
    Map<String, dynamic> myProfile = {};
    try {
      final myDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(myUid)
          .get();
      if (myDoc.exists) myProfile = myDoc.data() as Map<String, dynamic>;
    } catch (_) {}

    Map<String, dynamic>? rawMockoon;
    try {
      final res = await http
          .get(Uri.parse('http://127.0.0.1:3000/movies/random'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) rawMockoon = jsonDecode(res.body);
    } catch (_) {}

    final suggestion = NeonMatchAI.generateCinemaSuggestion(
      myProfile: myProfile,
      theirProfile: widget.otherUser,
      mockoonData: rawMockoon,
    );

    if (mounted) setState(() => _pendingProposal = suggestion);
  }

  Future<void> _sendMovieProposal() async {
    if (_pendingProposal == null) return;
    final myUid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance
        .collection('matches')
        .doc(widget.chatId)
        .collection('proposals')
        .add({
          'from': myUid,
          'to': widget.otherUser['uid'],
          'movie': _pendingProposal,
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        });
    if (mounted) setState(() => _pendingProposal = null);
  }

  void _dismissPendingProposal() {
    if (mounted) setState(() => _pendingProposal = null);
  }

  Future<void> _respondToProposal(bool accepted) async {
    if (_incomingProposalId == null) return;
    setState(() => _proposalHandled = true);

    await FirebaseFirestore.instance
        .collection('matches')
        .doc(widget.chatId)
        .collection('proposals')
        .doc(_incomingProposalId)
        .update({'status': accepted ? 'accepted' : 'rejected'});

    final movie = _incomingProposal?['movie'] ?? {};
    final location = movie['location'] ?? 'the cinema';
    final time = movie['time'] ?? 'tonight';

    final msg = accepted
        ? "I'm in! 🎬🔥 See you at $location at $time — can't wait!"
        : "Maybe next time! 😊 Let's plan something else.";

    _sendMessage(msg);
    setState(() {
      _incomingProposal = null;
      _incomingProposalId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    List images = widget.otherUser['images'] != null
        ? List.from(
            widget.otherUser['images'],
          ).where((u) => u.toString().isNotEmpty).toList()
        : [];
    String img = images.isNotEmpty
        ? images[0]
        : 'https://images.unsplash.com/photo-1557683316-973673baf926?q=80&w=800';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: const BackButton(),
        title: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(user: widget.otherUser),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(radius: 18, backgroundImage: NetworkImage(img)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUser['name'] ?? 'Unknown',
                    style: TextStyle(
                      color: isDark(context) ? Colors.white : Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Online',
                    style: TextStyle(color: AppColors.cyan, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.movie_outlined, color: AppColors.cyan),
            tooltip: 'Suggest a movie date',
            onPressed: _buildMovieSuggestion,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_pendingProposal != null) _buildPendingProposalPreview(),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('matches')
                .doc(widget.chatId)
                .collection('proposals')
                .where('to', isEqualTo: FirebaseAuth.instance.currentUser!.uid)
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, propSnap) {
              if (propSnap.hasData &&
                  propSnap.data!.docs.isNotEmpty &&
                  !_proposalHandled) {
                final propDoc = propSnap.data!.docs.first;
                if (_incomingProposalId != propDoc.id) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted)
                      setState(() {
                        _incomingProposalId = propDoc.id;
                        _incomingProposal =
                            propDoc.data() as Map<String, dynamic>;
                        _proposalHandled = false;
                      });
                  });
                }
              }
              return const SizedBox.shrink();
            },
          ),
          if (_incomingProposal != null && !_proposalHandled)
            _buildIncomingProposalCard(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('matches')
                  .doc(widget.chatId)
                  .collection('messages')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return Center(
                    child: Text(
                      'Could not load messages.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  );
                if (!snapshot.hasData)
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.cyan),
                  );

                var docs = snapshot.data!.docs.toList()
                  ..sort((a, b) {
                    final aTs = (a.data() as Map)['timestamp'];
                    final bTs = (b.data() as Map)['timestamp'];
                    if (aTs == null && bTs == null) return 0;
                    if (aTs == null) return -1;
                    if (bTs == null) return 1;
                    return (bTs as Timestamp).compareTo(aTs as Timestamp);
                  });
                int msgCount = docs.length;

                if (!_icebreakersLoaded) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _loadAiIcebreakers(),
                  );
                }

                if (msgCount == 0) return _buildEmptyChatView();

                return ListView.builder(
                  reverse: true,
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: msgCount,
                  itemBuilder: (context, index) {
                    final msg = docs[index];
                    final isMe =
                        msg['senderId'] ==
                        FirebaseAuth.instance.currentUser!.uid;
                    return _buildBubble(msg['text'], isMe);
                  },
                );
              },
            ),
          ),
          if (_aiIcebreakers.isNotEmpty && !_icebreakersDismissed)
            _buildIcebreakerBar(),
          if (_loadingIcebreakers)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.cyan,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'AI is thinking…',
                    style: TextStyle(color: Colors.white30, fontSize: 12),
                  ),
                ],
              ),
            ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyChatView() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.cyan.withOpacity(0.08),
          ),
          child: const Icon(Icons.favorite, color: AppColors.cyan, size: 48),
        ),
        const SizedBox(height: 16),
        const Text(
          "You matched! 🎉",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Break the ice — say something!",
          style: TextStyle(color: Colors.white38, fontSize: 14),
        ),
      ],
    ),
  );

  Widget _buildBubble(String text, bool isMe) {
    final dark = isDark(context);
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          gradient: isMe
              ? const LinearGradient(colors: [AppColors.blue, AppColors.purple])
              : null,
          color: isMe
              ? null
              : (dark ? AppColors.darkSurface : AppColors.lightSurface),
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: Radius.circular(isMe ? 4 : 20),
            bottomLeft: Radius.circular(isMe ? 20 : 4),
          ),
          border: isMe
              ? null
              : Border.all(
                  color: dark
                      ? Colors.transparent
                      : Colors.black.withOpacity(0.06),
                ),
          boxShadow: isMe
              ? [
                  BoxShadow(
                    color: AppColors.blue.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  if (!dark)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isMe ? Colors.white : (dark ? Colors.white : Colors.black87),
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildPendingProposalPreview() {
    final p = _pendingProposal!;
    final poster = p['poster'] ?? p['poster_local'];
    final date = p['date'] ?? '';
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppColors.darkCard,
        border: Border.all(color: AppColors.cyan.withOpacity(0.4)),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.cyan, AppColors.purple],
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.movie_outlined, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your movie suggestion — send it?',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                Icon(Icons.auto_awesome, color: Colors.white70, size: 14),
              ],
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (poster != null)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(18),
                  ),
                  child: Image.network(
                    poster,
                    width: 100,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const SizedBox(width: 100, height: 150),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p['movie'] ?? 'Unknown Movie',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p['genre'] ?? '',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (date.isNotEmpty)
                        _CinemaChip(icon: Icons.calendar_today, label: date),
                      const SizedBox(height: 4),
                      _CinemaChip(
                        icon: Icons.schedule,
                        label: p['time'] ?? '8:00 PM',
                      ),
                      const SizedBox(height: 4),
                      _CinemaChip(
                        icon: Icons.theaters,
                        label: p['location'] ?? 'Cinema',
                      ),
                      const SizedBox(height: 4),
                      if (p['rating'] != null)
                        _CinemaChip(icon: Icons.star, label: p['rating']),
                      const SizedBox(height: 6),
                      Text(
                        p['aiReason'] ?? p['message'] ?? '',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _dismissPendingProposal,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Maybe later',
                      style: TextStyle(color: Colors.white38),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _sendMovieProposal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.purple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Send suggestion 🎬',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingProposalCard() {
    final movie = (_incomingProposal?['movie'] as Map<String, dynamic>?) ?? {};
    final poster = movie['poster'] ?? movie['poster_local'];
    final date = movie['date'] ?? '';
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppColors.darkCard,
        border: Border.all(color: AppColors.purple.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(color: AppColors.purple.withOpacity(0.12), blurRadius: 16),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.purple, AppColors.pink],
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_movies_outlined,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.otherUser['name'] ?? 'Your match'} wants a movie date! 🎬',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (poster != null)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(18),
                  ),
                  child: Image.network(
                    poster,
                    width: 100,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const SizedBox(width: 100, height: 150),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movie['movie'] ?? 'Unknown Movie',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        movie['genre'] ?? '',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (date.isNotEmpty)
                        _CinemaChip(icon: Icons.calendar_today, label: date),
                      const SizedBox(height: 4),
                      _CinemaChip(
                        icon: Icons.schedule,
                        label: movie['time'] ?? '8:00 PM',
                      ),
                      const SizedBox(height: 4),
                      _CinemaChip(
                        icon: Icons.theaters,
                        label: movie['location'] ?? 'Cinema',
                      ),
                      const SizedBox(height: 4),
                      if (movie['rating'] != null)
                        _CinemaChip(icon: Icons.star, label: movie['rating']),
                      const SizedBox(height: 6),
                      Text(
                        movie['aiReason'] ?? movie['message'] ?? '',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _respondToProposal(false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Not now 😊',
                      style: TextStyle(color: Colors.white38),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => _respondToProposal(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.purple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      "I'm in! 🔥",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcebreakerBar() => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    decoration: BoxDecoration(
      color: AppColors.darkSurface,
      border: Border(top: BorderSide(color: AppColors.cyan.withOpacity(0.12))),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.cyan, size: 13),
            const SizedBox(width: 5),
            const Text(
              'AI Suggestions',
              style: TextStyle(
                color: AppColors.cyan,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                setState(() {
                  _icebreakersLoaded = false;
                  _aiIcebreakers = [];
                });
                _loadAiIcebreakers();
              },
              child: const Icon(Icons.refresh, color: Colors.white30, size: 15),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => setState(() => _icebreakersDismissed = true),
              child: const Icon(Icons.close, color: Colors.white30, size: 15),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _aiIcebreakers
                .map(
                  (msg) => Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 6),
                    child: GestureDetector(
                      onTap: () {
                        _sendMessage(msg);
                        setState(() {
                          _icebreakersLoaded = false;
                          _aiIcebreakers = [];
                        });
                        _loadAiIcebreakers();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.darkCard,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.cyan.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          msg,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    ),
  );

  Widget _buildInputBar() {
    final dark = isDark(context);
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: dark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: dark
                        ? Colors.white.withOpacity(0.07)
                        : Colors.black.withOpacity(0.07),
                  ),
                ),
                child: TextField(
                  controller: _msgCtrl,
                  decoration: InputDecoration(
                    hintText: 'Type a message…',
                    hintStyle: TextStyle(
                      color: dark ? Colors.white24 : Colors.black38,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: TextStyle(color: dark ? Colors.white : Colors.black87),
                  onSubmitted: _sendMessage,
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _sendMessage(_msgCtrl.text),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.cyan, AppColors.purple],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cyan.withOpacity(0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CinemaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _CinemaChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.07),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.cyan, size: 12),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    ),
  );
}

// ==========================================
// PROFILE TAB
// ==========================================
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  List<String> interests = [];
  List<String> firebaseImageUrls = ['', '', ''];
  List<XFile?> newlyPickedPhotos = [null, null, null];
  bool isSaving = false;

  final List<String> availableInterests = [
    "Gaming 🎮",
    "Coffee ☕️",
    "Music 🎵",
    "Foodie 🍕",
    "Gym 💪",
    "Art 🎨",
    "Movies 🎬",
  ];

  final String imgbbApiKey = 'a2fc26f7c2aba3390744731b43ea006d';

  @override
  void initState() {
    super.initState();
    _loadFirebaseData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFirebaseData() async {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (doc.exists) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      setState(() {
        _nameCtrl.text = data['name'] ?? '';
        _ageCtrl.text = data['age']?.toString() ?? '';
        _bioCtrl.text = data['bio'] ?? '';
        if (data['interests'] != null)
          interests = List<String>.from(data['interests']);
        if (data['images'] != null) {
          List<String> loaded = List<String>.from(data['images']);
          for (int i = 0; i < loaded.length && i < 3; i++) {
            firebaseImageUrls[i] = loaded[i];
          }
        }
      });
    }
  }

  Future<String?> _uploadToImgBB(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final response = await http.post(
        Uri.parse('https://api.imgbb.com/1/upload'),
        body: {'key': imgbbApiKey, 'image': base64Encode(bytes)},
      );
      if (response.statusCode == 200)
        return jsonDecode(response.body)['data']['display_url'];
    } catch (e) {
      debugPrint('ImgBB error: $e');
    }
    return null;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => isSaving = true);
    String uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      for (int i = 0; i < 3; i++) {
        if (newlyPickedPhotos[i] != null) {
          String? newUrl = await _uploadToImgBB(newlyPickedPhotos[i]!);
          if (newUrl != null) firebaseImageUrls[i] = newUrl;
        }
      }
      List<String> finalImages = firebaseImageUrls
          .where((url) => url.isNotEmpty)
          .toList();
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'name': _nameCtrl.text.trim(),
        'age': int.parse(_ageCtrl.text.trim()),
        'bio': _bioCtrl.text.trim(),
        'interests': interests,
        'images': finalImages,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated ✅'),
            backgroundColor: AppColors.purple,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
          newlyPickedPhotos = [null, null, null];
        });
      }
    }
  }

  void _showInterestsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose your interests',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: availableInterests.map((interest) {
                  bool isSel = interests.contains(interest);
                  return FilterChip(
                    label: Text(interest),
                    selected: isSel,
                    selectedColor: AppColors.cyan.withOpacity(0.2),
                    checkmarkColor: AppColors.cyan,
                    side: BorderSide(
                      color: isSel ? AppColors.cyan : Colors.white24,
                    ),
                    backgroundColor: AppColors.darkCard,
                    labelStyle: TextStyle(
                      color: isSel ? AppColors.cyan : Colors.white70,
                    ),
                    onSelected: (sel) {
                      setModalState(() {
                        if (sel)
                          interests.add(interest);
                        else
                          interests.remove(interest);
                      });
                      setState(() {});
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _clearImage(int index) => setState(() {
    newlyPickedPhotos[index] = null;
    firebaseImageUrls[index] = '';
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: TextStyle(
            color: isDark(context) ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 26,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: isDark(context) ? AppColors.cyan : AppColors.blue,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 250,
                child: Row(
                  children: [
                    Expanded(flex: 2, child: _buildPhotoBox(0, isMain: true)),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          Expanded(child: _buildPhotoBox(1)),
                          const SizedBox(height: 12),
                          Expanded(child: _buildPhotoBox(2)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _SectionLabel('About Me'),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nameCtrl,
                decoration: _inputDeco(context, 'Name', Icons.person_outline),
                validator: (v) => v!.isEmpty ? 'Required' : null,
                style: _inputStyle(context),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _ageCtrl,
                keyboardType: TextInputType.number,
                decoration: _inputDeco(context, 'Age', Icons.cake_outlined),
                style: _inputStyle(context),
                validator: (v) {
                  int? p = int.tryParse(v ?? '');
                  if (p == null || p < 18) return '18+ only';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _bioCtrl,
                maxLines: 3,
                maxLength: 150,
                decoration: _inputDeco(context, 'Bio', Icons.edit_outlined),
                style: _inputStyle(context),
              ),
              const SizedBox(height: 28),
              _SectionLabel('Interests'),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ...interests.map(
                    (i) => Chip(
                      label: Text(
                        i,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      backgroundColor: AppColors.purple.withOpacity(0.2),
                      side: const BorderSide(color: AppColors.purple, width: 1),
                      deleteIcon: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white54,
                      ),
                      onDeleted: () => setState(() => interests.remove(i)),
                    ),
                  ),
                  ActionChip(
                    backgroundColor: Colors.transparent,
                    side: const BorderSide(color: Colors.white24),
                    label: const Text(
                      '+ Add',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    onPressed: _showInterestsModal,
                  ),
                ],
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: isSaving
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.cyan),
                      )
                    : _GradientButton(
                        label: 'Save Profile',
                        onTap: _saveProfile,
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoBox(int index, {bool isMain = false}) {
    final dark = isDark(context);
    XFile? localFile = newlyPickedPhotos[index];
    String savedUrl = firebaseImageUrls[index];
    ImageProvider? imageProvider;
    if (localFile != null)
      imageProvider = kIsWeb
          ? NetworkImage(localFile.path)
          : FileImage(File(localFile.path)) as ImageProvider;
    else if (savedUrl.isNotEmpty)
      imageProvider = NetworkImage(savedUrl);

    return Stack(
      children: [
        GestureDetector(
          onTap: () async {
            final img = await ImagePicker().pickImage(
              source: ImageSource.gallery,
              imageQuality: 85,
            );
            if (img != null) setState(() => newlyPickedPhotos[index] = img);
          },
          child: Container(
            decoration: BoxDecoration(
              color: dark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isMain
                    ? AppColors.purple.withOpacity(0.5)
                    : (dark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.08)),
                width: isMain ? 1.5 : 1,
              ),
              image: imageProvider != null
                  ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                  : null,
            ),
            child: imageProvider == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          color: dark ? Colors.white24 : Colors.black26,
                          size: isMain ? 32 : 22,
                        ),
                        if (isMain) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Main Photo',
                            style: TextStyle(
                              color: dark ? Colors.white24 : Colors.black38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : null,
          ),
        ),
        if (imageProvider != null)
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _clearImage(index),
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppColors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  InputDecoration _inputDeco(BuildContext context, String hint, IconData icon) {
    final dark = isDark(context);
    return InputDecoration(
      labelText: hint,
      labelStyle: TextStyle(color: dark ? Colors.white38 : Colors.black45),
      prefixIcon: Icon(
        icon,
        color: dark ? Colors.white24 : Colors.black38,
        size: 18,
      ),
      filled: true,
      fillColor: dark ? AppColors.darkSurface : AppColors.lightSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: dark
              ? Colors.white.withOpacity(0.07)
              : Colors.black.withOpacity(0.07),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.cyan, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.red),
      ),
    );
  }

  TextStyle _inputStyle(BuildContext context) =>
      TextStyle(color: isDark(context) ? Colors.white : Colors.black87);
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      color: AppColors.cyan,
      fontWeight: FontWeight.bold,
      fontSize: 12,
      letterSpacing: 1.2,
    ),
  );
}

// ==========================================
// SETTINGS SCREEN
// ==========================================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double minAge = 18;
  double maxAge = 40;
  double maxDistance = 50;
  String location = 'Loading...';
  bool isLoading = true;
  bool _notificationsEnabled = true;
  bool _showMeOnApp = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (doc.exists) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      Map<String, dynamic> settings =
          data['discoverySettings'] ??
          {'minAge': 18, 'maxAge': 40, 'maxDistance': 50};
      setState(() {
        minAge = (settings['minAge'] ?? 18).toDouble();
        maxAge = (settings['maxAge'] ?? 40).toDouble();
        maxDistance = (settings['maxDistance'] ?? 50).toDouble();
        location = data['location'] ?? 'New York';
        _notificationsEnabled = data['notificationsEnabled'] ?? true;
        _showMeOnApp = data['showMeOnApp'] ?? true;
        isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'discoverySettings': {
        'minAge': minAge.toInt(),
        'maxAge': maxAge.toInt(),
        'maxDistance': maxDistance.toInt(),
      },
      'location': location,
      'notificationsEnabled': _notificationsEnabled,
      'showMeOnApp': _showMeOnApp,
    });
  }

  void _editLocation() {
    final ctrl = TextEditingController(text: location);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Set Location',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter city name',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.cyan),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white38),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => location = ctrl.text.trim());
              _saveSettings();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cyan,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Save',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _changePassword() {
    final _currentCtrl = TextEditingController();
    final _newCtrl = TextEditingController();
    final _confirmCtrl = TextEditingController();
    bool obscure1 = true, obscure2 = true, obscure3 = true;
    bool isChanging = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Change Password',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(
                ctrl: _currentCtrl,
                hint: 'Current password',
                obscure: obscure1,
                toggle: () => setDialogState(() => obscure1 = !obscure1),
              ),
              const SizedBox(height: 12),
              _dialogField(
                ctrl: _newCtrl,
                hint: 'New password',
                obscure: obscure2,
                toggle: () => setDialogState(() => obscure2 = !obscure2),
              ),
              const SizedBox(height: 12),
              _dialogField(
                ctrl: _confirmCtrl,
                hint: 'Confirm new password',
                obscure: obscure3,
                toggle: () => setDialogState(() => obscure3 = !obscure3),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white38),
              ),
            ),
            ElevatedButton(
              onPressed: isChanging
                  ? null
                  : () async {
                      if (_newCtrl.text != _confirmCtrl.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('New passwords do not match.'),
                            backgroundColor: AppColors.red,
                          ),
                        );
                        return;
                      }
                      if (_newCtrl.text.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Password must be at least 6 characters.',
                            ),
                            backgroundColor: AppColors.red,
                          ),
                        );
                        return;
                      }
                      setDialogState(() => isChanging = true);
                      try {
                        User user = FirebaseAuth.instance.currentUser!;
                        AuthCredential cred = EmailAuthProvider.credential(
                          email: user.email!,
                          password: _currentCtrl.text,
                        );
                        await user.reauthenticateWithCredential(cred);
                        await user.updatePassword(_newCtrl.text);
                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password changed successfully ✅'),
                              backgroundColor: AppColors.purple,
                            ),
                          );
                        }
                      } on FirebaseAuthException catch (e) {
                        String msg = 'Failed to update password.';
                        if (e.code == 'wrong-password')
                          msg = 'Current password is incorrect.';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(msg),
                            backgroundColor: AppColors.red,
                          ),
                        );
                      } finally {
                        setDialogState(() => isChanging = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cyan,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isChanging
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      'Update',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField({
    required TextEditingController ctrl,
    required String hint,
    required bool obscure,
    required VoidCallback toggle,
  }) => TextField(
    controller: ctrl,
    obscureText: obscure,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      suffixIcon: IconButton(
        icon: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: Colors.white38,
          size: 18,
        ),
        onPressed: toggle,
      ),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.white24),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.cyan),
      ),
    ),
  );

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Account',
          style: TextStyle(color: AppColors.red, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This action is permanent and cannot be undone. All your data, matches, and messages will be deleted.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white38),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAccount();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Delete Forever',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      await FirebaseAuth.instance.currentUser!.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please sign out and sign back in before deleting your account.',
              ),
              backgroundColor: AppColors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading)
      return const Scaffold(
        backgroundColor: AppColors.darkBg,
        body: Center(child: CircularProgressIndicator(color: AppColors.cyan)),
      );

    bool dark = isDark(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsSection(label: 'Discovery'),
          _SettingsTile(
            icon: Icons.location_on_outlined,
            title: 'Location',
            trailing: Text(
              location,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            onTap: _editLocation,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Maximum Distance',
                  style: TextStyle(
                    color: dark ? Colors.white : Colors.black,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${maxDistance.toInt()} mi',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
          Slider(
            value: maxDistance,
            min: 1,
            max: 100,
            activeColor: AppColors.cyan,
            inactiveColor: Colors.white12,
            onChanged: (val) => setState(() => maxDistance = val),
            onChangeEnd: (_) => _saveSettings(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Age Range',
                  style: TextStyle(
                    color: dark ? Colors.white : Colors.black,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${minAge.toInt()} – ${maxAge.toInt()}',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
          RangeSlider(
            values: RangeValues(minAge, maxAge),
            min: 18,
            max: 80,
            activeColor: AppColors.cyan,
            inactiveColor: Colors.white12,
            onChanged: (val) => setState(() {
              minAge = val.start;
              maxAge = val.end;
            }),
            onChangeEnd: (_) => _saveSettings(),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.visibility_outlined,
            title: 'Show me on NeonMatch',
            trailing: Switch(
              value: _showMeOnApp,
              activeColor: AppColors.cyan,
              onChanged: (val) {
                setState(() => _showMeOnApp = val);
                _saveSettings();
              },
            ),
          ),
          const SizedBox(height: 8),
          _SettingsSection(label: 'Notifications'),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Push Notifications',
            trailing: Switch(
              value: _notificationsEnabled,
              activeColor: AppColors.cyan,
              onChanged: (val) {
                setState(() => _notificationsEnabled = val);
                _saveSettings();
              },
            ),
          ),
          const SizedBox(height: 8),
          _SettingsSection(label: 'App Settings'),
          _SettingsTile(
            icon: dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            title: dark ? 'Light Mode' : 'Dark Mode',
            trailing: Switch(
              value: dark,
              activeColor: AppColors.cyan,
              onChanged: (_) => appState.toggleTheme(),
            ),
          ),
          const SizedBox(height: 8),
          _SettingsSection(label: 'Account'),
          _SettingsTile(
            icon: Icons.lock_outline,
            title: 'Change Password',
            trailing: const Icon(Icons.chevron_right, color: Colors.white24),
            onTap: _changePassword,
          ),
          _SettingsTile(
            icon: Icons.help_outline,
            title: 'Help & Support',
            trailing: const Icon(Icons.chevron_right, color: Colors.white24),
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            trailing: const Icon(Icons.chevron_right, color: Colors.white24),
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'About GEN Ƶ',
            trailing: const Text(
              'v1.0.0',
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
            onTap: () {},
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.logout, color: Colors.white54),
            label: const Text(
              'Sign Out',
              style: TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white12),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _showDeleteAccountDialog,
            icon: const Icon(Icons.delete_forever, color: AppColors.red),
            label: const Text(
              'Delete Account',
              style: TextStyle(
                color: AppColors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.red.withOpacity(0.3)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String label;
  const _SettingsSection({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppColors.cyan,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.4,
      ),
    ),
  );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Icon(
        icon,
        color: dark ? Colors.white38 : Colors.black45,
        size: 20,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: dark ? Colors.white : Colors.black87,
          fontSize: 15,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
