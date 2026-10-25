import 'package:hive_flutter/hive_flutter.dart';

import 'zone_model.dart';

// saves the zones on the phone with hive
class ZoneStorage {
  final Box<Map> _box;

  ZoneStorage(this._box);

  static Future<ZoneStorage> open() async {
    final box = await Hive.openBox<Map>('zones');
    return ZoneStorage(box);
  }

  List<RestrictedZone> getZones() {
    return _box.values.map((raw) => RestrictedZone.fromMap(raw)).toList();
  }

  Future<void> addZone(RestrictedZone zone) async {
    await _box.put(zone.id, zone.toMap());
  }

  Future<void> updateZone(RestrictedZone zone) async {
    await _box.put(zone.id, zone.toMap());
  }

  Future<void> deleteZone(String zoneId) async {
    await _box.delete(zoneId);
  }
}
