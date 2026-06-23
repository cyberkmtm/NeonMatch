part of genz_app;

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
