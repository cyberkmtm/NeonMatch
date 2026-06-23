part of genz_app;

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
