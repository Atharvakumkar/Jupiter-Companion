import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CLOUD ACCOUNT'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.cloud_outlined, size: 54, color: AppColors.primary),
          const SizedBox(height: 16),
          const Text(
            'Sync Rides & Expenses',
            textAlign: TextAlign.center,
            style: AppTypography.displayLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Sign in to synchronize your TVS Jupiter ride logs, maintenance schedules, and fuel receipts across devices.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: 32),

          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            child: const Text('SIGN IN WITH EMAIL'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Firebase Cloud Sync is active in offline-first mode.'),
                  backgroundColor: AppColors.success,
                ),
              );
              context.pop();
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            child: const Text('CONTINUE AS GUEST (OFFLINE ONLY)'),
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );
  }
}

