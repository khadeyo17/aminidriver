import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:audioplayers/audioplayers.dart';

const double baseFare = 100;
const double perKmFare = 50;

class LiveTrackingScreen extends StatefulWidget {
  final String rideId;
  final LatLng? pickup;
  final LatLng? destination;

  const LiveTrackingScreen({
    super.key,
    required this.rideId,
    this.pickup,
    this.destination,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  LatLng? _currentLocation;
  GoogleMapController? _mapController;
  Marker? _driverMarker;
  Set<Polyline> _polylines = {};
  double _distanceTraveledKm = 0;
  bool _ended = false;
  final DatabaseReference _rideRef = FirebaseDatabase.instance.ref();
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _startLocationTracking() {
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      Position pos = await Geolocator.getCurrentPosition();
      LatLng newLoc = LatLng(pos.latitude, pos.longitude);

      // Track distance
      if (_currentLocation != null) {
        _distanceTraveledKm += _haversineKm(_currentLocation!, newLoc);
      }

      setState(() {
        _currentLocation = newLoc;
        _driverMarker = Marker(
          markerId: const MarkerId("driver"),
          position: newLoc,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        );
      });

      // Animate camera to new location
      _mapController?.animateCamera(CameraUpdate.newLatLng(newLoc));

      // Update Firebase Realtime DB
      FirebaseDatabase.instance
          .ref('drivers/${FirebaseAuth.instance.currentUser!.uid}/location')
          .set({
            'lat': pos.latitude,
            'lng': pos.longitude,
            'timestamp': ServerValue.timestamp,
          });

      // Play sound when near destination
      if (_haversineKm(newLoc, widget.destination!) < 0.1) {
        _audioPlayer.play(AssetSource('sounds/alert.mp3'));
      }
    });
  }

  Future<void> _endRide() async {
    if (_ended || _currentLocation == null) return;

    double fare = _computeFare(_distanceTraveledKm);

    // Update Firebase ride node
    await _rideRef.child('rides/${widget.rideId}').update({
      'status': 'completed',
      'destination/lat': _currentLocation!.latitude,
      'destination/lng': _currentLocation!.longitude,
      'distanceKm': double.parse(_distanceTraveledKm.toStringAsFixed(2)),
      'fare': double.parse(fare.toStringAsFixed(2)),
      'endedAt': ServerValue.timestamp,
    });

    setState(() => _ended = true);
    //_showFareDialog(fare);
    _showFareSheet(fare);
  }

  double _computeFare(double traveledKm) => baseFare + traveledKm * perKmFare;

  double _haversineKm(LatLng a, LatLng b) {
    const R = 6371.0;
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLng = _degToRad(b.longitude - a.longitude);
    final s1 = math.sin(dLat / 2);
    final s2 = math.sin(dLng / 2);
    final aa =
        s1 * s1 +
        math.cos(_degToRad(a.latitude)) *
            math.cos(_degToRad(b.latitude)) *
            s2 *
            s2;
    return R * 2 * math.atan2(math.sqrt(aa), math.sqrt(1 - aa));
  }

  double _degToRad(double d) => d * math.pi / 180.0;

  void _showFareDialog(double fare) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Trip Completed'),
            content: Text(
              'Distance: ${_distanceTraveledKm.toStringAsFixed(2)} km\n'
              'Amount to pay: KES ${fare.toStringAsFixed(2)}',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context); // Back to main
                },
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showFareSheet(double fare) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (_) => Container(
            padding: const EdgeInsets.all(24),
            height: 220,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Trip Completed',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Distance: ${_distanceTraveledKm.toStringAsFixed(2)} km',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Amount to Pay: KES ${fare.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close bottom sheet
                    Navigator.pop(context); // Back to main screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 32,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Close', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Ride Tracking'),
        centerTitle: true,
      ),
      body:
          _currentLocation == null
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentLocation!,
                  zoom: 16,
                ),
                markers: _driverMarker != null ? {_driverMarker!} : {},
                polylines: _polylines,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                onMapCreated: (c) => _mapController = c,
              ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _endRide,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text("End Ride"),
        ),
      ),
    );
  }
}

