import 'package:geolocator/geolocator.dart';

/// Service responsible for location-based features.
/// 
/// This service handles requesting location permissions and checking
/// if the user is within a specified distance of a target location.
class LocationService {
  /// Coordinates for IFSul - Campus Santana do Livramento
  static const double campusLatitude = -30.869;
  static const double campusLongitude = -55.533;
  
  /// Maximum distance in meters to trigger the Easter egg (50 meters)
  static const double maxDistanceMeters = 50.0;

  /// Checks if location services are enabled.
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Requests location permission from the user.
  /// 
  /// Returns true if permission is granted, false otherwise.
  Future<bool> requestLocationPermission() async {
    // Check if location services are enabled first
    final isEnabled = await isLocationServiceEnabled();
    if (!isEnabled) {
      return false;
    }

    // Check current permission status
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      // Request permission
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permission is permanently denied, cannot request again
      return false;
    }

    // Permission is granted (whileInUse or always)
    return true;
  }

  /// Gets the user's current position.
  /// 
  /// Returns the current [Position] if available, null otherwise.
  /// Throws an exception if permission is not granted or location cannot be determined.
  Future<Position?> getCurrentPosition() async {
    // Check if permission is granted
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || 
        permission == LocationPermission.deniedForever) {
      return null;
    }

    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    try {
      // Get current position with desired accuracy
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return position;
    } catch (e) {
      print('Error getting current position: $e');
      return null;
    }
  }

  /// Calculates the distance between two coordinates in meters.
  /// 
  /// Returns the distance in meters between the two points.
  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Checks if the user is within the specified distance of the campus.
  /// 
  /// This method:
  /// 1. Requests location permission if not already granted
  /// 2. Gets the current position
  /// 3. Calculates the distance to the campus
  /// 4. Returns true if within maxDistanceMeters, false otherwise
  /// 
  /// Returns null if location cannot be determined (permission denied, service disabled, etc.)
  Future<bool?> isWithinCampusRange() async {
    try {
      // Request permission if needed
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        print('Location permission not granted');
        return false;
      }

      // Get current position
      final position = await getCurrentPosition();
      if (position == null) {
        print('Could not get current position');
        return false;
      }

      // Calculate distance to campus
      final distance = calculateDistance(
        position.latitude,
        position.longitude,
        campusLatitude,
        campusLongitude,
      );

      print('Distance to campus: ${distance.toStringAsFixed(2)} meters');

      // Check if within range
      return distance <= maxDistanceMeters;
    } catch (e) {
      print('Error checking location: $e');
      return false;
    }
  }
}

