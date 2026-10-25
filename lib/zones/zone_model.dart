class RestrictedZone {
  final String id;
  final String name;
  final double centerLat;
  final double centerLng;
  final double radiusMeters;
  final DateTime createdAt;

  const RestrictedZone({
    required this.id,
    required this.name,
    required this.centerLat,
    required this.centerLng,
    required this.radiusMeters,
    required this.createdAt,
  });

  RestrictedZone copyWith({
    String? name,
    double? centerLat,
    double? centerLng,
    double? radiusMeters,
  }) {
    return RestrictedZone(
      id: id,
      name: name ?? this.name,
      centerLat: centerLat ?? this.centerLat,
      centerLng: centerLng ?? this.centerLng,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'centerLat': centerLat,
    'centerLng': centerLng,
    'radiusMeters': radiusMeters,
    'createdAt': createdAt.toIso8601String(),
  };

  factory RestrictedZone.fromMap(Map<dynamic, dynamic> map) {
    return RestrictedZone(
      id: map['id'] as String,
      name: map['name'] as String,
      centerLat: (map['centerLat'] as num).toDouble(),
      centerLng: (map['centerLng'] as num).toDouble(),
      radiusMeters: (map['radiusMeters'] as num).toDouble(),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
