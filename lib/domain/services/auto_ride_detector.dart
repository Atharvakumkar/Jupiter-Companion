import 'package:flutter/foundation.dart';
import '../../data/local/preferences_service.dart';
import '../models/ride.dart';
import 'ride_tracking_service.dart';

/// Optional background detector for automatic ride start/stop.
/// Disabled by default. Requires explicit rider activation in settings.
class AutoRideDetector {
  final PreferencesService prefs;
  final RideTrackingService trackingService;

  int _sustainedMovingSeconds = 0;
  int _sustainedStoppedSeconds = 0;
  DateTime? _lastAutoEndCooldown;
  static const Duration _cooldownDuration = Duration(minutes: 3);

  AutoRideDetector({
    required this.prefs,
    required this.trackingService,
  });

  /// Evaluates GPS speed reading against auto-record thresholds
  void onGpsSpeedSample(double speedKmh, bool isAccurate) {
    // If feature disabled, do nothing
    if (!prefs.isAutoRecordEnabled) return;

    // If already recording manually or automatically, check for auto-stop condition
    if (trackingService.status == RideStatus.recording) {
      if (speedKmh < 3.0) {
        _sustainedStoppedSeconds++;
        // 5 minutes of continuous zero speed triggers auto-stop
        if (_sustainedStoppedSeconds >= 300) {
          debugPrint('Auto-ride detector: sustained stop detected. Finalizing ride.');
          trackingService.endRide();
          _sustainedStoppedSeconds = 0;
          _lastAutoEndCooldown = DateTime.now();
        }
      } else {
        _sustainedStoppedSeconds = 0;
      }
      return;
    }

    // Don't auto-start if in cooldown
    if (_lastAutoEndCooldown != null &&
        DateTime.now().difference(_lastAutoEndCooldown!) < _cooldownDuration) {
      return;
    }

    // Only process accurate GNSS samples
    if (!isAccurate) return;

    final thresholdSpeed = prefs.autoRecordMinSpeedKmh;
    final thresholdDuration = prefs.autoRecordMinDurationSec;

    if (speedKmh >= thresholdSpeed) {
      _sustainedMovingSeconds++;
      if (_sustainedMovingSeconds >= thresholdDuration) {
        debugPrint(
            'Auto-ride detector: sustained speed >= $thresholdSpeed km/h for $thresholdDuration s. Starting ride automatically.');
        trackingService.startRide(source: RecordingSource.automatic);
        _sustainedMovingSeconds = 0;
      }
    } else {
      // Hysteresis: slowly decrement rather than instantly resetting to prevent traffic light flakiness
      if (_sustainedMovingSeconds > 0) {
        _sustainedMovingSeconds--;
      }
    }
  }
}

