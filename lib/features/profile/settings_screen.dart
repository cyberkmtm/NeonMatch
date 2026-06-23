part of genz_app;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}



class _SettingsScreenState extends State<SettingsScreen> {
  double minAge = 18;
  double maxAge = 40;
  double maxDistance = 50;
  String location = 'Loading...';
  bool isLoading = true;
  bool _notificationsEnabled = true;
  bool _showMeOnApp = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  void _showAboutGenZ() {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.cyan, AppColors.purple],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cyan.withOpacity(0.35),
                  blurRadius: 16,
                ),
              ],
            ),
            child: const Icon(Icons.bolt, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Text(
            'About GEN Ƶ',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: const Text(
        'GEN Ƶ is a modern dating app built for real connections, smart discovery, and meaningful conversations. '
        'It helps people find nearby matches, explore shared interests, start chats with AI-powered icebreakers, '
        'and create a more fun, safe, and intentional dating experience.\n\n'
        'Version: 1.0.0',
        style: TextStyle(
          color: Colors.white70,
          height: 1.5,
          fontSize: 14,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Close',
            style: TextStyle(
              color: AppColors.cyan,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

  Future<void> _loadSettings() async {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (doc.exists) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      Map<String, dynamic> settings =
          data['discoverySettings'] ??
          {'minAge': 18, 'maxAge': 40, 'maxDistance': 50};
      setState(() {
        minAge = (settings['minAge'] ?? 18).toDouble();
        maxAge = (settings['maxAge'] ?? 40).toDouble();
        maxDistance = (settings['maxDistance'] ?? 50).toDouble();
        location = data['location'] ?? 'New York';
        _notificationsEnabled = data['notificationsEnabled'] ?? true;
        _showMeOnApp = data['showMeOnApp'] ?? true;
        isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    String uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'discoverySettings': {
        'minAge': minAge.toInt(),
        'maxAge': maxAge.toInt(),
        'maxDistance': maxDistance.toInt(),
      },
      'location': location,
      'notificationsEnabled': _notificationsEnabled,
      'showMeOnApp': _showMeOnApp,
    });
  }

  Future<void> _editLocation() async {
  try {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Getting your current location...'),
        backgroundColor: AppColors.purple,
        behavior: SnackBarBehavior.floating,
      ),
    );

    final locationData = await LocationService.getCurrentLocationData();

    final uid = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update(locationData);

    if (!mounted) return;

    setState(() {
      location = locationData['location'] ?? 'Location updated';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Location updated: $location'),
        backgroundColor: AppColors.cyan,
        behavior: SnackBarBehavior.floating,
      ),
    );
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Settings',
          textColor: Colors.white,
          onPressed: () {
            Geolocator.openAppSettings();
          },
        ),
      ),
    );
  }
}
  void _changePassword() {
    final _currentCtrl = TextEditingController();
    final _newCtrl = TextEditingController();
    final _confirmCtrl = TextEditingController();
    bool obscure1 = true, obscure2 = true, obscure3 = true;
    bool isChanging = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Change Password',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(
                ctrl: _currentCtrl,
                hint: 'Current password',
                obscure: obscure1,
                toggle: () => setDialogState(() => obscure1 = !obscure1),
              ),
              const SizedBox(height: 12),
              _dialogField(
                ctrl: _newCtrl,
                hint: 'New password',
                obscure: obscure2,
                toggle: () => setDialogState(() => obscure2 = !obscure2),
              ),
              const SizedBox(height: 12),
              _dialogField(
                ctrl: _confirmCtrl,
                hint: 'Confirm new password',
                obscure: obscure3,
                toggle: () => setDialogState(() => obscure3 = !obscure3),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white38),
              ),
            ),
            ElevatedButton(
              onPressed: isChanging
                  ? null
                  : () async {
                      if (_newCtrl.text != _confirmCtrl.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('New passwords do not match.'),
                            backgroundColor: AppColors.red,
                          ),
                        );
                        return;
                      }
                      if (_newCtrl.text.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Password must be at least 6 characters.',
                            ),
                            backgroundColor: AppColors.red,
                          ),
                        );
                        return;
                      }
                      setDialogState(() => isChanging = true);
                      try {
                        User user = FirebaseAuth.instance.currentUser!;
                        AuthCredential cred = EmailAuthProvider.credential(
                          email: user.email!,
                          password: _currentCtrl.text,
                        );
                        await user.reauthenticateWithCredential(cred);
                        await user.updatePassword(_newCtrl.text);
                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password changed successfully ✅'),
                              backgroundColor: AppColors.purple,
                            ),
                          );
                        }
                      } on FirebaseAuthException catch (e) {
                        String msg = 'Failed to update password.';
                        if (e.code == 'wrong-password')
                          msg = 'Current password is incorrect.';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(msg),
                            backgroundColor: AppColors.red,
                          ),
                        );
                      } finally {
                        setDialogState(() => isChanging = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cyan,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isChanging
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      'Update',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField({
    required TextEditingController ctrl,
    required String hint,
    required bool obscure,
    required VoidCallback toggle,
  }) => TextField(
    controller: ctrl,
    obscureText: obscure,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white38),
      suffixIcon: IconButton(
        icon: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: Colors.white38,
          size: 18,
        ),
        onPressed: toggle,
      ),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.white24),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.cyan),
      ),
    ),
  );

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Account',
          style: TextStyle(color: AppColors.red, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This action is permanent and cannot be undone. All your data, matches, and messages will be deleted.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white38),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAccount();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Delete Forever',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      await FirebaseAuth.instance.currentUser!.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please sign out and sign back in before deleting your account.',
              ),
              backgroundColor: AppColors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading)
      return const Scaffold(
        backgroundColor: AppColors.darkBg,
        body: Center(child: CircularProgressIndicator(color: AppColors.cyan)),
      );

    bool dark = isDark(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsSection(label: 'Discovery'),
          _SettingsTile(
  icon: Icons.my_location_outlined,
  title: 'Use Current Location',
  trailing: Flexible(
    child: Text(
      location,
      textAlign: TextAlign.right,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: Colors.grey, fontSize: 14),
    ),
  ),
  onTap: _editLocation,
),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Maximum Distance',
                  style: TextStyle(
                    color: dark ? Colors.white : Colors.black,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${maxDistance.toInt()} mi',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
          Slider(
            value: maxDistance,
            min: 1,
            max: 100,
            activeColor: AppColors.cyan,
            inactiveColor: Colors.white12,
            onChanged: (val) => setState(() => maxDistance = val),
            onChangeEnd: (_) => _saveSettings(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Age Range',
                  style: TextStyle(
                    color: dark ? Colors.white : Colors.black,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${minAge.toInt()} – ${maxAge.toInt()}',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
          RangeSlider(
            values: RangeValues(minAge, maxAge),
            min: 18,
            max: 80,
            activeColor: AppColors.cyan,
            inactiveColor: Colors.white12,
            onChanged: (val) => setState(() {
              minAge = val.start;
              maxAge = val.end;
            }),
            onChangeEnd: (_) => _saveSettings(),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.visibility_outlined,
            title: 'Show me on NeonMatch',
            trailing: Switch(
              value: _showMeOnApp,
              activeColor: AppColors.cyan,
              onChanged: (val) {
                setState(() => _showMeOnApp = val);
                _saveSettings();
              },
            ),
          ),
          const SizedBox(height: 8),
          _SettingsSection(label: 'Notifications'),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Push Notifications',
            trailing: Switch(
              value: _notificationsEnabled,
              activeColor: AppColors.cyan,
              onChanged: (val) {
                setState(() => _notificationsEnabled = val);
                _saveSettings();
              },
            ),
          ),
          const SizedBox(height: 8),
          _SettingsSection(label: 'App Settings'),
          _SettingsTile(
            icon: dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            title: dark ? 'Light Mode' : 'Dark Mode',
            trailing: Switch(
              value: dark,
              activeColor: AppColors.cyan,
              onChanged: (_) => appState.toggleTheme(),
            ),
          ),
          const SizedBox(height: 8),
          _SettingsSection(label: 'Account'),
          _SettingsTile(
            icon: Icons.lock_outline,
            title: 'Change Password',
            trailing: const Icon(Icons.chevron_right, color: Colors.white24),
            onTap: _changePassword,
          ),
          _SettingsTile(
  icon: Icons.help_outline,
  title: 'Help & Support',
  trailing: const Icon(Icons.chevron_right, color: Colors.white24),
  onTap: () {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: const Text(
          'Help & Support',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Need help with your profile, matches, chat, or account?\n\n'
          'For support, contact the GEN Ƶ team at support@genz.app.\n\n'
          'Common tips:\n'
          '• Add clear profile photos\n'
          '• Keep your bio friendly and honest\n'
          '• Enable location to see nearby matches\n'
          '• Update your discovery settings anytime',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AppColors.cyan)),
          ),
        ],
      ),
    );
  },
),
_SettingsTile(
  icon: Icons.privacy_tip_outlined,
  title: 'Privacy Policy',
  trailing: const Icon(Icons.chevron_right, color: Colors.white24),
  onTap: () {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: const Text(
          'Privacy Policy',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'GEN Ƶ uses your profile details, photos, interests, and location to help show relevant nearby matches.\n\n'
          'Your location is used for distance calculation and discovery filtering. '
          'You can turn off profile visibility from Settings using “Show me on NeonMatch”.\n\n'
          'Never share sensitive personal information with someone you do not trust.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AppColors.cyan)),
          ),
        ],
      ),
    );
  },
),
          _SettingsTile(
  icon: Icons.info_outline,
  title: 'About GEN Ƶ',
  trailing: const Text(
    'v1.0.0',
    style: TextStyle(color: Colors.white24, fontSize: 12),
  ),
  onTap: _showAboutGenZ,
),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.logout, color: Colors.white54),
            label: const Text(
              'Sign Out',
              style: TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white12),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _showDeleteAccountDialog,
            icon: const Icon(Icons.delete_forever, color: AppColors.red),
            label: const Text(
              'Delete Account',
              style: TextStyle(
                color: AppColors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.red.withOpacity(0.3)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}



class _SettingsSection extends StatelessWidget {
  final String label;
  const _SettingsSection({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppColors.cyan,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.4,
      ),
    ),
  );
}



class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Icon(
        icon,
        color: dark ? Colors.white38 : Colors.black45,
        size: 20,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: dark ? Colors.white : Colors.black87,
          fontSize: 15,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
