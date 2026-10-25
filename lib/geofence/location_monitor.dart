import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

// android kills it in the background unless its a foreground service,
// ios needs the background flag
// doesnt work if u force quit the app
class LocationMonitor {
  Stream<Position> get positionStream {
    return Geolocator.getPositionStream(locationSettings: _settings());
  }

  Future<Position> getCurrentPosition() {
    return Geolocator.getCurrentPosition(
      locationSettings: _settings(),
    );
  }

  LocationSettings _settings() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'Cross Guard is monitoring your location',
            notificationText: 'Watching for restricted zones nearby.',
            enableWakeLock: true,
          ),
        );
      case TargetPlatform.iOS:
        return AppleSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
          allowBackgroundLocationUpdates: true,
        );
      default:
        return const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        );
    }
  }
}
