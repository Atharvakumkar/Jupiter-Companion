import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Warm up database and restore any interrupted session
    try {
      final db = ref.read(databaseProvider);
      await db.database;
      final tracking = ref.read(rideTrackingServiceProvider);
      await tracking.restoreSessionIfInterrupted();
    } catch (e) {
      debugPrint('Initialization check: $e');
    }

    await Future.delayed(const Duration(milliseconds: 1200));

    if (mounted) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.two_wheeler,
              size: 72,
              color: AppColors.primary,
            ),
            SizedBox(height: 20),
            Text(
              'JUPITER COMPANION',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'TVS Jupiter 110 SmartXonnect Companion',
              style: AppTypography.bodySmall,
            ),
            SizedBox(height: 32),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

