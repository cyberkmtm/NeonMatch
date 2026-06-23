part of genz_app;

class LocationService {
  static Future<Map<String, dynamic>> getCurrentLocationData() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please turn on GPS.');
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permission denied.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission permanently denied. Enable it from app settings.',
      );
    }

    final Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    String readableLocation =
        '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';

    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;

        final city = place.locality?.trim().isNotEmpty == true
            ? place.locality!.trim()
            : place.subAdministrativeArea?.trim().isNotEmpty == true
                ? place.subAdministrativeArea!.trim()
                : place.administrativeArea?.trim() ?? '';

        final country = place.country?.trim() ?? '';

        final parts = [city, country].where((p) => p.isNotEmpty).toList();

        if (parts.isNotEmpty) {
          readableLocation = parts.join(', ');
        }
      }
    } catch (_) {
      // If reverse geocoding fails, keep the lat/lng text.
    }

    return {
      'location': readableLocation,
      'position': GeoPoint(position.latitude, position.longitude),
      'latitude': position.latitude,
      'longitude': position.longitude,
      'locationUpdatedAt': FieldValue.serverTimestamp(),
    };
  }

  static GeoPoint? readGeoPoint(Map<String, dynamic> data) {
    final rawPosition = data['position'];

    if (rawPosition is GeoPoint) return rawPosition;

    final lat = data['latitude'];
    final lng = data['longitude'];

    if (lat is num && lng is num) {
      return GeoPoint(lat.toDouble(), lng.toDouble());
    }

    return null;
  }

  static int? distanceMilesBetween(
    Map<String, dynamic> firstUser,
    Map<String, dynamic> secondUser,
  ) {
    final firstPoint = readGeoPoint(firstUser);
    final secondPoint = readGeoPoint(secondUser);

    if (firstPoint == null || secondPoint == null) return null;

    final meters = Geolocator.distanceBetween(
      firstPoint.latitude,
      firstPoint.longitude,
      secondPoint.latitude,
      secondPoint.longitude,
    );

    return (meters / 1609.344).round();
  }
}
