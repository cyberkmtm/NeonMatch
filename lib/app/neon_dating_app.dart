part of genz_app;

class NeonDatingApp extends StatelessWidget {
  const NeonDatingApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, child) => MaterialApp(
        title: 'GEN Ƶ',
        debugShowCheckedModeBanner: false,
        themeMode: appState.themeMode,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const AuthGate(),
      ),
    );
  }
}
