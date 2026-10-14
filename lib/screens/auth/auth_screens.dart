import 'dart:async';

import 'package:flutter/material.dart';
import '../../app.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/validators.dart';
import '../../models/user_model.dart';
import '../../services/api_service.dart';

void showError(BuildContext context, Object error) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error is ApiException
              ? error.message
              : 'Something went wrong. Please try again.',
        ),
      ),
    );

abstract class _AuthAttemptState<T extends StatefulWidget> extends State<T> {
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;
  bool _rateLimited = false;

  bool get _isCoolingDown => _cooldownSeconds > 0;

  void _handleAttemptError(Object error) {
    if (error is ApiException && error.isRateLimit) {
      _startCooldown(error.retryAfterSeconds ?? 15);
      return;
    }
    showError(context, error);
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() {
      _rateLimited = true;
      _cooldownSeconds = seconds < 1 ? 1 : seconds;
    });
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _cooldownSeconds--);
      if (_cooldownSeconds <= 0) {
        timer.cancel();
        _cooldownTimer = null;
      }
    });
  }

  void _clearRateLimit() {
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
    _rateLimited = false;
  }

  Widget get _cooldownNotice => !_rateLimited
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            _isCoolingDown
                ? 'Too many attempts. Please try again in $_cooldownSeconds ${_cooldownSeconds == 1 ? 'second' : 'seconds'}.'
                : 'You can try again now.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _isCoolingDown
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        );

  String _retryLabel(String normalLabel) => _isCoolingDown
      ? 'Try again in $_cooldownSeconds ${_cooldownSeconds == 1 ? 'second' : 'seconds'}'
      : normalLabel;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends _AuthAttemptState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;
  Future<void> _login() async {
    if (_loading || _isCoolingDown) return;
    if (!_formKey.currentState!.validate()) return;
    setState(_clearRateLimit);
    setState(() => _loading = true);
    try {
      final auth = AuthScope.of(context);
      await auth.login(_email.text.trim(), _password.text);
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.dashboardForRole(auth.user!.role),
          (_) => false,
        );
      }
    } catch (error) {
      if (mounted) _handleAttemptError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
    title: 'Welcome back',
    subtitle: 'Login to continue to Innovestia',
    child: Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _password,
            obscureText: !_showPassword,
            validator: Validators.password,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _showPassword ? 'Hide password' : 'Show password',
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loading || _isCoolingDown ? null : _login,
            child: Text(_loading ? 'Logging in...' : _retryLabel('Login')),
          ),
          _cooldownNotice,
          TextButton(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
            child: const Text('Create a new account'),
          ),
        ],
      ),
    ),
  );
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends _AuthAttemptState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _phone = TextEditingController(),
      _password = TextEditingController();
  UserRole _role = UserRole.startup;
  bool _loading = false;
  bool _showPassword = false;
  Future<void> _register() async {
    if (_loading || _isCoolingDown) return;
    if (!_formKey.currentState!.validate()) return;
    setState(_clearRateLimit);
    setState(() => _loading = true);
    try {
      final auth = AuthScope.of(context);
      await auth.register(
        name: _name.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        password: _password.text,
        role: _role,
      );
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.dashboardForRole(auth.user!.role),
          (_) => false,
        );
      }
    } catch (error) {
      if (mounted) _handleAttemptError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final controller in [_name, _email, _phone, _password]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
    title: 'Join Innovestia',
    subtitle: 'Create your account and start connecting.',
    child: Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _name,
            validator: (v) => Validators.required(v, 'Full name'),
            decoration: InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _email,
            validator: Validators.email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            validator: (v) => Validators.required(v, 'Phone number'),
            decoration: const InputDecoration(
              labelText: 'Phone number',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _password,
            obscureText: !_showPassword,
            validator: Validators.password,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _showPassword ? 'Hide password' : 'Show password',
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<UserRole>(
            initialValue: _role,
            decoration: const InputDecoration(labelText: 'I am a'),
            items: const [
              DropdownMenuItem(value: UserRole.startup, child: Text('Startup')),
              DropdownMenuItem(
                value: UserRole.investor,
                child: Text('Investor'),
              ),
            ],
            onChanged: (value) => setState(() => _role = value!),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _loading || _isCoolingDown ? null : _register,
            child: Text(
              _loading ? 'Creating account...' : _retryLabel('Create Account'),
            ),
          ),
          _cooldownNotice,
        ],
      ),
    ),
  );
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title, subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            child,
          ],
        ),
      ),
    ),
  );
}
