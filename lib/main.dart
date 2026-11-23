import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_theme.dart';
import 'data/services/auth_service.dart';
import 'features/admin/admin_dashboard_page.dart';
import 'features/auth/pages/login_page.dart';
import 'features/auth/pages/splash_page.dart';
import 'features/main/main_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const FinPayApp());
}

class FinPayApp extends StatelessWidget {
  const FinPayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinPay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Batasi skala teks sistem agar layout tetap rapi di semua perangkat.
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.15,
            ),
          ),
          child: child!,
        );
      },
      // Alur utama: SplashPage -> Onboarding / Login & Register -> MainPage.
      // Saat user logout, kembali ke SplashPage -> Login / Register.
      initialRoute: '/',
      onGenerateInitialRoutes: (initialRouteName) {
        final routeName = initialRouteName.trim().isEmpty
            ? '/'
            : initialRouteName;
        final WidgetBuilder builder = switch (routeName) {
          '/admin' => (_) => const AdminDashboardPage(),
          '/login' => (_) => const LoginPage(),
          '/splash' => (_) => const SplashPage(),
          _ => (_) => const _AuthGate(),
        };
        return [
          MaterialPageRoute<void>(
            settings: RouteSettings(name: routeName),
            builder: builder,
          ),
        ];
      },
      routes: {
        '/': (context) => const _AuthGate(),
        '/splash': (context) => const SplashPage(),
        '/login': (context) => const LoginPage(),
        '/admin': (context) => const AdminDashboardPage(),
      },
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthService.instance.isLoggedInNotifier,
      builder: (context, isLoggedIn, _) {
        if (!isLoggedIn) {
          return const SplashPage();
        }
        return const MainPage();
      },
    );
  }
}
