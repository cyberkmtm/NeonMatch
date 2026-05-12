import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
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
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(const NeonDatingApp());
}

// ==========================================
// 1. GLOBAL STATE & THEME
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
  static const Color pink = Color(0xFFFF00A0); // NEW: Cyberpunk Pink
  static const Color blue = Color(0xFF0066FF);
  static const Color purple = Color(0xFF8A2BE2);
  static const Color darkPurple = Color(0xFF1E0033); // NEW: Deep Neon Purple
  static const Color red = Color(0xFFFF0055);

  static const Color darkBg = Color(0xFF030508); // Much darker background
  static const Color darkSurface = Color(0xFF0D111A);

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
      secondary: AppColors.pink,
      surface: AppColors.darkSurface,
    ),
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
// 2. APP INITIALIZATION
// ==========================================
class NeonDatingApp extends StatelessWidget {
  const NeonDatingApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, child) => MaterialApp(
        title: 'Neon Match',
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
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        if (snapshot.hasData) return const MainNavigator();
        return const AuthScreen();
      },
    );
  }
}

// ==========================================
// 3. CYBERPUNK CIRCUIT ANIMATION
// ==========================================
class DataPulse {
  final double staticPos; // The fixed X or Y coordinate (percentage 0.0 to 1.0)
  final double speed; // Speed of the pulse
  final double length; // Length of the pulse tail
  final bool isHorizontal; // Direction
  final Color color; // Pink or Cyan
  final double offset; // Starting offset

  DataPulse(
    this.staticPos,
    this.speed,
    this.length,
    this.isHorizontal,
    this.color,
    this.offset,
  );
}

class CircuitPainter extends CustomPainter {
  final List<DataPulse> pulses;
  final double animationValue;

