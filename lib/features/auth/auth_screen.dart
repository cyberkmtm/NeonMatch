part of genz_app;

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
        final Map<String, dynamic> userData = {
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
  'location': 'Location not set',
  'notificationsEnabled': true,
  'showMeOnApp': true,
  'createdAt': FieldValue.serverTimestamp(),
};

try {
  final locationData = await LocationService.getCurrentLocationData();
  userData.addAll(locationData);
} catch (e) {
  debugPrint('Location setup skipped: $e');
}

await FirebaseFirestore.instance
    .collection('users')
    .doc(cred.user!.uid)
    .set(userData);
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
