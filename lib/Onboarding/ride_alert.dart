import 'dart:async';
import 'dart:convert';
import 'package:aminidriver/Container/utils/keys.dart';
import 'package:aminidriver/Container/utils/pending_ride_storage.dart';
import 'package:aminidriver/Onboarding/driver_location_live.dart';
import 'package:aminidriver/Onboarding/trip_detail_screen.dart';
import 'package:aminidriver/View/Screens/Nav_Screens/navigation_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RideAlertScreen extends StatefulWidget {
  final String rideId;
  final String rider;
  final String pickupName;
  final String destinationName;
  final double pickupLat;
  final double pickupLng;
  final double destLat;
  final double destLng;

  const RideAlertScreen({
    super.key,
    required this.rideId,
    required this.pickupName,
    required this.destinationName,
    required this.pickupLat,
    required this.pickupLng,
    required this.destLat,
    required this.destLng,
    required this.rider,
  });

  @override
  State<RideAlertScreen> createState() => _RideAlertScreenState();
}

class _RideAlertScreenState extends State<RideAlertScreen> {
  int _remaining = 30;
  Timer? _timer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  GoogleMapController? _mapController;
  late CameraPosition _initialCamera;

  @override
  void initState() {
    super.initState();
    _initialCamera = CameraPosition(
      target: LatLng(widget.pickupLat, widget.pickupLng),
      zoom: 13,
    );
    _startCountdown();
    _playRingtone();

    _checkPendingRide();
  }