  CircuitPainter(this.pulses, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    final Paint corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var pulse in pulses) {
      double movingPos = (pulse.offset + (animationValue * pulse.speed)) % 1.0;

      double startX = pulse.isHorizontal
          ? movingPos * size.width
          : pulse.staticPos * size.width;
      double startY = pulse.isHorizontal
          ? pulse.staticPos * size.height
          : movingPos * size.height;

      double tailLength =
          pulse.length * (pulse.isHorizontal ? size.width : size.height);

      double endX = pulse.isHorizontal ? startX - tailLength : startX;
      double endY = pulse.isHorizontal ? startY : startY - tailLength;

      // Create fading tail gradient
      final Gradient gradient = LinearGradient(
        colors: [pulse.color, pulse.color.withOpacity(0.0)],
        begin: pulse.isHorizontal
            ? Alignment.centerRight
            : Alignment.bottomCenter,
        end: pulse.isHorizontal ? Alignment.centerLeft : Alignment.topCenter,
      );

      final Rect rect = Rect.fromPoints(
        Offset(startX, startY),
        Offset(endX, endY),
      );
      glowPaint.shader = gradient.createShader(rect);
      corePaint.shader = gradient.createShader(rect);

      // Draw glow then core
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), glowPaint);
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ==========================================
// 4. DARK NEON AUTH SCREEN
// ==========================================
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool isLogin = true;
  final _formKey = GlobalKey<FormState>();
  String email = '', password = '', name = '', age = '', gender = 'Male';

  late AnimationController _animController;
  final List<DataPulse> _pulses = [];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // Generate Circuit Pulses
    final rng = Random();
    for (int i = 0; i < 40; i++) {
      bool isHoriz = rng.nextBool();
      Color c = rng.nextBool() ? AppColors.cyan : AppColors.pink;
      _pulses.add(
        DataPulse(
          rng.nextDouble(), // Static position
          rng.nextDouble() * 1.5 + 0.5, // Speed
          rng.nextDouble() * 0.15 + 0.05, // Length of tail
          isHoriz,
          c,
          rng.nextDouble(), // Direction, Color, Start Offset
        ),
      );
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        UserCredential user = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.user!.uid)
            .set({
              'uid': user.user!.uid,
              'name': name,
              'age': int.parse(age),
              'gender': gender,
              'bio': 'New here!',
              'interests': [],
              'images': [],
            });
      }
    } on FirebaseAuthException catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Username or password is incorrect.",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        children: [
          // Deep Dark Purple Orbs (Background Glows)
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.darkPurple.withOpacity(0.8),
                boxShadow: [
                  BoxShadow(color: AppColors.darkPurple, blurRadius: 150),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -150,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.darkPurple.withOpacity(0.6),
                boxShadow: [
                  BoxShadow(color: AppColors.darkPurple, blurRadius: 150),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: 50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cyan.withOpacity(0.1),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cyan.withOpacity(0.2),
                    blurRadius: 150,
                  ),
                ],
              ),
            ),
          ),

          // Animated Cyber Circuit
          AnimatedBuilder(
            animation: _animController,
            builder: (context, child) => CustomPaint(
              painter: CircuitPainter(_pulses, _animController.value),
              size: Size.infinite,
            ),
          ),

          // Glassmorphism Form
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFF0B0F1A,
                      ).withOpacity(0.6), // Dark Frosted Glass
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: AppColors.cyan.withOpacity(0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.pink.withOpacity(0.05),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isLogin ? "NEON MATCH" : "JOIN NEON",
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(color: AppColors.cyan, blurRadius: 15),
                                Shadow(color: AppColors.pink, blurRadius: 15),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            isLogin
                                ? "Connect to the grid"
                                : "Initialize your profile",
                            style: const TextStyle(color: AppColors.cyan),
                          ),
                          const SizedBox(height: 40),

                          if (!isLogin) ...[
                            TextFormField(
                              decoration: _glassInputDeco(
                                "First Name",
                                Icons.person,
                              ),
                              style: const TextStyle(color: Colors.white),
                              onSaved: (val) => name = val!,
                              validator: (val) =>
                                  val!.isEmpty ? "Required" : null,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    decoration: _glassInputDeco(
                                      "Age",
                                      Icons.numbers,
                                    ),
                                    style: const TextStyle(color: Colors.white),
                                    keyboardType: TextInputType.number,
                                    onSaved: (val) => age = val!,
                                    validator: (val) {
                                      int? p = int.tryParse(val ?? "");
                                      if (p == null || p < 18)
                                        return "18+ only";
                                      if (p > 80) return "Invalid";
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: gender,
                                    decoration: _glassInputDeco(
                                      "Gender",
                                      Icons.wc,
                                    ),
                                    dropdownColor: AppColors.darkSurface,
                                    style: const TextStyle(color: Colors.white),
                                    items: ['Male', 'Female']
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(e),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (val) =>
                                        setState(() => gender = val!),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            decoration: _glassInputDeco("Email", Icons.email),
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.emailAddress,
                            onSaved: (val) => email = val!,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            decoration: _glassInputDeco("Password", Icons.lock),
                            style: const TextStyle(color: Colors.white),
                            obscureText: true,
                            onSaved: (val) => password = val!,
                          ),
                          const SizedBox(height: 40),

                          // Cyberpunk Gradient Button
                          GestureDetector(
                            onTap: _submit,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: const LinearGradient(
                                  colors: [AppColors.cyan, AppColors.pink],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.pink.withOpacity(0.4),
                                    blurRadius: 15,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                isLogin ? "INITIALIZE" : "REGISTER",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextButton(
                            onPressed: () => setState(() => isLogin = !isLogin),
                            child: Text(
                              isLogin
                                  ? "New to the grid? Create account"
                                  : "Already active? Login",
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _glassInputDeco(String hint, IconData icon) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: AppColors.cyan),
        filled: true,
        fillColor: Colors.black.withOpacity(0.3),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.purple.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.pink, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.red),
        ),
      );
}

// ==========================================
// 5. DETAILED USER PROFILE SCREEN
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: PageView.builder(
                itemCount: images.length,
                itemBuilder: (context, index) =>
                    Image.network(images[index], fit: BoxFit.cover),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '${user['name'] ?? 'Unknown'}, ${user['age'] ?? '?'}',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: isDark(context) ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.verified,
                        color: AppColors.cyan,
                        size: 28,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person, color: Colors.grey, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        user['gender'] ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Divider(color: Colors.grey),
                  ),
                  const Text(
                    "About Me",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.pink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user['bio'] ?? 'This user is a mystery.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: isDark(context) ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 30),
                  if (interests.isNotEmpty) ...[
                    const Text(
                      "Interests",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.cyan,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: interests
                          .map(
                            (i) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.cyan.withOpacity(0.1),
                                border: Border.all(color: AppColors.cyan),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                i,
                                style: TextStyle(
                                  color: isDark(context)
                                      ? Colors.white
                                      : Colors.black,
                                  fontWeight: FontWeight.w600,
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
// 6. MAIN NAVIGATOR
// ==========================================
class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});
  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const SwipeTab(),
    const DiscoverTab(),
    const MatchesTab(),
    const ChatListTab(),
    const ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        currentIndex: _currentIndex,
        selectedItemColor: isDark(context) ? AppColors.cyan : AppColors.blue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.style), label: 'Swipe'),
          BottomNavigationBarItem(
            icon: Icon(Icons.travel_explore),
            label: 'Discover',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Matches'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// ==========================================
// 7. SWIPE TAB
// ==========================================
class SwipeTab extends StatefulWidget {
  final Map<String, dynamic>? specificUser;
  final String? filterInterest;
  const SwipeTab({super.key, this.specificUser, this.filterInterest});

  @override
  State<SwipeTab> createState() => _SwipeTabState();
}

class _SwipeTabState extends State<SwipeTab> {
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
    String targetGender = (myData['gender'] ?? 'Male') == 'Male'
        ? 'Female'
        : 'Male';

    QuerySnapshot usersQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('gender', isEqualTo: targetGender)
        .get();
    QuerySnapshot mySwipes = await FirebaseFirestore.instance
        .collection('swipes')
        .doc(myUid)
        .collection('interactions')
        .get();
    List<String> swipedIds = mySwipes.docs.map((d) => d.id).toList();

    List<Map<String, dynamic>> loadedDeck = [];
    for (var doc in usersQuery.docs) {
      if (!swipedIds.contains(doc.id)) {
        Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
        userData['uid'] = userData.containsKey('uid')
            ? userData['uid']
            : doc.id;

        if (widget.filterInterest != null) {
          List interests = userData['interests'] ?? [];
          if (!interests.contains(widget.filterInterest)) continue;
        }
        loadedDeck.add(userData);
      }
    }
    setState(() {
      deck = loadedDeck;
      isLoading = false;
    });
  }

  void _swipe(bool isLike) async {
    if (deck.isEmpty) return;
    isLike ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact();
    String targetUid = deck.first['uid'],
        myUid = FirebaseAuth.instance.currentUser!.uid;

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("IT'S A MATCH! 🎉"),
            backgroundColor: AppColors.purple,
          ),
        );
      }
    }

    setState(() {
      deck.removeAt(0);
      _position = Offset.zero;
      _angle = 0;
    });
    if ((widget.specificUser != null || widget.filterInterest != null) &&
        deck.isEmpty)
      Navigator.pop(context);
  }

  void _onPanUpdate(DragUpdateDetails details) => setState(() {
    _position += details.delta;
    _angle = 45 * (_position.dx / MediaQuery.of(context).size.width);
    _isDragging = true;
  });
  void _onPanEnd(DragEndDetails details) {
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    bool isModal = widget.specificUser != null || widget.filterInterest != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: isModal ? const BackButton() : null,
        title: Text(
          widget.filterInterest ?? 'NeonMatch',
          style: TextStyle(
            color: isDark(context) ? AppColors.cyan : AppColors.blue,
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: deck.isEmpty
                ? const Center(child: Text("No profiles left!"))
                : Stack(
                    alignment: Alignment.center,
                    children: deck.reversed.map((user) {
                      int index = deck.indexOf(user);
                      return index == 0
                          ? _buildTopCard(user)
                          : Transform.scale(
                              scale: 1.0 - (index * 0.05),
                              child: Container(
                                margin: EdgeInsets.only(top: index * 20.0),
                                child: _buildCardUI(user, isTop: false),
                              ),
                            );
                    }).toList(),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () => _swipe(false),
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(
                        color: AppColors.red.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: AppColors.red,
                      size: 35,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _swipe(true),
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(
                        color: AppColors.cyan.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: AppColors.cyan,
                      size: 35,
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
    Color glow = isTop
        ? (lOp > 0
              ? AppColors.cyan.withOpacity(lOp * 0.8)
              : (nOp > 0
                    ? AppColors.red.withOpacity(nOp * 0.8)
                    : Colors.black26))
        : Colors.black26;

    List images = [];
    if (user['images'] != null)
      images = List.from(
        user['images'],
      ).where((u) => u.toString().isNotEmpty).toList();
    String imgUrl = images.isNotEmpty
        ? images[0]
        : 'https://images.unsplash.com/photo-1557683316-973673baf926?q=80&w=800';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: MediaQuery.of(context).size.width * 0.9,
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: glow, blurRadius: 20, spreadRadius: 5)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(child: Image.network(imgUrl, fit: BoxFit.cover)),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.6, 1.0],
                  ),
                ),
                padding: const EdgeInsets.all(24),
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${user['name'] ?? 'Unknown'}, ${user['age'] ?? '?'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      user['bio'] ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.white54,
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          "Tap for more info",
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (lOp > 0)
              Positioned(
                top: 40,
                left: 40,
                child: Transform.rotate(
                  angle: -0.2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.cyan, width: 4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      "LIKE",
                      style: TextStyle(
                        color: AppColors.cyan,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            if (nOp > 0)
              Positioned(
                top: 40,
                right: 40,
                child: Transform.rotate(
                  angle: 0.2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.red, width: 4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      "NOPE",
                      style: TextStyle(
                        color: AppColors.red,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
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

// ==========================================
// 8. DISCOVER TAB
// ==========================================
class DiscoverTab extends StatelessWidget {
  const DiscoverTab({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Discover',
          style: TextStyle(
            color: isDark(context) ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
        children: [
          _buildDiscoverTile(
            "Movie Date",
            "🎬",
            'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=800&q=80',
            AppColors.cyan,
            "Movies 🎬",
            context,
          ),
          _buildDiscoverTile(
            "Coffee Date",
            "☕️",
            'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=800&q=80',
            AppColors.pink,
            "Coffee ☕️",
            context,
          ),
          _buildDiscoverTile(
            "Music Event",
            "🎵",
            'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?w=800&q=80',
            AppColors.blue,
            "Music 🎵",
            context,
          ),
          _buildDiscoverTile(
            "Gamer Buddy",
            "🎮",
            'https://images.unsplash.com/photo-1511285560929-80b456fea0bc?w=800&q=80',
            AppColors.red,
            "Gaming 🎮",
            context,
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverTile(
    String title,
    String emoji,
    String imgUrl,
    Color neonColor,
    String filterTag,
    BuildContext context,
  ) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SwipeTab(filterInterest: filterTag)),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: neonColor.withOpacity(0.6), width: 2),
          image: DecorationImage(
            image: NetworkImage(imgUrl),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 9. MATCHES TAB
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
            fontSize: 28,
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
            return const Center(child: CircularProgressIndicator());
          var likes = snapshot.data!.docs;
          if (likes.isEmpty) return const Center(child: Text("No likes yet."));
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75,
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
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.pink.withOpacity(0.5),
                        ),
                        image: DecorationImage(
                          image: NetworkImage(img),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.8),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        padding: const EdgeInsets.all(12),
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          '${user['name'] ?? 'Unknown'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
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
// 10. CHAT LIST TAB
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
            fontSize: 28,
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
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          var matches = snapshot.data!.docs;
          if (matches.isEmpty)
            return const Center(child: Text("No matches yet."));

          return ListView.builder(
            itemCount: matches.length,
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
                    leading: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => UserProfileScreen(user: user),
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 30,
                        backgroundImage: NetworkImage(img),
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
                    ),
                    trailing: const Icon(
                      Icons.circle,
                      color: AppColors.pink,
                      size: 12,
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
  final TextEditingController _msgController = TextEditingController();
  bool _cinemaHandled = false;
  Map<String, dynamic>? mockoonData;

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    String message = text.trim();
    _msgController.clear();
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

  Future<void> _triggerAiCinema() async {
    if (_cinemaHandled || mockoonData != null) return;
    try {
      final res = await http.get(Uri.parse('http://127.0.0.1:3000/movies'));
      if (res.statusCode == 200)
        setState(() => mockoonData = jsonDecode(res.body));
    } catch (e) {
      setState(
        () => mockoonData = {
          "movie": "Dune 2",
          "time": "8:00 PM",
          "location": "Local Cinema",
          "message": "AI ALERT! Let's go to a movie.",
        },
      );
    }
  }

  void _handleCinemaAlert(bool accepted) async {
    setState(() => _cinemaHandled = true);
    String res = accepted
        ? "I accepted the movie date! 🔥 See you at ${mockoonData!['location']}?"
        : "Maybe next time! 😊";
    _sendMessage(res);
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
        title: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserProfileScreen(user: widget.otherUser),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(backgroundImage: NetworkImage(img)),
              const SizedBox(width: 12),
              Text(
                widget.otherUser['name'] ?? 'Unknown',
                style: TextStyle(
                  color: isDark(context) ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('matches')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                var docs = snapshot.data!.docs;
                int msgCount = docs.length;

                if (msgCount >= 4 && !_cinemaHandled && mockoonData == null)
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _triggerAiCinema(),
                  );

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(20),
                  itemCount:
                      msgCount +
                      (mockoonData != null && !_cinemaHandled ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (mockoonData != null && !_cinemaHandled && index == 0)
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _buildPushyCinemaAlert(),
                      );
                    int actualIndex = (mockoonData != null && !_cinemaHandled)
                        ? index - 1
                        : index;
                    var msg = docs[actualIndex];
                    bool isMe =
                        msg['senderId'] ==
                        FirebaseAuth.instance.currentUser!.uid;

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? (isDark(context)
                                    ? AppColors.blue
                                    : const Color(0xFF0055DD))
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(20).copyWith(
                            bottomRight: Radius.circular(isMe ? 0 : 20),
                            bottomLeft: Radius.circular(isMe ? 20 : 0),
                          ),
                        ),
                        child: Text(
                          msg['text'],
                          style: TextStyle(
                            color: isMe
                                ? Colors.white
                                : (isDark(context)
                                      ? Colors.white
                                      : Colors.black),
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('matches')
                .doc(widget.chatId)
                .collection('messages')
                .limit(1)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasData && snap.data!.docs.isEmpty)
                return _buildAiIcebreaker();
              return const SizedBox();
            },
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.surface,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: TextField(
                        controller: _msgController,
                        decoration: const InputDecoration(
                          hintText: 'Type...',
                          border: InputBorder.none,
                        ),
                        style: TextStyle(
                          color: isDark(context) ? Colors.white : Colors.black,
                        ),
                        onSubmitted: _sendMessage,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _sendMessage(_msgController.text),
                    child: CircleAvatar(
                      backgroundColor: AppColors.cyan,
                      child: const Icon(
                        Icons.send,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPushyCinemaAlert() => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: isDark(context) ? AppColors.darkSurface : Colors.white,
      border: Border.all(color: AppColors.cyan, width: 1.5),
    ),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: AppColors.cyan,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.black,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mockoonData!['message'] ?? 'Movie Match!',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                "'${mockoonData!['movie']}' at ${mockoonData!['location']} (${mockoonData!['time']}).",
                style: TextStyle(
                  color: isDark(context) ? Colors.white : Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => _handleCinemaAlert(false),
                    child: const Text(
                      "Too soon",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _handleCinemaAlert(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.pink,
                    ),
                    child: const Text(
                      "Accept Date 🔥",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _buildAiIcebreaker() => Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.pink, size: 16),
          const SizedBox(width: 8),
          ActionChip(
            label: const Text(
              "You look familiar 👀",
              style: TextStyle(color: AppColors.cyan),
            ),
            onPressed: () => _sendMessage("You look familiar 👀"),
          ),
          const SizedBox(width: 8),
          ActionChip(
            label: const Text(
              "What's your favorite movie? 🍿",
              style: TextStyle(color: AppColors.cyan),
            ),
            onPressed: () => _sendMessage("What's your favorite movie? 🍿"),
          ),
        ],
      ),
    ),
  );
}

// ==========================================
// 11. PROFILE TAB
// ==========================================
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController(),
      _ageCtrl = TextEditingController(),
      _bioCtrl = TextEditingController();
  List<String> interests = [], firebaseImageUrls = ['', '', ''];
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

  // ==========================================================
  // PASTE YOUR IMGBB KEY BELOW
  // ==========================================================
  final String imgbbApiKey = 'a2fc26f7c2aba3390744731b43ea006d';

  @override
  void initState() {
    super.initState();
    _loadFirebaseData();
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
          List<String> loadedUrls = List<String>.from(data['images']);
          for (int i = 0; i < loadedUrls.length && i < 3; i++)
            firebaseImageUrls[i] = loadedUrls[i];
        }
      });
    }
  }

  Future<String?> _uploadToImgBB(XFile imageFile) async {
    if (imgbbApiKey == 'PASTE_YOUR_API_KEY_HERE') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error: You forgot to paste your ImgBB API key!"),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
    try {
      final bytes = await imageFile.readAsBytes();
      final response = await http.post(
        Uri.parse('https://api.imgbb.com/1/upload'),
        body: {'key': imgbbApiKey, 'image': base64Encode(bytes)},
      );
      if (response.statusCode == 200)
        return jsonDecode(response.body)['data']['display_url'];
      else
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("ImgBB Error: ${response.body}"),
            backgroundColor: Colors.red,
          ),
        );
    } catch (e) {
      print(e);
    }
    return null;
  }

  void _saveProfile() async {
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
      List<String> finalImagesToSave = firebaseImageUrls
          .where((url) => url.isNotEmpty)
          .toList();
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'name': _nameCtrl.text,
        'age': int.parse(_ageCtrl.text),
        'bio': _bioCtrl.text,
        'interests': interests,
        'images': finalImagesToSave,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profile Updated! ✅"),
          backgroundColor: AppColors.purple,
        ),
      );
    } finally {
      setState(() {
        isSaving = false;
        newlyPickedPhotos = [null, null, null];
      });
    }
  }

  void _showInterestsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Select Interests",
                    style: TextStyle(
                      color: isDark(context) ? Colors.white : Colors.black,
                      fontSize: 20,
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
                        selectedColor: AppColors.pink.withOpacity(0.3),
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
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: TextStyle(
            color: isDark(context) ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.red),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
          IconButton(
            icon: Icon(
              isDark(context) ? Icons.light_mode : Icons.dark_mode,
              color: AppColors.cyan,
            ),
            onPressed: () => appState.toggleTheme(),
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
              const SizedBox(height: 30),
              const Text(
                "ABOUT ME",
                style: TextStyle(
                  color: AppColors.pink,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: _inputDeco("Name"),
                validator: (v) => v!.isEmpty ? "Required" : null,
                style: TextStyle(
                  color: isDark(context) ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ageCtrl,
                keyboardType: TextInputType.number,
                decoration: _inputDeco("Age"),
                style: TextStyle(
                  color: isDark(context) ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioCtrl,
                maxLines: 3,
                decoration: _inputDeco("Bio"),
                style: TextStyle(
                  color: isDark(context) ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                "INTERESTS",
                style: TextStyle(
                  color: AppColors.cyan,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ...interests.map(
                    (i) => Chip(
                      label: Text(
                        i,
                        style: TextStyle(
                          color: isDark(context) ? Colors.white : Colors.black,
                        ),
                      ),
                      backgroundColor: AppColors.cyan.withOpacity(0.1),
                      side: const BorderSide(color: AppColors.cyan),
                    ),
                  ),
                  ActionChip(
                    backgroundColor: Colors.transparent,
                    side: BorderSide(
                      color: Colors.grey[600]!,
                      style: BorderStyle.solid,
                    ),
                    label: const Text(
                      "+ Add",
                      style: TextStyle(color: Colors.grey),
                    ),
                    onPressed: _showInterestsModal,
                  ),
                ],
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark(context)
                        ? AppColors.pink
                        : AppColors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isSaving
                      ? const CircularProgressIndicator(color: Colors.black)
                      : Text(
                          "Save Profile",
                          style: TextStyle(
                            color: isDark(context)
                                ? Colors.white
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoBox(int index, {bool isMain = false}) {
    XFile? localFile = newlyPickedPhotos[index];
    String savedUrl = firebaseImageUrls[index];
    ImageProvider? imageProvider;
    if (localFile != null)
      imageProvider = kIsWeb
          ? NetworkImage(localFile.path)
          : FileImage(File(localFile.path)) as ImageProvider;
    else if (savedUrl.isNotEmpty)
      imageProvider = NetworkImage(savedUrl);
    return GestureDetector(
      onTap: () async {
        final img = await ImagePicker().pickImage(source: ImageSource.gallery);
        if (img != null) setState(() => newlyPickedPhotos[index] = img);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMain ? AppColors.pink : Colors.grey[800]!,
            width: isMain ? 2 : 1,
          ),
          image: imageProvider != null
              ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
              : null,
        ),
        child: imageProvider == null
            ? Center(
                child: Icon(Icons.add_a_photo, color: AppColors.cyan, size: 30),
              )
            : null,
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    labelText: hint,
    filled: true,
    fillColor: Theme.of(context).colorScheme.surface,
    labelStyle: const TextStyle(color: Colors.grey),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}
