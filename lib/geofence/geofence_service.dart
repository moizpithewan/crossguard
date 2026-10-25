import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../alerts/alert_service.dart';
import '../zones/zone_storage.dart';
import 'geofence_evaluator.dart';
import 'location_monitor.dart';

// remembers the last state for each zone so it only alerts when it
// changes, not every gps update
class GeofenceService {
  final ZoneStorage zoneStorage;
  final LocationMonitor locationMonitor;
  final AlertService alertService;
  final evaluator = const GeofenceEvaluator();

  final Map<String, ZoneProximityState> _lastState = {};
  StreamSubscription<Position>? _gpsSub;

  GeofenceService(this.zoneStorage, this.locationMonitor, this.alertService);

  void start() {
    if (_gpsSub != null) return; // already started

    _gpsSub = locationMonitor.positionStream.listen(
      _onPosition,
      // TODO: maybe show something to the user instead of just printing
      onError: (e) => debugPrint('gps error: $e'),
    );
  }

  void _onPosition(Position position) {
    for (final zone in zoneStorage.getZones()) {
      final previous = _lastState[zone.id] ?? ZoneProximityState.outside;
      final distance = evaluator.distanceToZone(
        zone,
        position.latitude,
        position.longitude,
      );
      final current = evaluator.evaluate(
        zone: zone,
        distanceMeters: distance,
        previousState: previous,
      );

      if (current != previous) {
        _lastState[zone.id] = current;
        alertService.onZoneChange(zone, current);
      }
    }
  }
}
