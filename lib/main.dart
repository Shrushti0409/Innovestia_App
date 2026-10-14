import 'package:flutter/material.dart';

import 'app.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authService = AuthService(StorageService());
  await authService.restoreSession();
  runApp(InnovestiaApp(authService: authService));
}

