import 'package:geolocator/geolocator.dart';

import '../zones/zone_model.dart';

enum ZoneProximityState { outside, approaching, inside }

// just the math part, no gps, so u can test it without a phone
//
// gps jumps around near the edge so u have to go a bit past the line
// before it counts as leaving, otherwise it spams notifications
class GeofenceEvaluator {
  final double warnDistance;
  final double exitBuffer;

  const GeofenceEvaluator({
    this.warnDistance = 50,
    this.exitBuffer = 10,
  });

  double distanceToZone(RestrictedZone zone, double lat, double lng) {
    return Geolocator.distanceBetween(
      lat,
      lng,
      zone.centerLat,
      zone.centerLng,
    );
  }

  ZoneProximityState evaluate({
    required RestrictedZone zone,
    required double distanceMeters,
    required ZoneProximityState previousState,
  }) {
    final insideDist = zone.radiusMeters;
    final warnDist = zone.radiusMeters + warnDistance;

    switch (previousState) {
      case ZoneProximityState.inside:
        if (distanceMeters > insideDist + exitBuffer) {
          return distanceMeters > warnDist
              ? ZoneProximityState.outside
              : ZoneProximityState.approaching;
        }
        return ZoneProximityState.inside;

      case ZoneProximityState.approaching:
        if (distanceMeters <= insideDist) {
          return ZoneProximityState.inside;
        }
        if (distanceMeters > warnDist + exitBuffer) {
          return ZoneProximityState.outside;
        }
        return ZoneProximityState.approaching;

      case ZoneProximityState.outside:
        if (distanceMeters <= insideDist) {
          return ZoneProximityState.inside;
        }
        if (distanceMeters <= warnDist) {
          return ZoneProximityState.approaching;
        }
        return ZoneProximityState.outside;
    }
  }
}
