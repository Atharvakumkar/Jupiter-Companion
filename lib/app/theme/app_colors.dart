import 'package:flutter/material.dart';

/// Premium dark automotive color palette inspired by modern instrument clusters.
class AppColors {
  // Background surfaces
  static const Color background = Color(0xFF090D14);
  static const Color surface = Color(0xFF131A26);
  static const Color surfaceVariant = Color(0xFF1B2433);
  static const Color surfaceElevated = Color(0xFF222E40);
  static const Color border = Color(0xFF2B3A4F);
  static const Color divider = Color(0xFF1F2937);

  // Automotive Primary Accent: Electric Cyan / Hyper Teal
  static const Color primary = Color(0xFF00E5FF);
  static const Color primaryGlow = Color(0x3300E5FF);
  static const Color primaryDark = Color(0xFF00B0FF);

  // Secondary & Accents
  static const Color secondary = Color(0xFF3B82F6);
  static const Color accentIndigo = Color(0xFF6366F1);

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color successGlow = Color(0x3310B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningGlow = Color(0x33F59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color errorGlow = Color(0x33EF4444);

  // Vehicle Provenance Colors
  static const Color provenanceGps = Color(0xFF38BDF8); // Cyan-Blue for GPS
  static const Color provenanceEcu = Color(0xFF10B981); // Emerald for verified vehicle ECU
  static const Color provenanceManual = Color(0xFFFBBF24); // Amber for user entered
  static const Color provenanceCalculated = Color(0xFFA78BFA); // Violet for calculated
  static const Color provenanceUnavailable = Color(0xFF6B7280); // Gray for unavailable

  // High-contrast Typography
  static const Color textPrimary = Color(0xFFF9FAFB);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textDisabled = Color(0xFF4B5563);
}

