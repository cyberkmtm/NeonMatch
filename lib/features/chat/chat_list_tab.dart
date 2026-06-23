part of genz_app;

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
