import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Communication bridge to the native Android Foreground Service.
class NativeTrackingChannel {
  static const MethodChannel _methodChannel =
      MethodChannel('com.antigravity.jupitercompanion/ride_tracking');
  static const EventChannel _eventChannel =
      EventChannel('com.antigravity.jupitercompanion/location_events');

  Stream<Map<String, dynamic>>? _locationStream;

  /// Starts native foreground service with persistent notification and location listener
  Future<bool> startTracking({
    required String rideId,
    int minTimeMs = 1000,
    double minDistanceM = 1.0,
  }) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final result = await _methodChannel.invokeMethod<bool>('startTracking', {
          'rideId': rideId,
          'minTimeMs': minTimeMs,
          'minDistanceM': minDistanceM,
        });
        return result ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('Error starting native tracking: $e');
      return false;
    }
  }

  /// Pauses tracking in native foreground service
  Future<bool> pauseTracking() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final result = await _methodChannel.invokeMethod<bool>('pauseTracking');
        return result ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('Error pausing native tracking: $e');
      return false;
    }
  }

  /// Resumes tracking in native foreground service
  Future<bool> resumeTracking() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final result = await _methodChannel.invokeMethod<bool>('resumeTracking');
        return result ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('Error resuming native tracking: $e');
      return false;
    }
  }

  /// Stops native foreground service and removes notification
  Future<bool> stopTracking() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final result = await _methodChannel.invokeMethod<bool>('stopTracking');
        return result ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('Error stopping native tracking: $e');
      return false;
    }
  }

  /// Returns current foreground service status
  Future<Map<String, dynamic>> getTrackingStatus() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final result =
            await _methodChannel.invokeMapMethod<String, dynamic>('getTrackingStatus');
        return result ?? {'isRunning': false, 'isPaused': false, 'currentRideId': null};
      }
      return {'isRunning': false, 'isPaused': false, 'currentRideId': null};
    } catch (e) {
      debugPrint('Error getting tracking status: $e');
      return {'isRunning': false, 'isPaused': false, 'currentRideId': null};
    }
  }

  /// Checks if battery optimization is disabled for continuous background tracking
  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final result = await _methodChannel
            .invokeMethod<bool>('isIgnoringBatteryOptimizations');
        return result ?? false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Requests user exemption from battery optimization
  Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final result = await _methodChannel
            .invokeMethod<bool>('requestIgnoreBatteryOptimizations');
        return result ?? false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Continuous stream of location points from native foreground service
  Stream<Map<String, dynamic>> get locationStream {
    if (_locationStream == null && defaultTargetPlatform == TargetPlatform.android) {
      _locationStream = _eventChannel
          .receiveBroadcastStream()
          .map((event) => Map<String, dynamic>.from(event as Map));
    }
    return _locationStream ?? const Stream.empty();
  }
}

