import 'package:intl/intl.dart';

/// Formatting utilities for dates, numbers, distances and durations.
class AppFormatters {
  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _timeFormat = DateFormat('hh:mm a');
  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');

  static String formatDate(DateTime dt) => _dateFormat.format(dt);
  static String formatTime(DateTime dt) => _timeFormat.format(dt);
  static String formatDateTime(DateTime dt) => _dateTimeFormat.format(dt);

  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      final km = meters / 1000.0;
      return '${km.toStringAsFixed(2)} km';
    }
  }

  static String formatDurationClock(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  static String formatDurationReadable(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  static String formatSpeed(double kmh) {
    if (kmh < 0.5) return '0';
    return kmh.toStringAsFixed(0);
  }

  static String formatCurrency(double amount, {String symbol = '₹'}) {
    return '$symbol${amount.toStringAsFixed(2)}';
  }
}

