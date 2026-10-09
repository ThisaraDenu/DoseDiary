import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/remote/auth_service.dart';

class LivePresenceService {
  LivePresenceService._();

  static const locationRefreshInterval = Duration(minutes: 5);
  static DateTime? _lastLocationUpdate;

  static Future<bool> publishNow({bool forceLocation = false}) async {
    if (!AuthService.isLoggedIn) return false;

    double? latitude;
    double? longitude;
    String? locationLabel;
    final shouldReadLocation = forceLocation ||
        _lastLocationUpdate == null ||
        DateTime.now().difference(_lastLocationUpdate!) >=
            locationRefreshInterval;

    if (shouldReadLocation) {
      try {
        final permission = await Permission.locationWhenInUse.status;
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (permission.isGranted && serviceEnabled) {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 12),
            ),
          );
          latitude = position.latitude;
          longitude = position.longitude;
          locationLabel = await _resolveLocationLabel(position);
          _lastLocationUpdate = DateTime.now();
        }
      } catch (error) {
        debugPrint('LivePresenceService location error: $error');
      }
    }

    try {
      await Supabase.instance.client.rpc(
        'update_my_presence',
        params: {
          'p_latitude': latitude,
          'p_longitude': longitude,
          'p_location_label': locationLabel,
        },
      );
      return true;
    } catch (error) {
      debugPrint('LivePresenceService publish error: $error');
      return false;
    }
  }

  static Future<String> _resolveLocationLabel(Position position) async {
    try {
      final places = await Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (places.isNotEmpty) {
        final place = places.first;
        final values = <String>[
          if (place.subLocality?.trim().isNotEmpty == true)
            place.subLocality!.trim(),
          if (place.locality?.trim().isNotEmpty == true) place.locality!.trim(),
          if (place.administrativeArea?.trim().isNotEmpty == true)
            place.administrativeArea!.trim(),
        ];
        final unique = values.toSet().take(2).toList();
        if (unique.isNotEmpty) return unique.join(', ');
      }
    } catch (error) {
      debugPrint('LivePresenceService geocoding error: $error');
    }

    return '${position.latitude.toStringAsFixed(5)}, '
        '${position.longitude.toStringAsFixed(5)}';
  }
}
