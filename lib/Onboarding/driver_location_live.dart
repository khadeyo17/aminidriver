import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

class DriverLocationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void startSendingLocation() async {
    // Get the currently logged-in user's UID
    final User? user = _auth.currentUser;
    if (user == null) {
      print('User not logged in.');
      return;
    }

    final String driverId = user.uid;

    // Check location permission
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever)
      return;

    // Start streaming location
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      FirebaseDatabase.instance.ref('drivers/$driverId/location').set({
        'lat': position.latitude,
        'lng': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }, onError: (e) => print('Location update error: $e'));
  }
}

// import 'package:firebase_database/firebase_database.dart';
// import 'package:geolocator/geolocator.dart';

// class DriverLocationService {
//   final String driverId;
//   DriverLocationService(this.driverId);

//   void startSendingLocation() async {
//     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) return;

//     LocationPermission permission = await Geolocator.requestPermission();
//     if (permission == LocationPermission.denied ||
//         permission == LocationPermission.deniedForever)
//       return;

//     Geolocator.getPositionStream(
//       locationSettings: LocationSettings(
//         accuracy: LocationAccuracy.high,
//         distanceFilter: 10,
//       ),
//     ).listen((Position position) {
//       FirebaseDatabase.instance.ref('drivers/$driverId/location').set({
//         'lat': position.latitude,
//         'lng': position.longitude,
//         'timestamp': DateTime.now().toIso8601String(),
//       });
//     });
//   }
// }
