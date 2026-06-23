part of genz_app;

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
