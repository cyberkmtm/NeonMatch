part of genz_app;

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
