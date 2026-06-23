part of genz_app;

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
      if (userData['showMeOnApp'] == false) continue;

      String? theirGender = userData['gender'];
      if (theirGender != null &&
          theirGender.isNotEmpty &&
          theirGender != targetGender) {
        continue;
      }

      int userAge = userData['age'] ?? 25;
      if (userAge < minAge || userAge > maxAge) continue;

     final int? realDistance =
    LocationService.distanceMilesBetween(myData, userData);

if (realDistance == null) {
  continue;
}

if (realDistance > maxDist) {
  continue;
}

userData['calculatedDistance'] = realDistance;

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
