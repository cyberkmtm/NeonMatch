part of genz_app;

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
