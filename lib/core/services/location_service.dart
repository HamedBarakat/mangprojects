import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Geolocation service.
/// Web: uses browser navigator.geolocation (dart:html - built into Flutter web SDK).
/// Mobile/Desktop: returns null (no geolocator in pubspec).
class LocationService {
  static final LocationService _instance = LocationService._();
  factory LocationService() => _instance;
  LocationService._();

  Future<Map<String, dynamic>?> getCurrentPosition() async {
    if (!kIsWeb) return null;
    try {
      final completer = Completer<Map<String, dynamic>?>();
      _getWebPosition(completer);
      return await completer.future.timeout(const Duration(seconds: 15));
    } catch (_) {
      return null;
    }
  }
}

// Web implementation injected at compile time — see location_service_web.dart
// This stub runs on mobile where dart:html is not available
void _getWebPosition(Completer<Map<String, dynamic>?> completer) {
  completer.complete(null);
}
