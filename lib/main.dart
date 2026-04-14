import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  runApp(const NeonDatingApp());
}

// ==========================================
// 1. THEME & DESIGN SYSTEM
// ==========================================
class AppColors {
  static const Color cyan = Color(0xFF00F5FF);
  static const Color blue = Color(0xFF0066FF);
  static const Color purple = Color(0xFF8A2BE2);
  static const Color darkBg = Color(0xFF0B0F1A);
  static const Color darkSurface = Color(0xFF161B2B);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBg,
    primaryColor: AppColors.cyan,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.cyan,
      secondary: AppColors.purple,
      surface: AppColors.darkSurface,
    ),
    fontFamily: 'Roboto',
  );
}

// ==========================================
// 2. MOCK DATA MODELS
// ==========================================
class UserProfile {
  final String id;
  final String name;
  final int age;
  final String image;
  final String bio;
  UserProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.image,
    required this.bio,
  });
}

final List<UserProfile> mockSwipeDeck = [
  UserProfile(
    id: '1',
    name: 'Elena',
    age: 24,
    image:
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&q=80',
    bio: 'Coffee & tech. ☕️',
  ),
  UserProfile(
    id: '2',
    name: 'Marcus',
    age: 27,
    image:
        'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=800&q=80',
    bio: 'Adventure seeker. 🏔️',
  ),
  UserProfile(
    id: '3',
    name: 'Sarah',
    age: 23,
    image:
        'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=800&q=80',
    bio: 'Art & music 🎨',
  ),
];

final List<UserProfile> mockLikedMe = [
  UserProfile(
    id: '4',
    name: 'Jessica',
    age: 25,
    image:
        'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=800&q=80',
    bio: 'Always down for a movie.',
  ),
  UserProfile(
    id: '5',
    name: 'David',
    age: 28,
    image:
        'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=800&q=80',
    bio: 'Gym & pizza.',
  ),
];

// ==========================================
// 3. MAIN NAVIGATION (5 TABS)
// ==========================================
class NeonDatingApp extends StatelessWidget {
  const NeonDatingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neon Match',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const MainNavigator(),
    );
  }
}

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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: AppColors.cyan.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: AppColors.darkSurface,
          currentIndex: _currentIndex,
          selectedItemColor: AppColors.cyan,
          unselectedItemColor: Colors.grey[600],
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          onTap: (index) {
            HapticFeedback.lightImpact();
            setState(() => _currentIndex = index);
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
// TAB 1: SWIPE (Pure Tinder-like Interface)
// ==========================================
class SwipeTab extends StatefulWidget {
  final List<UserProfile>?
  specificUser; // Used for "Matches" screen integration
  const SwipeTab({super.key, this.specificUser});

  @override
  State<SwipeTab> createState() => _SwipeTabState();
}

class _SwipeTabState extends State<SwipeTab> {
  late List<UserProfile> deck;
  Offset _position = Offset.zero;
  bool _isDragging = false;
  double _angle = 0;

  @override
  void initState() {
    super.initState();
    deck = widget.specificUser ?? List.from(mockSwipeDeck);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _position += details.delta;
      _angle = 45 * (_position.dx / MediaQuery.of(context).size.width);
      _isDragging = true;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() => _isDragging = false);
    if (_position.dx > 100) {
      _swipe(true);
    } else if (_position.dx < -100) {
      _swipe(false);
    } else {
      setState(() {
        _position = Offset.zero;
        _angle = 0;
      });
    }
  }

  void _swipe(bool isRight) {
    isRight ? HapticFeedback.heavyImpact() : HapticFeedback.lightImpact();
    setState(() {
      deck.removeAt(0);
      _position = Offset.zero;
      _angle = 0;
    });

    if (widget.specificUser != null && deck.isEmpty) {
      Navigator.pop(
        context,
      ); // Return to Matches tab if viewing a specific match
    } else if (deck.isEmpty) {
      setState(() => deck = List.from(mockSwipeDeck)); // Loop for demo
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.specificUser == null
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text(
                'NeonMatch',
                style: TextStyle(
                  color: AppColors.cyan,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                  letterSpacing: 1,
                ),
              ),
            )
          : AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Column(
        children: [
          Expanded(
            child: deck.isEmpty
                ? const Center(child: Text("No more profiles!"))
                : Stack(
                    alignment: Alignment.center,
                    children: deck.reversed.map((user) {
                      int index = deck.indexOf(user);
                      return index == 0
                          ? _buildTopCard(user)
                          : _buildBackgroundCard(user, index);
                    }).toList(),
                  ),
          ),
          _buildBottomActionButtons(),
        ],
      ),
    );
  }

  Widget _buildTopCard(UserProfile user) {
    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: AnimatedContainer(
        duration: _isDragging
            ? Duration.zero
            : const Duration(milliseconds: 300),
        transform: Matrix4.identity()
          ..translate(_position.dx, _position.dy)
          ..rotateZ(_angle * (pi / 180)),
        child: _buildCardUI(user),
      ),
    );
  }

  Widget _buildBackgroundCard(UserProfile user, int index) {
    return Transform.scale(
      scale: 1.0 - (index * 0.05),
      child: Container(
        margin: EdgeInsets.only(top: index * 20.0),
        child: _buildCardUI(user),
      ),
    );
  }

  Widget _buildCardUI(UserProfile user) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.cyan.withOpacity(0.1), blurRadius: 15),
        ],
        image: DecorationImage(
          image: NetworkImage(user.image),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.6, 1.0],
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${user.name}, ${user.age}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              user.bio,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNeonButton(Icons.close, Colors.redAccent, () => _swipe(false)),
          _buildNeonButton(Icons.favorite, AppColors.cyan, () => _swipe(true)),
        ],
      ),
    );
  }

  Widget _buildNeonButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.darkSurface,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
          border: Border.all(color: color.withOpacity(0.5), width: 2),
        ),
        child: Icon(icon, color: color, size: 35),
      ),
    );
  }
}

