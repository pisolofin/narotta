import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

/// Represents the current status of the GPS location tracking service.
enum LocationStatus {
  idle,
  loading,
  active,
  serviceDisabled,
  permissionDenied,
  error,
}

/// Service managing GPS permissions, single position reads, and real-time position stream.
class LocationService extends ChangeNotifier {
  static const int _distanceFilterMeters = 2;

  static final LocationService _instance = LocationService._internal();

  /// Returns the singleton instance of [LocationService].
  factory LocationService() {
    return _instance;
  }

  LocationService._internal();

  Position?                     _currentPosition;
  LocationStatus                _status = LocationStatus.idle;
  StreamSubscription<Position>? _positionSubscription;

  /// Returns the most recently acquired [Position], or `null` if not yet available.
  Position? get currentPosition => _currentPosition;

  /// Returns the current [LocationStatus].
  LocationStatus get status => _status;

  /// Checks permissions, fetches the current GPS fix, and starts listening to position updates.
  Future startTrackingAsync() async {
    if (_status == LocationStatus.loading) {
      return;
    }

    _status = LocationStatus.loading;
    notifyListeners();

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _status = LocationStatus.serviceDisabled;
        notifyListeners();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if ((permission == LocationPermission.denied) || (permission == LocationPermission.deniedForever)) {
        _status = LocationStatus.permissionDenied;
        notifyListeners();
        return;
      }

      // Immediately use last known position if available while acquiring fresh fix
      try {
        final Position? lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          _currentPosition = lastKnown;
          _status          = LocationStatus.active;
          notifyListeners();
        }
      }catch (_) {
        // Ignore if getLastKnownPosition is unsupported on the current platform
      }

      await _positionSubscription?.cancel();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy      : LocationAccuracy.high,
          distanceFilter: _distanceFilterMeters,
        ),
      ).listen(
        (Position updatedPosition) {
          _currentPosition = updatedPosition;
          _status          = LocationStatus.active;
          notifyListeners();
        },
        onError: (Object error) {
          if (_currentPosition == null) {
            _status = LocationStatus.error;
          }
          notifyListeners();
        },
      );

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _currentPosition = position;
      _status          = LocationStatus.active;
      notifyListeners();
    }catch (_) {
      _status = (_currentPosition != null) ? LocationStatus.active : LocationStatus.error;
      notifyListeners();
    }
  }

  /// Refreshes the current GPS position on demand.
  Future refreshPositionAsync() async {
    if ((_status != LocationStatus.active) || (_positionSubscription == null)) {
      await startTrackingAsync();
      return;
    }

    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _currentPosition = position;
      _status          = LocationStatus.active;
      notifyListeners();
    }catch (_) {
      notifyListeners();
    }
  }

  /// Stops listening to real-time position updates.
  Future stopTrackingAsync() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}
