import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../screens/auth/auth_screens.dart';
import '../../screens/auth/welcome_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/features/feature_screens.dart';

class AppRoutes {
  static const welcome = '/welcome',
      login = '/auth/login',
      register = '/auth/register',
      startupDashboard = '/startup/dashboard',
      investorDashboard = '/investor/dashboard',
      adminDashboard = '/admin/dashboard',
      adminUsers = '/admin/users',
      discovery = '/discovery',
      messages = '/messages',
      notifications = '/notifications',
      profile = '/profile',
      requests = '/requests';
  static String dashboardForRole(UserRole role) => switch (role) {
    UserRole.startup => startupDashboard,
    UserRole.investor => investorDashboard,
    UserRole.admin => adminDashboard,
  };
  static final routes = <String, WidgetBuilder>{
    welcome: (_) => const WelcomeScreen(),
    login: (_) => const LoginScreen(),
    register: (_) => const RegisterScreen(),
    startupDashboard: (_) => const DashboardScreen(role: UserRole.startup),
    investorDashboard: (_) => const DashboardScreen(role: UserRole.investor),
    adminDashboard: (_) => const DashboardScreen(role: UserRole.admin),
    adminUsers: (_) => const AdminUsersScreen(),
    discovery: (_) => const DiscoveryScreen(),
    messages: (_) => const MessagesScreen(),
    notifications: (_) => const NotificationsScreen(),
    profile: (_) => const ProfileScreen(),
    requests: (_) => const RequestsScreen(),
  };
}
