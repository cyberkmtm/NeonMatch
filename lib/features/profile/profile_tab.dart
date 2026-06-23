part of genz_app;

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}



class _ProfileTabState extends State<ProfileTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  List<String> interests = [];
  List<String> firebaseImageUrls = ['', '', ''];
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

  final String imgbbApiKey = 'a2fc26f7c2aba3390744731b43ea006d';

  @override
  void initState() {
    super.initState();
    _loadFirebaseData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
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
          List<String> loaded = List<String>.from(data['images']);
          for (int i = 0; i < loaded.length && i < 3; i++) {
            firebaseImageUrls[i] = loaded[i];
          }
        }
      });
    }
  }

  Future<String?> _uploadToImgBB(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final response = await http.post(
        Uri.parse('https://api.imgbb.com/1/upload'),
        body: {'key': imgbbApiKey, 'image': base64Encode(bytes)},
      );
      if (response.statusCode == 200)
        return jsonDecode(response.body)['data']['display_url'];
    } catch (e) {
      debugPrint('ImgBB error: $e');
    }
    return null;
  }

  Future<void> _saveProfile() async {
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
      List<String> finalImages = firebaseImageUrls
          .where((url) => url.isNotEmpty)
          .toList();
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'name': _nameCtrl.text.trim(),
        'age': int.parse(_ageCtrl.text.trim()),
        'bio': _bioCtrl.text.trim(),
        'interests': interests,
        'images': finalImages,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated ✅'),
            backgroundColor: AppColors.purple,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
          newlyPickedPhotos = [null, null, null];
        });
      }
    }
  }

  void _showInterestsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose your interests',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
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
                    selectedColor: AppColors.cyan.withOpacity(0.2),
                    checkmarkColor: AppColors.cyan,
                    side: BorderSide(
                      color: isSel ? AppColors.cyan : Colors.white24,
                    ),
                    backgroundColor: AppColors.darkCard,
                    labelStyle: TextStyle(
                      color: isSel ? AppColors.cyan : Colors.white70,
                    ),
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
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _clearImage(int index) => setState(() {
    newlyPickedPhotos[index] = null;
    firebaseImageUrls[index] = '';
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: TextStyle(
            color: isDark(context) ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 26,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: isDark(context) ? AppColors.cyan : AppColors.blue,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
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
              const SizedBox(height: 32),
              _SectionLabel('About Me'),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nameCtrl,
                decoration: _inputDeco(context, 'Name', Icons.person_outline),
                validator: (v) => v!.isEmpty ? 'Required' : null,
                style: _inputStyle(context),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _ageCtrl,
                keyboardType: TextInputType.number,
                decoration: _inputDeco(context, 'Age', Icons.cake_outlined),
                style: _inputStyle(context),
                validator: (v) {
                  int? p = int.tryParse(v ?? '');
                  if (p == null || p < 18) return '18+ only';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _bioCtrl,
                maxLines: 3,
                maxLength: 150,
                decoration: _inputDeco(context, 'Bio', Icons.edit_outlined),
                style: _inputStyle(context),
              ),
              const SizedBox(height: 28),
              _SectionLabel('Interests'),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ...interests.map(
                    (i) => Chip(
                      label: Text(
                        i,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      backgroundColor: AppColors.purple.withOpacity(0.2),
                      side: const BorderSide(color: AppColors.purple, width: 1),
                      deleteIcon: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white54,
                      ),
                      onDeleted: () => setState(() => interests.remove(i)),
                    ),
                  ),
                  ActionChip(
                    backgroundColor: Colors.transparent,
                    side: const BorderSide(color: Colors.white24),
                    label: const Text(
                      '+ Add',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    onPressed: _showInterestsModal,
                  ),
                ],
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: isSaving
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.cyan),
                      )
                    : _GradientButton(
                        label: 'Save Profile',
                        onTap: _saveProfile,
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoBox(int index, {bool isMain = false}) {
    final dark = isDark(context);
    XFile? localFile = newlyPickedPhotos[index];
    String savedUrl = firebaseImageUrls[index];
    ImageProvider? imageProvider;
    if (localFile != null)
      imageProvider = kIsWeb
          ? NetworkImage(localFile.path)
          : FileImage(File(localFile.path)) as ImageProvider;
    else if (savedUrl.isNotEmpty)
      imageProvider = NetworkImage(savedUrl);

    return Stack(
      children: [
        GestureDetector(
          onTap: () async {
            final img = await ImagePicker().pickImage(
              source: ImageSource.gallery,
              imageQuality: 85,
            );
            if (img != null) setState(() => newlyPickedPhotos[index] = img);
          },
          child: Container(
            decoration: BoxDecoration(
              color: dark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isMain
                    ? AppColors.purple.withOpacity(0.5)
                    : (dark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.08)),
                width: isMain ? 1.5 : 1,
              ),
              image: imageProvider != null
                  ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                  : null,
            ),
            child: imageProvider == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          color: dark ? Colors.white24 : Colors.black26,
                          size: isMain ? 32 : 22,
                        ),
                        if (isMain) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Main Photo',
                            style: TextStyle(
                              color: dark ? Colors.white24 : Colors.black38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : null,
          ),
        ),
        if (imageProvider != null)
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _clearImage(index),
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppColors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  InputDecoration _inputDeco(BuildContext context, String hint, IconData icon) {
    final dark = isDark(context);
    return InputDecoration(
      labelText: hint,
      labelStyle: TextStyle(color: dark ? Colors.white38 : Colors.black45),
      prefixIcon: Icon(
        icon,
        color: dark ? Colors.white24 : Colors.black38,
        size: 18,
      ),
      filled: true,
      fillColor: dark ? AppColors.darkSurface : AppColors.lightSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: dark
              ? Colors.white.withOpacity(0.07)
              : Colors.black.withOpacity(0.07),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.cyan, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.red),
      ),
    );
  }

  TextStyle _inputStyle(BuildContext context) =>
      TextStyle(color: isDark(context) ? Colors.white : Colors.black87);
}



class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      color: AppColors.cyan,
      fontWeight: FontWeight.bold,
      fontSize: 12,
      letterSpacing: 1.2,
    ),
  );
}
