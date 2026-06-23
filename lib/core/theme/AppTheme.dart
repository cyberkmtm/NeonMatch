part of genz_app;

class AppState extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.dark;
  void toggleTheme() {
    themeMode = themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}



final appState = AppState();


class AppTheme {
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBg,
    primaryColor: AppColors.cyan,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.cyan,
      secondary: AppColors.purple,
      surface: AppColors.darkSurface,
    ),
    textTheme: const TextTheme(bodyMedium: TextStyle(fontFamily: 'sans-serif')),
  );
  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBg,
    primaryColor: AppColors.blue,
    colorScheme: const ColorScheme.light(
      primary: AppColors.blue,
      secondary: AppColors.purple,
      surface: AppColors.lightSurface,
    ),
  );
}



bool isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;
