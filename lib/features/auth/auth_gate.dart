part of genz_app;

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.darkBg,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.cyan),
            ),
          );
        }
        if (snapshot.hasData) return const MainNavigator();
        return const AuthScreen();
      },
    );
  }
}
