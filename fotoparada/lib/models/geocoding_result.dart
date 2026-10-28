class GeocodingResult {
  final String displayName;
  final double latitude;
  final double longitude;
  final List<double> boundingBox;

  GeocodingResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.boundingBox,
  });

  factory GeocodingResult.fromJson(Map<String, dynamic> json) {
    return GeocodingResult(
      displayName: json['display_name'] as String? ?? 'Sin nombre',
      latitude: double.parse(json['lat'] as String),
      longitude: double.parse(json['lon'] as String),
      boundingBox: (json['boundingbox'] as List<dynamic>)
          .map((e) => double.parse(e as String))
          .toList(),
    );
  }
}