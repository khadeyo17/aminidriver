// import 'package:aminidriver/Model/direction_model.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:geolocator/geolocator.dart';

// class DriverLocationNotifier extends StateNotifier<Direction?> {
//   DriverLocationNotifier() : super(null) {
//     fetchCurrentLocation(); // Load initial location on creation
//   }

//   Future<void> fetchCurrentLocation() async {
//     try {
//       final hasPermission = await Geolocator.checkPermission();
//       if (hasPermission == LocationPermission.denied ||
//           hasPermission == LocationPermission.deniedForever) {
//         await Geolocator.requestPermission();
//       }

//       final position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );

//       state = Direction(
//         locationLatitude: position.latitude,
//         locationLongitude: position.longitude,
//       );
//     } catch (e) {
//       // handle location error if needed
//       print("Location error: $e");
//     }
//   }

//   void updateLocation(Position position) {
//     state = Direction(
//       locationLatitude: position.latitude,
//       locationLongitude: position.longitude,
//     );
//   }

//   void setLocation(Direction model) {}
// }
