import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'app/providers.dart';
import 'data/local/preferences_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize persistent preferences
  final prefs = await PreferencesService.create();

  runApp(
    ProviderScope(
      overrides: [
        preferencesServiceProvider.overrideWithValue(prefs),
      ],
      child: const JupiterCompanionApp(),
    ),
  );
}