// ==========================================
// TAB 2: DISCOVER (Intent Modes)
// ==========================================
class DiscoverTab extends StatelessWidget {
  const DiscoverTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Discover',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28),
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
            context,
          ),
          _buildDiscoverTile(
            "Coffee Date",
            "☕️",
            'https://images.unsplash.com/photo-1554118811-1e0d58224f24?w=800&q=80',
            AppColors.purple,
            context,
          ),
          _buildDiscoverTile(
            "Event Buddies",
            "🎉",
            'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?w=800&q=80',
            AppColors.blue,
            context,
          ),
          _buildDiscoverTile(
            "FWB",
            "🔥",
            'https://images.unsplash.com/photo-1511285560929-80b456fea0bc?w=800&q=80',
            Colors.pinkAccent,
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
    BuildContext context,
  ) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Looking for $title..."),
            backgroundColor: neonColor,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: neonColor.withOpacity(0.6), width: 2),
          boxShadow: [
            BoxShadow(color: neonColor.withOpacity(0.2), blurRadius: 15),
          ],
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
// TAB 3: MATCHES (Who Liked You)
// ==========================================
class MatchesTab extends StatelessWidget {
  const MatchesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'Likes You',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.cyan,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "${mockLikedMe.length}",
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: mockLikedMe.length,
        itemBuilder: (context, index) {
          final user = mockLikedMe[index];
          return GestureDetector(
            onTap: () {
              // Open specific user in Swipe view
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SwipeTab(specificUser: [user]),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.purple.withOpacity(0.5)),
                image: DecorationImage(
                  image: NetworkImage(user.image),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                alignment: Alignment.bottomLeft,
                child: Text(
                  '${user.name}, ${user.age}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// TAB 4: CHAT & AI CINEMA ASSISTANT
// ==========================================
class ChatListTab extends StatelessWidget {
  const ChatListTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chats',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const CircleAvatar(
              radius: 30,
              backgroundImage: NetworkImage(
                'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&q=80',
              ),
            ),
            title: const Text(
              "Elena",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            subtitle: const Text("Let's figure out a time!"),
            trailing: const Icon(Icons.circle, color: AppColors.cyan, size: 12),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatDetailScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatDetailScreen extends StatelessWidget {
  const ChatDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.darkSurface,
        title: const Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(
                'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=800&q=80',
              ),
            ),
            SizedBox(width: 12),
            Text("Elena", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildBubble("Hey, we finally matched! You seem cool.", false),
                _buildBubble(
                  "Hi! Thanks, your bio made me laugh. What's up?",
                  true,
                ),

                // AI CINEMA ALERT (Pushy Tone)
                const SizedBox(height: 24),
                _buildPushyCinemaAlert(context),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // AI Icebreakers
          _buildAiIcebreaker(),

          // Input Field
          _buildChatInput(),
        ],
      ),
    );
  }

  Widget _buildBubble(String text, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        constraints: const BoxConstraints(maxWidth: 250),
        decoration: BoxDecoration(
          color: isMe ? AppColors.blue : AppColors.darkSurface,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: Radius.circular(isMe ? 0 : 20),
            bottomLeft: Radius.circular(isMe ? 20 : 0),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildPushyCinemaAlert(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            AppColors.purple.withOpacity(0.2),
            AppColors.cyan.withOpacity(0.1),
          ],
        ),
        border: Border.all(color: AppColors.cyan, width: 1.5),
        boxShadow: [
          BoxShadow(color: AppColors.purple.withOpacity(0.2), blurRadius: 20),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: const BoxDecoration(
              color: AppColors.cyan,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.black,
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "AI ALERT: Stop texting and meet up! 🛑",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
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
                const Text(
                  "'Dune: Part Two' is playing in exactly 45 minutes at IMAX Downtown (1.2 miles away). You both love Sci-Fi. Are we doing this or what?",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        "Too soon",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => HapticFeedback.heavyImpact(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.purple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        "Accept Date 🔥",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
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
  }

  Widget _buildAiIcebreaker() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: AppColors.darkBg,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.cyan, size: 16),
            const SizedBox(width: 8),
            _buildChip("I'm down! I'll buy popcorn 🍿"),
            const SizedBox(width: 8),
            _buildChip("Let's do it! Meet you there?"),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String text) {
    return ActionChip(
      backgroundColor: AppColors.darkSurface,
      side: const BorderSide(color: AppColors.cyan, width: 1),
      label: Text(
        text,
        style: const TextStyle(color: AppColors.cyan, fontSize: 13),
      ),
      onPressed: () {},
    );
  }

  Widget _buildChatInput() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        color: AppColors.darkSurface,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.darkBg,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const TextField(
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              backgroundColor: AppColors.cyan,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.black, size: 20),
                onPressed: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// TAB 5: PROFILE EDIT SECTION
// ==========================================
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 28),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo Grid
            SizedBox(
              height: 250,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildPhotoBox(
                      'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800&q=80',
                      isMain: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        Expanded(child: _buildPhotoBox('', isAdd: true)),
                        const SizedBox(height: 12),
                        Expanded(child: _buildPhotoBox('', isAdd: true)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Editable Info
            const Text(
              "ABOUT ME",
              style: TextStyle(
                color: AppColors.cyan,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField("Name", "Alex"),
            const SizedBox(height: 16),
            _buildTextField("Age", "25"),
            const SizedBox(height: 16),
            _buildTextField(
              "Bio",
              "Software engineer in NY. Looking for someone to explore the city and watch movies with.",
              maxLines: 3,
            ),

            const SizedBox(height: 30),
            const Text(
              "INTERESTS",
              style: TextStyle(
                color: AppColors.cyan,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildInterestChip("Sci-Fi Movies"),
                _buildInterestChip("Coffee"),
                _buildInterestChip("Tech"),
                ActionChip(
                  backgroundColor: Colors.transparent,
                  side: BorderSide(
                    color: Colors.grey[700]!,
                    style: BorderStyle.solid,
                  ),
                  label: const Text(
                    "+ Add",
                    style: TextStyle(color: Colors.grey),
                  ),
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoBox(String url, {bool isMain = false, bool isAdd = false}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: isMain
            ? Border.all(color: AppColors.purple, width: 2)
            : Border.all(color: Colors.grey[800]!),
        image: url.isNotEmpty
            ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
            : null,
      ),
      child: isAdd
          ? const Center(
              child: Icon(Icons.add, color: AppColors.cyan, size: 30),
            )
          : null,
    );
  }

  Widget _buildTextField(String label, String value, {int maxLines = 1}) {
    return TextField(
      controller: TextEditingController(text: value),
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: AppColors.darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildInterestChip(String label) {
    return Chip(
      backgroundColor: AppColors.purple.withOpacity(0.2),
      side: const BorderSide(color: AppColors.purple),
      label: Text(label, style: const TextStyle(color: Colors.white)),
    );
  }
}