  Future<void> _checkPendingRide() async {
    final pendingRide = await getPendingRide();
    if (pendingRide == null) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => NavigationScreen()),
      );
    }
  }

  // void _playRingtone() async {
  //   await _audioPlayer.play(AssetSource('assets/ringtone.mp3'), volume: 1.0);
  //   _audioPlayer.setReleaseMode(ReleaseMode.loop);
  // }
  void _playRingtone() async {
    const ringtoneUrl =
        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';

    await _audioPlayer.play(UrlSource(ringtoneUrl), volume: 1.0);
    _audioPlayer.setReleaseMode(ReleaseMode.loop);
  }

  void _stopRingtone() {
    _audioPlayer.stop();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining > 0) {
        setState(() => _remaining--);
      } else {
        timer.cancel();
        _rejectRide(context, auto: true);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => NavigationScreen()),
        );
      }
    });
  }

  Future<void> _acceptRide(BuildContext context) async {
    _timer?.cancel();
    _stopRingtone();

    final user = FirebaseAuth.instance.currentUser;
    final position = await _getCurrentPosition();

    final response = await http.post(
      Uri.parse('$baseUrl/rides/driver/accept-ride'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'rideId': int.parse(widget.rideId),
        'firebaseIdToken': user?.uid,
        'latitude': position.latitude,
        'longitude': position.longitude,
      }),
    );

    if (response.statusCode == 200) {
      DriverLocationService().startSendingLocation();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (_) => TripDetailScreen(
                rideId: widget.rideId,
                rider: widget.rider,
                pickupName: widget.pickupName,
                destinationName: widget.destinationName,
                pickupLat: widget.pickupLat,
                pickupLng: widget.pickupLng,
                destLat: widget.destLat,
                destLng: widget.destLng,
              ),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Failed to accept ride")));
    }
  }

  Future<void> _rejectRide(BuildContext context, {bool auto = false}) async {
    _timer?.cancel();
    _stopRingtone();

    final user = FirebaseAuth.instance.currentUser;
    final response = await http.post(
      Uri.parse('$baseUrl/rides/reject-ride'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'rideId': widget.rideId, 'firebaseToken': user?.uid}),
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);

      //await _audioPlayer.stop();

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => NavigationScreen()),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? 'Failed to reject ride')),
      );
    } else {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => NavigationScreen()),
      );
    }

    if (mounted) {
      Navigator.pop(context);
      if (auto) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("⏳ Ride request expired")));
      }
    }
  }

  Future<Position> _getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Location services are disabled.');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopRingtone();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Set<Marker> markers = {
      Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(widget.pickupLat, widget.pickupLng),
        infoWindow: InfoWindow(title: 'Pickup: ${widget.pickupName}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(widget.destLat, widget.destLng),
        infoWindow: InfoWindow(title: 'Destination: ${widget.destinationName}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };

    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      body: Center(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          elevation: 12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.directions_car_filled,
                  size: 80,
                  color: Colors.green,
                ),
                const SizedBox(height: 20),
                Text(
                  "New Ride Request",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 15),
                _buildInfoRow(Icons.location_pin, "Pickup", widget.pickupName),
                const SizedBox(height: 10),
                _buildInfoRow(
                  Icons.flag,
                  "Destination",
                  widget.destinationName,
                ),
                const SizedBox(height: 20),
                // Google Maps mini preview
                SizedBox(
                  height: 180,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: GoogleMap(
                      initialCameraPosition: _initialCamera,
                      markers: markers,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 25,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    "⏳ $_remaining seconds left",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _rejectRide(context),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          backgroundColor: Colors.red.shade400,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text(
                          "Reject",
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _acceptRide(context),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          backgroundColor: Colors.green.shade600,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text(
                          "Accept",
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.green.shade700, size: 28),
        const SizedBox(width: 10),
        Text(
          "$title: ",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 22),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
// import 'dart:async';
// import 'dart:convert';
// import 'package:aminidriver/Container/utils/api_constant.dart';
// import 'package:aminidriver/Container/utils/keys.dart';
// import 'package:aminidriver/Onboarding/driver_location_live.dart';
// import 'package:aminidriver/Onboarding/trip_detail_screen.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:http/http.dart' as http;

// class RideAlertScreen extends StatefulWidget {
//   final String rideId;
//   final String rider;
//   final String pickupName;
//   final String destinationName;
//   final double pickupLat;
//   final double pickupLng;
//   final double destLat;
//   final double destLng;

//   const RideAlertScreen({
//     super.key,
//     required this.rideId,
//     required this.pickupName,
//     required this.destinationName,
//     required this.pickupLat,
//     required this.pickupLng,
//     required this.destLat,
//     required this.destLng,
//     required this.rider,
//   });

//   @override
//   State<RideAlertScreen> createState() => _RideAlertScreenState();
// }

// class _RideAlertScreenState extends State<RideAlertScreen> {
//   int _remaining = 30;
//   Timer? _timer;

//   @override
//   void initState() {
//     super.initState();
//     _startCountdown();
//   }

//   void _startCountdown() {
//     _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       if (_remaining > 0) {
//         setState(() => _remaining--);
//       } else {
//         timer.cancel();
//         _rejectRide(context, auto: true); // auto reject after timeout
//       }
//     });
//   }

//   Future<void> _acceptRide(BuildContext context) async {
//     _timer?.cancel();
//     final user = FirebaseAuth.instance.currentUser;
//     final idToken = await user?.getIdToken();

//     final position = await _getCurrentPosition();
//     final driversLatitude = position.latitude;
//     final driversLongitude = position.longitude;

//     final response = await http.post(
//       Uri.parse('$baseUrl/rides/driver/accept-ride'),
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode({
//         'rideId': int.parse(widget.rideId),
//         'firebaseIdToken': user?.uid,
//         'latitude': driversLatitude,
//         'longitude': driversLongitude,
//       }),
//     );

//     if (response.statusCode == 200) {
//       DriverLocationService().startSendingLocation();
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(
//           builder:
//               (_) => TripDetailScreen(
//                 rideId: widget.rideId,
//                 rider: widget.rider,
//                 pickupName: widget.pickupName,
//                 destinationName: widget.destinationName,
//                 pickupLat: widget.pickupLat,
//                 pickupLng: widget.pickupLng,
//                 destLat: widget.destLat,
//                 destLng: widget.destLng,
//               ),
//         ),
//       );
//     } else {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text("Failed to accept ride")));
//     }
//   }

//   Future<void> _rejectRide(BuildContext context, {bool auto = false}) async {
//     _timer?.cancel();
//     final user = FirebaseAuth.instance.currentUser;
//     final url = Uri.parse('$baseUrl/rides/reject-ride');

//     final response = await http.post(
//       url,
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode({'rideId': widget.rideId, 'firebaseToken': user?.uid}),
//     );

//     if (response.statusCode != 200) {
//       final data = jsonDecode(response.body);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(data['message'] ?? 'Failed to reject ride')),
//       );
//     }

//     if (mounted) {
//       Navigator.pop(context);
//       if (auto) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(const SnackBar(content: Text("⏳ Ride request expired")));
//       }
//     }
//   }

//   Future<Position> _getCurrentPosition() async {
//     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) throw Exception('Location services are disabled.');

//     LocationPermission permission = await Geolocator.checkPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.denied) {
//         throw Exception('Location permissions are denied');
//       }
//     }

//     if (permission == LocationPermission.deniedForever) {
//       throw Exception('Location permissions are permanently denied.');
//     }

//     return await Geolocator.getCurrentPosition(
//       desiredAccuracy: LocationAccuracy.high,
//     );
//   }

//   @override
//   void dispose() {
//     _timer?.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("New Ride Request"),
//         backgroundColor: Colors.green,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               "Pickup: ${widget.pickupName}",
//               style: const TextStyle(fontSize: 18),
//             ),
//             const SizedBox(height: 10),
//             Text(
//               "Destination: ${widget.destinationName}",
//               style: const TextStyle(fontSize: 18),
//             ),
//             const SizedBox(height: 20),
//             Center(
//               child: Text(
//                 "⏳ $_remaining seconds left",
//                 style: const TextStyle(
//                   fontSize: 20,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.red,
//                 ),
//               ),
//             ),
//             const Spacer(),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 ElevatedButton(
//                   style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//                   onPressed: () => _rejectRide(context),
//                   child: const Text("Reject"),
//                 ),
//                 ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.green,
//                   ),
//                   onPressed: () => _acceptRide(context),
//                   child: const Text("Accept"),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
// // import 'dart:async';
// // import 'dart:convert';
// // import 'package:aminidriver/Container/utils/api_constant.dart';
// // import 'package:aminidriver/Container/utils/keys.dart';
// // import 'package:aminidriver/Onboarding/driver_location_live.dart';
// // import 'package:aminidriver/Onboarding/trip_detail_screen.dart';
// // import 'package:firebase_auth/firebase_auth.dart';
// // import 'package:flutter/material.dart';
// // import 'package:geolocator/geolocator.dart';
// // import 'package:http/http.dart' as http;

// // class RideAlertScreen extends StatefulWidget {
// //   final String rideId;
// //   final String rider;
// //   final String pickupName;
// //   final String destinationName;
// //   final double pickupLat;
// //   final double pickupLng;
// //   final double destLat;
// //   final double destLng;

// //   const RideAlertScreen({
// //     super.key,
// //     required this.rideId,
// //     required this.pickupName,
// //     required this.destinationName,
// //     required this.pickupLat,
// //     required this.pickupLng,
// //     required this.destLat,
// //     required this.destLng,
// //     required this.rider,
// //   });

// //   @override
// //   State<RideAlertScreen> createState() => _RideAlertScreenState();
// // }

// // class _RideAlertScreenState extends State<RideAlertScreen> {
// //   int _remaining = 30;
// //   Timer? _timer;

// //   @override
// //   void initState() {
// //     super.initState();
// //     _startCountdown();
// //   }

// //   void _startCountdown() {
// //     _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
// //       if (_remaining > 0) {
// //         setState(() => _remaining--);
// //       } else {
// //         timer.cancel();
// //         _rejectRide(context, auto: true); // auto reject after timeout
// //       }
// //     });
// //   }

// //   Future<void> _acceptRide(BuildContext context) async {
// //     _timer?.cancel();
// //     final user = FirebaseAuth.instance.currentUser;
// //     final idToken = await user?.getIdToken();

// //     final position = await _getCurrentPosition();
// //     final driversLatitude = position.latitude;
// //     final driversLongitude = position.longitude;

// //     final response = await http.post(
// //       Uri.parse('$baseUrl/rides/driver/accept-ride'),
// //       headers: {'Content-Type': 'application/json'},
// //       body: jsonEncode({
// //         'rideId': int.parse(widget.rideId),
// //         'firebaseIdToken': user?.uid,
// //         'latitude': driversLatitude,
// //         'longitude': driversLongitude,
// //       }),
// //     );

// //     if (response.statusCode == 200) {
// //       DriverLocationService().startSendingLocation();
// //       Navigator.pushReplacement(
// //         context,
// //         MaterialPageRoute(
// //           builder:
// //               (_) => TripDetailScreen(
// //                 rideId: widget.rideId,
// //                 rider: widget.rider,
// //                 pickupName: widget.pickupName,
// //                 destinationName: widget.destinationName,
// //                 pickupLat: widget.pickupLat,
// //                 pickupLng: widget.pickupLng,
// //                 destLat: widget.destLat,
// //                 destLng: widget.destLng,
// //               ),
// //         ),
// //       );
// //     } else {
// //       ScaffoldMessenger.of(
// //         context,
// //       ).showSnackBar(const SnackBar(content: Text("Failed to accept ride")));
// //     }
// //   }

// //   Future<void> _rejectRide(BuildContext context, {bool auto = false}) async {
// //     _timer?.cancel();
// //     final user = FirebaseAuth.instance.currentUser;
// //     final url = Uri.parse('$baseUrl/rides/reject-ride');

// //     final response = await http.post(
// //       url,
// //       headers: {'Content-Type': 'application/json'},
// //       body: jsonEncode({'rideId': widget.rideId, 'firebaseToken': user?.uid}),
// //     );

// //     if (response.statusCode != 200) {
// //       final data = jsonDecode(response.body);
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(content: Text(data['message'] ?? 'Failed to reject ride')),
// //       );
// //     }

// //     if (mounted) {
// //       Navigator.pop(context);
// //       if (auto) {
// //         ScaffoldMessenger.of(
// //           context,
// //         ).showSnackBar(const SnackBar(content: Text("⏳ Ride request expired")));
// //       }
// //     }
// //   }

// //   Future<Position> _getCurrentPosition() async {
// //     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
// //     if (!serviceEnabled) throw Exception('Location services are disabled.');

// //     LocationPermission permission = await Geolocator.checkPermission();
// //     if (permission == LocationPermission.denied) {
// //       permission = await Geolocator.requestPermission();
// //       if (permission == LocationPermission.denied) {
// //         throw Exception('Location permissions are denied');
// //       }
// //     }

// //     if (permission == LocationPermission.deniedForever) {
// //       throw Exception('Location permissions are permanently denied.');
// //     }

// //     return await Geolocator.getCurrentPosition(
// //       desiredAccuracy: LocationAccuracy.high,
// //     );
// //   }

// //   @override
// //   void dispose() {
// //     _timer?.cancel();
// //     super.dispose();
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(
// //         title: const Text("New Ride Request"),
// //         backgroundColor: Colors.green,
// //       ),
// //       body: Padding(
// //         padding: const EdgeInsets.all(16.0),
// //         child: Column(
// //           mainAxisAlignment: MainAxisAlignment.center,
// //           crossAxisAlignment: CrossAxisAlignment.start,
// //           children: [
// //             Text(
// //               "Pickup: ${widget.pickupName}",
// //               style: const TextStyle(fontSize: 18),
// //             ),
// //             const SizedBox(height: 10),
// //             Text(
// //               "Destination: ${widget.destinationName}",
// //               style: const TextStyle(fontSize: 18),
// //             ),
// //             const SizedBox(height: 20),
// //             Center(
// //               child: Text(
// //                 "⏳ $_remaining seconds left",
// //                 style: const TextStyle(
// //                   fontSize: 20,
// //                   fontWeight: FontWeight.bold,
// //                   color: Colors.red,
// //                 ),
// //               ),
// //             ),
// //             const Spacer(),
// //             Row(
// //               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
// //               children: [
// //                 ElevatedButton(
// //                   style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
// //                   onPressed: () => _rejectRide(context),
// //                   child: const Text("Reject"),
// //                 ),
// //                 ElevatedButton(
// //                   style: ElevatedButton.styleFrom(
// //                     backgroundColor: Colors.green,
// //                   ),
// //                   onPressed: () => _acceptRide(context),
// //                   child: const Text("Accept"),
// //                 ),
// //               ],
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// // }

// // // import 'dart:convert';

// // // import 'package:aminidriver/Container/utils/api_constant.dart';
// // // import 'package:aminidriver/Onboarding/driver_location_live.dart';
// // // import 'package:aminidriver/Onboarding/trip_detail_screen.dart';
// // // import 'package:firebase_auth/firebase_auth.dart';
// // // import 'package:flutter/material.dart';
// // // import 'package:geolocator/geolocator.dart';
// // // import 'package:http/http.dart' as http;

// // // class RideAlertPopup extends StatelessWidget {
// // //   final String rideId;
// // //   final String rider;
// // //   final String pickupName;
// // //   final String destinationName;
// // //   final double pickupLat;
// // //   final double pickupLng;
// // //   final double destLat;
// // //   final double destLng;
// // //   final VoidCallback onAccept;
// // //   final VoidCallback onReject;

// // //   const RideAlertPopup({
// // //     super.key,
// // //     required this.rideId,
// // //     required this.pickupName,
// // //     required this.destinationName,
// // //     required this.pickupLat,
// // //     required this.pickupLng,
// // //     required this.destLat,
// // //     required this.destLng,
// // //     required this.onAccept,
// // //     required this.onReject,
// // //     required this.rider,
// // //   });
// // //   Future<void> _acceptRide(BuildContext context) async {
// // //     final user = FirebaseAuth.instance.currentUser;
// // //     final idToken = await user?.getIdToken();

// // //     final position = await _getCurrentPosition();
// // //     final driversLatitude = position.latitude;
// // //     final driversLongitude = position.longitude;

// // //     final response = await http.post(
// // //       Uri.parse('$baseUrl/rides/driver/accept-ride'),
// // //       headers: {'Content-Type': 'application/json'},
// // //       body: jsonEncode({
// // //         'rideId': int.parse(rideId), // assuming rideId is a string
// // //         'firebaseIdToken': idToken,
// // //         'latitude': driversLatitude,
// // //         'longitude': driversLongitude,

// // //         // Replace with real method
// // //       }),
// // //     );

// // //     if (response.statusCode == 200) {
// // //       DriverLocationService().startSendingLocation();
// // //       // Navigate to TripDetailScreen
// // //       Navigator.pushReplacement(
// // //         context,
// // //         MaterialPageRoute(
// // //           builder:
// // //               (_) => TripDetailScreen(
// // //                 rideId: rideId,
// // //                 rider: rider,
// // //                 pickupName: pickupName,
// // //                 destinationName: destinationName,
// // //                 pickupLat: pickupLat,
// // //                 pickupLng: pickupLng,
// // //                 destLat: destLat,
// // //                 destLng: destLng,
// // //               ),
// // //         ),
// // //       );
// // //     } else {
// // //       ScaffoldMessenger.of(
// // //         context,
// // //       ).showSnackBar(const SnackBar(content: Text("Failed to accept ride")));
// // //     }
// // //   }

// // //   Future<Position> _getCurrentPosition() async {
// // //     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
// // //     if (!serviceEnabled) {
// // //       throw Exception('Location services are disabled.');
// // //     }

// // //     LocationPermission permission = await Geolocator.checkPermission();
// // //     if (permission == LocationPermission.denied) {
// // //       permission = await Geolocator.requestPermission();
// // //       if (permission == LocationPermission.denied) {
// // //         throw Exception('Location permissions are denied');
// // //       }
// // //     }

// // //     if (permission == LocationPermission.deniedForever) {
// // //       throw Exception('Location permissions are permanently denied.');
// // //     }

// // //     return await Geolocator.getCurrentPosition(
// // //       desiredAccuracy: LocationAccuracy.high,
// // //     );
// // //   }

// // //   Future<void> rejectRide(BuildContext context) async {
// // //     final user = FirebaseAuth.instance.currentUser;
// // //     final idToken = await user?.getIdToken();

// // //     final url = Uri.parse('$baseUrl/rides/reject-ride');

// // //     final response = await http.post(
// // //       url,
// // //       headers: {'Content-Type': 'application/json'},
// // //       body: jsonEncode({'rideId': rideId, 'firebaseToken': user?.uid}),
// // //     );

// // //     if (response.statusCode != 200) {
// // //       final data = jsonDecode(response.body);
// // //       throw Exception(data['message'] ?? 'Failed to reject ride');
// // //     }
// // //   }

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     return AlertDialog(
// // //       title: const Text('New Ride Request'),
// // //       content: Column(
// // //         mainAxisSize: MainAxisSize.min,
// // //         children: [
// // //           Text('Pickup: $pickupName'),
// // //           Text('Destination: $destinationName'),
// // //         ],
// // //       ),
// // //       actions: [
// // //         TextButton(
// // //           onPressed: () => rejectRide(context),
// // //           child: const Text('Reject'),
// // //         ),
// // //         ElevatedButton(
// // //           onPressed: () => _acceptRide(context),
// // //           child: const Text('Accept'),
// // //         ),
// // //       ],
// // //     );
// // //   }
// // // }