// import 'dart:async';
// import 'dart:convert';

// import 'package:aminidriver/Container/utils/api_constant.dart';
// import 'package:aminidriver/Container/utils/keys.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:http/http.dart' as http;

// class LiveTrackingScreen extends StatefulWidget {
//   final String rideId;

//   const LiveTrackingScreen({required this.rideId, Key? key}) : super(key: key);

//   @override
//   _LiveTrackingScreenState createState() => _LiveTrackingScreenState();
// }

// class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
//   LatLng? _currentLocation;
//   Timer? _locationTimer;
//   GoogleMapController? _mapController;
//   Marker? _driverMarker;

//   @override
//   void initState() {
//     super.initState();
//     _startLocationTracking();
//   }

//   Future<void> _endRide() async {
//     final user = FirebaseAuth.instance.currentUser;
//     final idToken = await user?.getIdToken();

//     final url = Uri.parse('$baseUrl/rides/${widget.rideId}/end');

//     try {
//       final response = await http.put(
//         url,
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $idToken',
//         },
//         body: jsonEncode({
//           'latitude': _currentLocation?.latitude,
//           'longitude': _currentLocation?.longitude,
//         }),
//       );

//       if (response.statusCode == 200) {
//         final rideRef = FirebaseDatabase.instance.ref("rides/${widget.rideId}");
//         await rideRef.update({
//           "status": "completed",
//           "destination/lat": _currentLocation?.latitude,
//           "destination/lng": _currentLocation?.longitude,
//           "endTime": DateTime.now().toIso8601String(),

//         });

//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("Ride ended successfully")),
//         );
//         Navigator.pop(context); // go back after ending ride
//       } else {
//         throw Exception("Failed to end ride");
//       }
//     } catch (e) {
//       debugPrint("End ride error: $e");
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text("Error ending ride: $e")));
//     }
//   }

//   void _startLocationTracking() {
//     _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
//       Position pos = await Geolocator.getCurrentPosition();
//       LatLng newLocation = LatLng(pos.latitude, pos.longitude);

//       setState(() {
//         _currentLocation = newLocation;
//         _driverMarker = Marker(
//           markerId: const MarkerId("driver"),
//           position: newLocation,
//           icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//         );
//       });

//       // Animate camera to new location
//       if (_mapController != null) {
//         _mapController!.animateCamera(CameraUpdate.newLatLng(newLocation));
//       }

//       // Update Firebase realtime DB
//       FirebaseDatabase.instance
//           .ref('drivers/${FirebaseAuth.instance.currentUser!.uid}/location')
//           .set({
//             'latitude': pos.latitude,
//             'longitude': pos.longitude,
//             'timestamp': ServerValue.timestamp,
//           });
//     });
//   }

//   @override
//   void dispose() {
//     _locationTimer?.cancel();
//     _mapController?.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         title: const Text("Live Ride Tracking"),
//         centerTitle: true,
//         backgroundColor: Colors.white,
//         elevation: 0,
//         foregroundColor: Colors.black,
//       ),
//       body:
//           _currentLocation == null
//               ? const Center(child: CircularProgressIndicator())
//               : GoogleMap(
//                 initialCameraPosition: CameraPosition(
//                   target: _currentLocation!,
//                   zoom: 16,
//                 ),
//                 myLocationEnabled: true,
//                 myLocationButtonEnabled: true,
//                 markers: _driverMarker != null ? {_driverMarker!} : {},
//                 onMapCreated: (controller) => _mapController = controller,
//               ),
//       bottomNavigationBar: Padding(
//         padding: const EdgeInsets.all(16),
//         child: ElevatedButton(
//           onPressed: _endRide,
//           style: ElevatedButton.styleFrom(
//             backgroundColor: Colors.red,
//             padding: const EdgeInsets.symmetric(vertical: 16),
//           ),
//           child: const Text("End Ride"),
//         ),
//       ),
//     );
//   }
// }

// // import 'dart:async';
// // import 'dart:convert';

