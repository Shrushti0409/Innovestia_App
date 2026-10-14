import 'package:flutter/material.dart';

import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'services/auth_service.dart';

class InnovestiaApp extends StatelessWidget {
  const InnovestiaApp({super.key, required this.authService});
  final AuthService authService;
  @override
  Widget build(BuildContext context) => AuthScope(
    notifier: authService,
    child: MaterialApp(
      title: 'Innovestia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routes: AppRoutes.routes,
      home: SplashScreen(
        next: authService.isAuthenticated
            ? DashboardScreen(role: authService.user!.role)
            : const WelcomeScreen(),
      ),
    ),
  );
}

class AuthScope extends InheritedNotifier<AuthService> {
  const AuthScope({
    super.key,
    required AuthService notifier,
    required super.child,
  }) : super(notifier: notifier);
  static AuthService of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthScope>()!.notifier!;
}
