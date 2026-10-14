import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.next});
  final Widget next;
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => widget.next));
      }
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: AppTheme.primary,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.trending_up_rounded,
              size: 55,
              color: AppTheme.primary,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Innovestia',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Connecting Ideas with Capital',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    ),
  );
}