// // import 'package:aminidriver/Container/utils/api_constant.dart';
// // import 'package:firebase_auth/firebase_auth.dart';
// // import 'package:firebase_database/firebase_database.dart';
// // import 'package:flutter/material.dart';
// // import 'package:flutter/widgets.dart';
// // import 'package:flutter_map/flutter_map.dart';
// // import 'package:geolocator/geolocator.dart';
// // import 'package:http/http.dart' as http;
// // import 'package:latlong2/latlong.dart';

// // class LiveTrackingScreen extends StatefulWidget {
// //   final String rideId;

// //   const LiveTrackingScreen({required this.rideId});

// //   @override
// //   _LiveTrackingScreenState createState() => _LiveTrackingScreenState();
// // }

// // class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
// //   LatLng? _currentLocation;
// //   Timer? _locationTimer;

// //   @override
// //   void initState() {
// //     super.initState();
// //     _startLocationTracking();
// //   }

// //   Future<void> _endRide() async {
// //     final user = FirebaseAuth.instance.currentUser;
// //     final idToken = await user?.getIdToken();

// //     final url = Uri.parse('$baseUrl/rides/${widget.rideId}/end');

// //     try {
// //       final response = await http.put(
// //         url,
// //         headers: {
// //           'Content-Type': 'application/json',
// //           //'Authorization': 'Bearer $idToken',
// //         },
// //         body: jsonEncode({
// //           'latitude': _currentLocation!.latitude,
// //           'longitude': _currentLocation!.longitude,
// //         }),
// //       );

// //       if (response.statusCode == 200) {
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           const SnackBar(content: Text("Ride started successfully")),
// //         );

// //         // Optional: Navigate to live tracking screen or update UI state
// //       } else {
// //         throw Exception("Failed to start ride");
// //       }
// //     } catch (e) {
// //       debugPrint("Start ride error: $e");
// //       ScaffoldMessenger.of(
// //         context,
// //       ).showSnackBar(SnackBar(content: Text("Error starting ride: $e")));
// //     }
// //   }

// //   void _startLocationTracking() {
// //     _locationTimer = Timer.periodic(Duration(seconds: 5), (_) async {
// //       Position pos = await Geolocator.getCurrentPosition();
// //       setState(() {
// //         _currentLocation = LatLng(pos.latitude, pos.longitude);
// //       });

// //       // Optionally send location to backend or Firebase
// //       FirebaseDatabase.instance
// //           .ref('drivers/${FirebaseAuth.instance.currentUser!.uid}/location')
// //           .set({
// //             'latitude': pos.latitude,
// //             'longitude': pos.longitude,
// //             'timestamp': ServerValue.timestamp,
// //           });
// //     });
// //   }

// //   @override
// //   void dispose() {
// //     _locationTimer?.cancel();
// //     super.dispose();
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       backgroundColor: Colors.white,
// //       appBar: AppBar(
// //         title: Text("Live Ride Tracking"),
// //         centerTitle: true,
// //         backgroundColor: Colors.white,
// //         elevation: 0,
// //         foregroundColor: Colors.black,
// //       ),
// //       body:
// //           _currentLocation == null
// //               ? Center(child: CircularProgressIndicator())
// //               : FlutterMap(
// //                 options: MapOptions(center: _currentLocation, zoom: 16),
// //                 children: [
// //                   TileLayer(
// //                     urlTemplate:
// //                         "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
// //                   ),
// //                   MarkerLayer(
// //                     markers: [
// //                       Marker(
// //                         point: _currentLocation!,
// //                         width: 40,
// //                         height: 40,
// //                         builder:
// //                             (context) =>
// //                                 Icon(Icons.local_taxi, color: Colors.blue),
// //                       ),
// //                     ],
// //                   ),
// //                 ],
// //               ),
// //       bottomNavigationBar: Padding(
// //         padding: EdgeInsets.all(16),
// //         child: ElevatedButton(
// //           onPressed: () {
// //             // Trigger end ride API
// //           },
// //           child: Text("End Ride"),
// //         ),
// //       ),
// //     );
// //   }
// // }
