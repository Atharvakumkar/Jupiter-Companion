import 'package:flutter/material.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class JupiterCompanionApp extends StatelessWidget {
  const JupiterCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Jupiter Companion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}

