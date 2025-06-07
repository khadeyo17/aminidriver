//import 'package:aminidriver/View/Screens/Auth_Screens/Driver_config/driver_location_notifier';
//import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/driver_location.dart';
import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/driver_location_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:aminidriver/Model/direction_model.dart';
import 'package:aminidriver/Container/Repositories/firestore_repo.dart'; // Import the FirestoreRepo
// State providers for map-related state
// final homeScreenDriversLocationProvider = StateProvider<Direction?>((ref) {
//   return null;
// });

final homeScreenMainPolylinesProvider = StateProvider<Set<Polyline>>((ref) {
  return {};
});

final homeScreenMainMarkersProvider = StateProvider<Set<Marker>>((ref) {
  return {};
});

final homeScreenMainCirclesProvider = StateProvider<Set<Circle>>((ref) {
  return {};
});

final homeScreenIsDriverActiveProvider = StateProvider<bool>((ref) {
  return false;
});

// Firestore repository provider
final globalFirestoreRepoProvider = Provider<FirestoreRepo>((ref) {
  return FirestoreRepo();
});
final homeScreenDriversLocationProvider =
    StateNotifierProvider<DriverLocationNotifier, Direction?>(
      (ref) => DriverLocationNotifier(),
    );

// final homeScreenDriversLocationProvider = FutureProvider<Direction?>((
//   ref,
// ) async {
//   final hasPermission = await Geolocator.checkPermission();
//   if (hasPermission == LocationPermission.denied ||
//       hasPermission == LocationPermission.deniedForever) {
//     await Geolocator.requestPermission();
//   }

//   final position = await Geolocator.getCurrentPosition(
//     desiredAccuracy: LocationAccuracy.high,
//   );

//   return Direction(
//     locationLatitude: position.latitude,
//     locationLongitude: position.longitude,
//   );
// });
