library genz_app;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'firebase_options.dart';

part 'core/theme/Colors.dart';
part 'core/theme/AppTheme.dart';
part 'core/animations/GlowAnimators.dart';
part 'app/neon_dating_app.dart';
part 'services/location_service.dart';
part 'features/auth/auth_gate.dart';
part 'features/auth/auth_screen.dart';
part 'components/inputs/neon_field.dart';
part 'components/buttons/glass_button.dart';
part 'components/buttons/neon_action_button.dart';
part 'features/profile/user_profile_screen.dart';
part 'navigation/main_navigator.dart';
part 'features/swipe/swipe_tab.dart';
part 'features/swipe/discover_tab.dart';
part 'features/match/matches_tab.dart';
part 'features/chat/chat_list_tab.dart';
part 'services/neon_match_ai.dart';
part 'features/chat/chat_detail_screen.dart';
part 'features/profile/profile_tab.dart';
part 'features/profile/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
    ),
  );
  runApp(const NeonDatingApp());
}
