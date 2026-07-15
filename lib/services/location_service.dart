import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Calculates a destination GPS point given a starting point, distance (meters), and bearing (degrees).
  static Map<String, double> getOffsetCoordinate(
    double startLat,
    double startLng,
    double distanceInMeters,
    double bearingInDegrees,
  ) {
    const double earthRadius = 6378137.0; // in meters
    double bearingRad = bearingInDegrees * (math.pi / 180.0);

    double latRad = startLat * (math.pi / 180.0);
    double lngRad = startLng * (math.pi / 180.0);

    double dByR = distanceInMeters / earthRadius;

    double targetLatRad = math.asin(
      math.sin(latRad) * math.cos(dByR) +
      math.cos(latRad) * math.sin(dByR) * math.cos(bearingRad)
    );

    double targetLngRad = lngRad +
        math.atan2(
          math.sin(bearingRad) * math.sin(dByR) * math.cos(latRad),
          math.cos(dByR) - math.sin(latRad) * math.sin(targetLatRad),
        );

    return {
      'latitude': targetLatRad * (180.0 / math.pi),
      'longitude': targetLngRad * (180.0 / math.pi),
    };
  }

  /// Obtains the bearing (degrees) between two coordinates
  static double getBearing(double lat1, double lon1, double lat2, double lon2) {
    double dLon = (lon2 - lon1) * (math.pi / 180.0);
    double lat1Rad = lat1 * (math.pi / 180.0);
    double lat2Rad = lat2 * (math.pi / 180.0);

    double y = math.sin(dLon) * math.cos(lat2Rad);
    double x = math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);

    double brng = math.atan2(y, x);
    return ((brng * (180.0 / math.pi)) + 360.0) % 360.0;
  }
}
