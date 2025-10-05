import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:aminidriver/Container/utils/keys.dart';
import 'package:aminidriver/View/Routes/routes.dart';
import 'package:aminidriver/main.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_screen.dart';

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
  List<LatLng> _routePoints = [];
  int _lastRouteIndex = 0; // Last point drawn on the map

  @override
  void dispose() {
    _locationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;

    _initTracking();

    if (widget.pickup != null && widget.destination != null) {
      _loadRoute(widget.pickup!, widget.destination!);
    }
  }

  void _initTracking() {
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        LatLng newLoc = LatLng(pos.latitude, pos.longitude);

        if (_currentLocation != null) {
          _distanceTraveledKm += _haversineKm(_currentLocation!, newLoc);
        }

        _currentLocation = newLoc;
        _updateDriverMarker(newLoc);
        _updateRouteProgress(newLoc);

        _mapController?.animateCamera(CameraUpdate.newLatLng(newLoc));

        FirebaseDatabase.instance
            .ref('drivers/${FirebaseAuth.instance.currentUser!.uid}/location')
            .set({
              'lat': pos.latitude,
              'lng': pos.longitude,
              'timestamp': ServerValue.timestamp,
            });

        if (widget.destination != null &&
            _haversineKm(newLoc, widget.destination!) < 0.1) {
          _audioPlayer.play(AssetSource('sounds/alert.mp3'));
        }
      } catch (e) {
        debugPrint("Location tracking error: $e");
      }
    });
  }

  void _updateDriverMarker(LatLng newLoc) {
    setState(() {
      _driverMarker = Marker(
        markerId: const MarkerId("driver"),
        position: newLoc,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      );
    });
  }

  /// Incrementally draw route polyline up to the current location
  void _updateRouteProgress(LatLng current) {
    if (_routePoints.isEmpty) return;

    // Find the closest point ahead
    for (int i = _lastRouteIndex; i < _routePoints.length; i++) {
      if (_haversineKm(current, _routePoints[i]) < 0.05) {
        _lastRouteIndex = i;
      }
    }

    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId("route"),
          points: _routePoints.sublist(0, _lastRouteIndex + 1),
          color: Colors.blue,
          width: 5,
        ),
      };
    });
  }

  Future<void> _loadRoute(LatLng pickup, LatLng dest) async {
    final url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${pickup.latitude},${pickup.longitude}&destination=${dest.latitude},${dest.longitude}&mode=driving&key=$mapKey";

    try {
      final response = await http.get(Uri.parse(url));
      final data = jsonDecode(response.body);

      if (data['routes'].isNotEmpty) {
        final points = data['routes'][0]['overview_polyline']['points'];
        final decoded = _decodePolyline(points);
        final simplified = _simplifyPolyline(decoded, factor: 5);
        setState(() {
          _routePoints = simplified;
        });
      }
    } catch (e) {
      debugPrint("Error loading route: $e");
    }
  }

  List<LatLng> _simplifyPolyline(List<LatLng> points, {int factor = 3}) {
    final simplified = <LatLng>[];
    for (var i = 0; i < points.length; i += factor) simplified.add(points[i]);
    if (points.isNotEmpty) simplified.add(points.last);
    return simplified;
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      polyline.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return polyline;
  }

  Future<void> _endRide() async {
    if (_ended || _currentLocation == null) return;

    final url = Uri.parse('$baseUrl/rides/${widget.rideId}/end');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'latitude': _currentLocation?.latitude,
          'longitude': _currentLocation?.longitude,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final double fare = double.parse(responseData['fare'].toString());

        final db = FirebaseDatabase.instanceFor(app: passengerApp);
        final rideRef = db.ref("rides/${widget.rideId}");

        await rideRef.update({
          'status': 'completed',
          'destination/lat': _currentLocation!.latitude,
          'destination/lng': _currentLocation!.longitude,
          'distanceKm': double.parse(_distanceTraveledKm.toStringAsFixed(2)),
          'fare': double.parse(fare.toStringAsFixed(2)),
          'endedAt': ServerValue.timestamp,
        });

        setState(() => _ended = true);
        _showFareSheet(fare);
      } else {
        throw Exception("Failed to end ride");
      }
    } catch (e) {
      debugPrint("End ride error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error ending ride: $e")));
      }
    }
  }

  double _computeFare(double traveledKm) => baseFare + traveledKm * perKmFare;

  double _haversineKm(LatLng a, LatLng b) {
    const R = 6371.0;
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLng = _degToRad(b.longitude - a.longitude);
    final aa =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(a.latitude)) *
            math.cos(_degToRad(b.latitude)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return R * 2 * math.atan2(math.sqrt(aa), math.sqrt(1 - aa));
  }

  double _degToRad(double d) => d * math.pi / 180.0;

  void _showFareSheet(double fare) {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        final screenHeight = MediaQuery.of(context).size.height;
        return SizedBox(
          height: screenHeight * 0.5,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'Trip Completed',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Distance: ${_distanceTraveledKm.toStringAsFixed(2)} km',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Fare: KES ${fare.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      context.goNamed(Routes().navigationScreen);
                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(builder: (_) => const HomeScreen()),
                      // );
                      // Navigator.of(context).pushNamed(const HomeScreen()
                      //   MaterialPageRoute(builder: (_) => const HomeScreen()),
                      //   // (route) => false, // ✅ clear back stack
                      // );
                      // Navigator.pop(context);
                      // Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("OK", style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Ride Tracking')),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: widget.pickup ?? const LatLng(-1.286389, 36.817223),
          zoom: 14,
        ),
        markers: _driverMarker != null ? {_driverMarker!} : {},
        polylines: _polylines,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        onMapCreated: _onMapCreated,
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
// import 'dart:math' as math;
// import 'package:aminidriver/Container/utils/keys.dart'; // put your Google Maps API key in keys.dart
// import 'package:aminidriver/main.dart';
// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:audioplayers/audioplayers.dart';
// import 'package:http/http.dart' as http;

// const double baseFare = 100;
// const double perKmFare = 50;

// class LiveTrackingScreen extends StatefulWidget {
//   final String rideId;
//   final LatLng? pickup;
//   final LatLng? destination;

//   const LiveTrackingScreen({
//     super.key,
//     required this.rideId,
//     this.pickup,
//     this.destination,
//   });

//   @override
//   State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
// }

// class _LiveTrackingScreenState extends State<LiveTrackingScreen>
//     with TickerProviderStateMixin {
//   LatLng? _currentLocation;
//   GoogleMapController? _mapController;
//   Marker? _driverMarker;
//   Set<Polyline> _polylines = {};
//   double _distanceTraveledKm = 0;
//   bool _ended = false;
//   final DatabaseReference _rideRef = FirebaseDatabase.instance.ref();
//   final AudioPlayer _audioPlayer = AudioPlayer();
//   Timer? _locationTimer;
//   List<LatLng> _routePoints = [];
//   int _currentRouteIndex = 0;

//   @override
//   void dispose() {
//     _locationTimer?.cancel();
//     _mapController?.dispose();
//     super.dispose();
//   }

//   /// Map created → now safe to start tracking + route
//   void _onMapCreated(GoogleMapController controller) {
//     _mapController = controller;

//     if (widget.pickup != null && widget.destination != null) {
//       _loadRoute(widget.pickup!, widget.destination!);
//     }

//     _initTracking();
//   }

//   /// Start location tracking like Uber
//   void _initTracking() {
//     _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
//       try {
//         Position pos = await Geolocator.getCurrentPosition(
//           desiredAccuracy: LocationAccuracy.best,
//         );
//         LatLng newLoc = LatLng(pos.latitude, pos.longitude);

//         if (_currentLocation != null) {
//           _distanceTraveledKm += _haversineKm(_currentLocation!, newLoc);
//         }

//         _animateMarker(newLoc); // ✅ smooth animation
//         _currentLocation = newLoc;

//         // Smooth camera update
//         _mapController?.animateCamera(CameraUpdate.newLatLng(newLoc));

//         // Update Firebase driver location
//         FirebaseDatabase.instance
//             .ref('drivers/${FirebaseAuth.instance.currentUser!.uid}/location')
//             .set({
//               'lat': pos.latitude,
//               'lng': pos.longitude,
//               'timestamp': ServerValue.timestamp,
//             });

//         // Play alert near destination
//         if (widget.destination != null &&
//             _haversineKm(newLoc, widget.destination!) < 0.1) {
//           _audioPlayer.play(AssetSource('sounds/alert.mp3'));
//         }
//       } catch (e) {
//         debugPrint("Location tracking error: $e");
//       }
//     });
//   }

//   /// Animate marker smoothly
//   void _animateMarker(LatLng newLoc) {
//     final old = _driverMarker?.position ?? newLoc;
//     final tweenLat = Tween<double>(begin: old.latitude, end: newLoc.latitude);
//     final tweenLng = Tween<double>(begin: old.longitude, end: newLoc.longitude);

//     final controller = AnimationController(
//       duration: const Duration(seconds: 2),
//       vsync: this,
//     );

//     final animation = CurvedAnimation(
//       parent: controller,
//       curve: Curves.easeInOut,
//     );

//     controller.addListener(() {
//       final lat = tweenLat.evaluate(animation);
//       final lng = tweenLng.evaluate(animation);
//       setState(() {
//         _driverMarker = Marker(
//           markerId: const MarkerId("driver"),
//           position: LatLng(lat, lng),
//           icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
//         );
//       });
//     });

//     controller.forward().whenComplete(controller.dispose);
//   }

//   /// Fetch and draw polyline route
//   Future<void> _loadRoute(LatLng pickup, LatLng dest) async {
//     final url =
//         "https://maps.googleapis.com/maps/api/directions/json?origin=${pickup.latitude},${pickup.longitude}&destination=${dest.latitude},${dest.longitude}&mode=driving&key=$mapKey";

//     try {
//       final response = await http.get(Uri.parse(url));
//       final data = jsonDecode(response.body);

//       if (data['routes'].isNotEmpty) {
//         final points = data['routes'][0]['overview_polyline']['points'];
//         final decoded = _decodePolyline(points);

//         // setState(() {
//         //   _polylines.add(
//         //     Polyline(
//         //       polylineId: const PolylineId("route"),
//         //       points: decoded,
//         //       color: Colors.blue,
//         //       width: 5,
//         //     ),
//         //   );
//         // });
//         setState(() {
//           _routePoints = decoded;
//           _polylines.add(
//             Polyline(
//               polylineId: const PolylineId("route"),
//               points: decoded,
//               color: Colors.blue,
//               width: 5,
//             ),
//           );
//         });
//       }
//     } catch (e) {
//       debugPrint("Error loading route: $e");
//     }
//   }

//   /// Decode Google polyline string
//   List<LatLng> _decodePolyline(String encoded) {
//     List<LatLng> polyline = [];
//     int index = 0, len = encoded.length;
//     int lat = 0, lng = 0;

//     while (index < len) {
//       int b, shift = 0, result = 0;
//       do {
//         b = encoded.codeUnitAt(index++) - 63;
//         result |= (b & 0x1F) << shift;
//         shift += 5;
//       } while (b >= 0x20);
//       int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
//       lat += dlat;

//       shift = 0;
//       result = 0;
//       do {
//         b = encoded.codeUnitAt(index++) - 63;
//         result |= (b & 0x1F) << shift;
//         shift += 5;
//       } while (b >= 0x20);
//       int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
//       lng += dlng;

//       polyline.add(LatLng(lat / 1E5, lng / 1E5));
//     }
//     return polyline;
//   }

//   Future<void> _endRide() async {
//     if (_ended || _currentLocation == null) return;

//     final url = Uri.parse('$baseUrl/rides/${widget.rideId}/end');

//     try {
//       final response = await http.post(
//         url,
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({
//           'latitude': _currentLocation?.latitude,
//           'longitude': _currentLocation?.longitude,
//         }),
//       );

//       if (response.statusCode == 200) {
//         final responseData = jsonDecode(response.body);

//         // Assume backend returns fare in decimal-compatible format
//         final String fareString = responseData['fare'].toString();
//         final double fare = double.parse(fareString);
//         //  double fare = _computeFare(_distanceTraveledKm);

//         final db = FirebaseDatabase.instanceFor(app: passengerApp);
//         final rideRef = db.ref("rides/${widget.rideId}");

//         await rideRef.update({
//           'status': 'completed',
//           'destination/lat': _currentLocation!.latitude,
//           'destination/lng': _currentLocation!.longitude,
//           'distanceKm': double.parse(_distanceTraveledKm.toStringAsFixed(2)),
//           'fare': double.parse(fare.toStringAsFixed(2)),
//           'endedAt': ServerValue.timestamp,
//         });

//         setState(() => _ended = true);
//         _showFareSheet(fare);
//       } else {
//         throw Exception("Failed to end ride");
//       }
//     } catch (e) {
//       debugPrint("End ride error: $e");
//       if (mounted) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text("Error ending ride: $e")));
//       }
//     }
//   }

//   /// End the ride
//   // Future<void> _endRide() async {
//   //   if (_ended || _currentLocation == null) return;

//   //   try {
//   //     double fare = _computeFare(_distanceTraveledKm);

//   //     await _rideRef.child('rides/${widget.rideId}').update({
//   //       'status': 'completed',
//   //       'destination/lat': _currentLocation!.latitude,
//   //       'destination/lng': _currentLocation!.longitude,
//   //       'distanceKm': double.parse(_distanceTraveledKm.toStringAsFixed(2)),
//   //       'fare': double.parse(fare.toStringAsFixed(2)),
//   //       'endedAt': ServerValue.timestamp,
//   //     });

//   //     setState(() => _ended = true);

//   //     _showFareSheet(fare);
//   //   } catch (e) {
//   //     debugPrint("End ride error: $e");
//   //     if (mounted) {
//   //       ScaffoldMessenger.of(
//   //         context,
//   //       ).showSnackBar(SnackBar(content: Text("Error ending ride: $e")));
//   //     }
//   //   }
//   // }

//   double _computeFare(double traveledKm) => baseFare + traveledKm * perKmFare;

//   double _haversineKm(LatLng a, LatLng b) {
//     const R = 6371.0;
//     final dLat = _degToRad(b.latitude - a.latitude);
//     final dLng = _degToRad(b.longitude - a.longitude);
//     final aa =
//         math.sin(dLat / 2) * math.sin(dLat / 2) +
//         math.cos(_degToRad(a.latitude)) *
//             math.cos(_degToRad(b.latitude)) *
//             math.sin(dLng / 2) *
//             math.sin(dLng / 2);
//     return R * 2 * math.atan2(math.sqrt(aa), math.sqrt(1 - aa));
//   }

//   double _degToRad(double d) => d * math.pi / 180.0;

//   // void _showFareSheet(double fare) {
//   //   if (!mounted) return;
//   //   showModalBottomSheet(
//   //     context: context,
//   //     isDismissible: false,
//   //     enableDrag: false,
//   //     shape: const RoundedRectangleBorder(
//   //       borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
//   //     ),
//   //     builder:
//   //         (_) => Container(
//   //           padding: const EdgeInsets.all(24),
//   //           height: 240,
//   //           child: Column(
//   //             mainAxisAlignment: MainAxisAlignment.center,
//   //             children: [
//   //               const Icon(Icons.check_circle, color: Colors.green, size: 48),
//   //               const SizedBox(height: 16),
//   //               const Text(
//   //                 'Trip Completed',
//   //                 style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//   //               ),
//   //               const SizedBox(height: 8),
//   //               Text('Distance: ${_distanceTraveledKm.toStringAsFixed(2)} km'),
//   //               const SizedBox(height: 8),
//   //               Text(
//   //                 'Fare: KES ${fare.toStringAsFixed(2)}',
//   //                 style: const TextStyle(
//   //                   fontSize: 20,
//   //                   fontWeight: FontWeight.bold,
//   //                   color: Colors.red,
//   //                 ),
//   //               ),
//   //               const SizedBox(height: 20),
//   //               ElevatedButton(
//   //                 onPressed: () {
//   //                   Navigator.pop(context);
//   //                   Navigator.pop(context);
//   //                 },
//   //                 style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//   //                 child: const Text("OK"),
//   //               ),
//   //             ],
//   //           ),
//   //         ),
//   //   );
//   // }

//   void _showFareSheet(double fare) {
//     if (!mounted) return;
//     showModalBottomSheet(
//       context: context,
//       isDismissible: false,
//       enableDrag: false,
//       backgroundColor: Colors.white, // fill screen sides
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
//       ),
//       builder: (_) {
//         final screenHeight = MediaQuery.of(context).size.height;
//         return SizedBox(
//           height: screenHeight * 0.5, // half the screen
//           child: Padding(
//             padding: const EdgeInsets.all(24),
//             child: Column(
//               children: [
//                 const Icon(Icons.check_circle, color: Colors.green, size: 56),
//                 const SizedBox(height: 16),
//                 const Text(
//                   'Trip Completed',
//                   style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
//                 ),
//                 const SizedBox(height: 8),
//                 Text(
//                   'Distance: ${_distanceTraveledKm.toStringAsFixed(2)} km',
//                   style: const TextStyle(fontSize: 16),
//                 ),
//                 const SizedBox(height: 8),
//                 Text(
//                   'Fare: KES ${fare.toStringAsFixed(2)}',
//                   style: const TextStyle(
//                     fontSize: 22,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.red,
//                   ),
//                 ),
//                 const Spacer(),
//                 SizedBox(
//                   width: double.infinity,
//                   child: ElevatedButton(
//                     onPressed: () {
//                       Navigator.pop(context); // close sheet
//                       Navigator.pop(context); // close ride screen
//                     },
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.red,
//                       padding: const EdgeInsets.symmetric(vertical: 16),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ),
//                     child: const Text("OK", style: TextStyle(fontSize: 18)),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Live Ride Tracking')),
//       body: GoogleMap(
//         initialCameraPosition: CameraPosition(
//           target:
//               widget.pickup ??
//               const LatLng(-1.286389, 36.817223), // Nairobi fallback
//           zoom: 14,
//         ),
//         markers: _driverMarker != null ? {_driverMarker!} : {},
//         polylines: _polylines,
//         myLocationEnabled: true,
//         myLocationButtonEnabled: true,
//         onMapCreated: _onMapCreated,
//       ),
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
// // import 'dart:math' as math;
// // import 'package:aminidriver/Container/utils/keys.dart'; // put your Google Maps API key in keys.dart
// // import 'package:flutter/material.dart';
// // import 'package:firebase_auth/firebase_auth.dart';
// // import 'package:firebase_database/firebase_database.dart';
// // import 'package:geolocator/geolocator.dart';
// // import 'package:google_maps_flutter/google_maps_flutter.dart';
// // import 'package:audioplayers/audioplayers.dart';
// // import 'package:http/http.dart' as http;

// // const double baseFare = 100;
// // const double perKmFare = 50;

// // class LiveTrackingScreen extends StatefulWidget {
// //   final String rideId;
// //   final LatLng? pickup;
// //   final LatLng? destination;

// //   const LiveTrackingScreen({
// //     super.key,
// //     required this.rideId,
// //     this.pickup,
// //     this.destination,
// //   });

// //   @override
// //   State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
// // }

// // class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
// //   LatLng? _currentLocation;
// //   GoogleMapController? _mapController;
// //   Marker? _driverMarker;
// //   Set<Polyline> _polylines = {};
// //   double _distanceTraveledKm = 0;
// //   bool _ended = false;
// //   final DatabaseReference _rideRef = FirebaseDatabase.instance.ref();
// //   final AudioPlayer _audioPlayer = AudioPlayer();
// //   Timer? _locationTimer;

// //   @override
// //   void initState() {
// //     super.initState();

// //     if (widget.pickup != null && widget.destination != null) {
// //       _loadRoute(widget.pickup!, widget.destination!);

// //       _initTracking();
// //     }
// //   }

// //   @override
// //   void dispose() {
// //     _locationTimer?.cancel();
// //     _mapController?.dispose();
// //     super.dispose();
// //   }

// //   /// Start location tracking like Uber
// //   void _initTracking() {
// //     _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
// //       try {
// //         Position pos = await Geolocator.getCurrentPosition(
// //           desiredAccuracy: LocationAccuracy.best,
// //         );
// //         LatLng newLoc = LatLng(pos.latitude, pos.longitude);

// //         if (_currentLocation != null) {
// //           _distanceTraveledKm += _haversineKm(_currentLocation!, newLoc);
// //         }

// //         setState(() {
// //           _currentLocation = newLoc;
// //           _driverMarker = Marker(
// //             markerId: const MarkerId("driver"),
// //             position: newLoc,
// //             icon: BitmapDescriptor.defaultMarkerWithHue(
// //               BitmapDescriptor.hueBlue,
// //             ),
// //           );
// //         });

// //         // Smooth camera update
// //         _mapController?.animateCamera(CameraUpdate.newLatLng(newLoc));

// //         // Update Firebase driver location
// //         FirebaseDatabase.instance
// //             .ref('drivers/${FirebaseAuth.instance.currentUser!.uid}/location')
// //             .set({
// //               'lat': pos.latitude,
// //               'lng': pos.longitude,
// //               'timestamp': ServerValue.timestamp,
// //             });

// //         // Play alert near destination
// //         if (widget.destination != null &&
// //             _haversineKm(newLoc, widget.destination!) < 0.1) {
// //           _audioPlayer.play(AssetSource('sounds/alert.mp3'));
// //         }
// //       } catch (e) {
// //         debugPrint("Location tracking error: $e");
// //       }
// //     });
// //   }

// //   /// Fetch and draw polyline route
// //   Future<void> _loadRoute(LatLng pickup, LatLng dest) async {
// //     final url =
// //         "https://maps.googleapis.com/maps/api/directions/json?origin=${pickup.latitude},${pickup.longitude}&destination=${dest.latitude},${dest.longitude}&mode=driving&key=$mapKey";

// //     try {
// //       final response = await http.get(Uri.parse(url));
// //       final data = jsonDecode(response.body);

// //       if (data['routes'].isNotEmpty) {
// //         final points = data['routes'][0]['overview_polyline']['points'];
// //         final decoded = _decodePolyline(points);

// //         setState(() {
// //           _polylines.add(
// //             Polyline(
// //               polylineId: const PolylineId("route"),
// //               points: decoded,
// //               color: Colors.blue,
// //               width: 5,
// //             ),
// //           );
// //         });
// //       }
// //     } catch (e) {
// //       debugPrint("Error loading route: $e");
// //     }
// //   }

// //   /// Decode Google polyline string
// //   List<LatLng> _decodePolyline(String encoded) {
// //     List<LatLng> polyline = [];
// //     int index = 0, len = encoded.length;
// //     int lat = 0, lng = 0;

// //     while (index < len) {
// //       int b, shift = 0, result = 0;
// //       do {
// //         b = encoded.codeUnitAt(index++) - 63;
// //         result |= (b & 0x1F) << shift;
// //         shift += 5;
// //       } while (b >= 0x20);
// //       int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
// //       lat += dlat;

// //       shift = 0;
// //       result = 0;
// //       do {
// //         b = encoded.codeUnitAt(index++) - 63;
// //         result |= (b & 0x1F) << shift;
// //         shift += 5;
// //       } while (b >= 0x20);
// //       int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
// //       lng += dlng;

// //       polyline.add(LatLng(lat / 1E5, lng / 1E5));
// //     }
// //     return polyline;
// //   }

// //   /// End the ride
// //   Future<void> _endRide() async {
// //     if (_ended || _currentLocation == null) return;

// //     try {
// //       double fare = _computeFare(_distanceTraveledKm);

// //       await _rideRef.child('rides/${widget.rideId}').update({
// //         'status': 'completed',
// //         'destination/lat': _currentLocation!.latitude,
// //         'destination/lng': _currentLocation!.longitude,
// //         'distanceKm': double.parse(_distanceTraveledKm.toStringAsFixed(2)),
// //         'fare': double.parse(fare.toStringAsFixed(2)),
// //         'endedAt': ServerValue.timestamp,
// //       });

// //       setState(() => _ended = true);

// //       _showFareSheet(fare);
// //     } catch (e) {
// //       debugPrint("End ride error: $e");
// //       ScaffoldMessenger.of(
// //         context,
// //       ).showSnackBar(SnackBar(content: Text("Error ending ride: $e")));
// //     }
// //   }

// //   double _computeFare(double traveledKm) => baseFare + traveledKm * perKmFare;

// //   double _haversineKm(LatLng a, LatLng b) {
// //     const R = 6371.0;
// //     final dLat = _degToRad(b.latitude - a.latitude);
// //     final dLng = _degToRad(b.longitude - a.longitude);
// //     final aa =
// //         math.sin(dLat / 2) * math.sin(dLat / 2) +
// //         math.cos(_degToRad(a.latitude)) *
// //             math.cos(_degToRad(b.latitude)) *
// //             math.sin(dLng / 2) *
// //             math.sin(dLng / 2);
// //     return R * 2 * math.atan2(math.sqrt(aa), math.sqrt(1 - aa));
// //   }

// //   double _degToRad(double d) => d * math.pi / 180.0;

// //   void _showFareSheet(double fare) {
// //     showModalBottomSheet(
// //       context: context,
// //       isDismissible: false,
// //       enableDrag: false,
// //       shape: const RoundedRectangleBorder(
// //         borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
// //       ),
// //       builder:
// //           (_) => Container(
// //             padding: const EdgeInsets.all(24),
// //             height: 240,
// //             child: Column(
// //               mainAxisAlignment: MainAxisAlignment.center,
// //               children: [
// //                 const Icon(Icons.check_circle, color: Colors.green, size: 48),
// //                 const SizedBox(height: 16),
// //                 const Text(
// //                   'Trip Completed',
// //                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
// //                 ),
// //                 const SizedBox(height: 8),
// //                 Text('Distance: ${_distanceTraveledKm.toStringAsFixed(2)} km'),
// //                 const SizedBox(height: 8),
// //                 Text(
// //                   'Fare: KES ${fare.toStringAsFixed(2)}',
// //                   style: const TextStyle(
// //                     fontSize: 20,
// //                     fontWeight: FontWeight.bold,
// //                     color: Colors.red,
// //                   ),
// //                 ),
// //                 const SizedBox(height: 20),
// //                 ElevatedButton(
// //                   onPressed: () {
// //                     Navigator.pop(context);
// //                     Navigator.pop(context);
// //                   },
// //                   style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
// //                   child: const Text("OK"),
// //                 ),
// //               ],
// //             ),
// //           ),
// //     );
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(title: const Text('Live Ride Tracking')),
// //       body:
// //           _currentLocation == null
// //               ? const Center(child: CircularProgressIndicator())
// //               : GoogleMap(
// //                 initialCameraPosition: CameraPosition(
// //                   target: _currentLocation!,
// //                   zoom: 16,
// //                 ),
// //                 markers: _driverMarker != null ? {_driverMarker!} : {},
// //                 polylines: _polylines,
// //                 myLocationEnabled: true,
// //                 myLocationButtonEnabled: true,
// //                 onMapCreated: (c) => _mapController = c,
// //               ),
// //       bottomNavigationBar: Padding(
// //         padding: const EdgeInsets.all(16),
// //         child: ElevatedButton(
// //           onPressed: _endRide,
// //           style: ElevatedButton.styleFrom(
// //             backgroundColor: Colors.red,
// //             padding: const EdgeInsets.symmetric(vertical: 16),
// //           ),
// //           child: const Text("End Ride"),
// //         ),
// //       ),
// //     );
// //   }
// // }
// // // import 'dart:async';
// // // import 'dart:convert';
// // // import 'dart:math' as math;
// // // import 'package:aminidriver/Container/utils/keys.dart';
// // // import 'package:flutter/material.dart';
// // // import 'package:firebase_auth/firebase_auth.dart';
// // // import 'package:firebase_database/firebase_database.dart';
// // // import 'package:geolocator/geolocator.dart';
// // // import 'package:google_maps_flutter/google_maps_flutter.dart';
// // // import 'package:audioplayers/audioplayers.dart';
// // // import 'package:http/http.dart' as http;

// // // const double baseFare = 100;
// // // const double perKmFare = 50;

// // // class LiveTrackingScreen extends StatefulWidget {
// // //   final String rideId;
// // //   final LatLng? pickup;
// // //   final LatLng? destination;

// // //   const LiveTrackingScreen({
// // //     super.key,
// // //     required this.rideId,
// // //     this.pickup,
// // //     this.destination,
// // //   });

// // //   @override
// // //   State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
// // // }

// // // class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
// // //   LatLng? _currentLocation;
// // //   GoogleMapController? _mapController;
// // //   Marker? _driverMarker;
// // //   final Set<Polyline> _polylines = {};
// // //   double _distanceTraveledKm = 0;
// // //   bool _ended = false;
// // //   final DatabaseReference _rideRef = FirebaseDatabase.instance.ref();
// // //   final AudioPlayer _audioPlayer = AudioPlayer();
// // //   StreamSubscription<Position>? _positionSub;

// // //   @override
// // //   void initState() {
// // //     super.initState();
// // //     _startLocationTracking();
// // //   }

// // //   @override
// // //   void dispose() {
// // //     _positionSub?.cancel();
// // //     _mapController?.dispose();
// // //     super.dispose();
// // //   }

// // //   void _startLocationTracking() {
// // //     const settings = LocationSettings(
// // //       accuracy: LocationAccuracy.high,
// // //       distanceFilter: 10, // only update if moved >10m
// // //     );

// // //     _positionSub = Geolocator.getPositionStream(locationSettings: settings)
// // //         .listen((Position pos) async {
// // //       final newLoc = LatLng(pos.latitude, pos.longitude);

// // //       if (_currentLocation != null) {
// // //         _distanceTraveledKm += _haversineKm(_currentLocation!, newLoc);
// // //       }

// // //       setState(() {
// // //         _currentLocation = newLoc;
// // //         _driverMarker = Marker(
// // //           markerId: const MarkerId("driver"),
// // //           position: newLoc,
// // //           icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
// // //         );
// // //       });

// // //       // update DB (only every ~5s to save bandwidth)
// // //       FirebaseDatabase.instance
// // //           .ref('drivers/${FirebaseAuth.instance.currentUser!.uid}/location')
// // //           .set({
// // //         'lat': pos.latitude,
// // //         'lng': pos.longitude,
// // //         'timestamp': ServerValue.timestamp,
// // //       });

// // //       // Animate smoothly (like Uber)
// // //       _mapController?.animateCamera(
// // //         CameraUpdate.newLatLng(newLoc),
// // //       );

// // //       // Play alert near destination
// // //       if (widget.destination != null &&
// // //           _haversineKm(newLoc, widget.destination!) < 0.15) {
// // //         _audioPlayer.play(AssetSource('sounds/alert.mp3'));
// // //       }
// // //     });
// // //   }

// // //   Future<void> _endRide() async {
// // //     if (_ended || _currentLocation == null) return;

// // //     final url = Uri.parse('$baseUrl/rides/${widget.rideId}/end');

// // //     try {
// // //       final response = await http.post(
// // //         url,
// // //         headers: {'Content-Type': 'application/json'},
// // //         body: jsonEncode({
// // //           'latitude': _currentLocation?.latitude,
// // //           'longitude': _currentLocation?.longitude,
// // //         }),
// // //       );

// // //       if (response.statusCode == 200) {
// // //         double fare = _computeFare(_distanceTraveledKm);

// // //         await _rideRef.child('rides/${widget.rideId}').update({
// // //           'status': 'completed',
// // //           'destination/lat': _currentLocation!.latitude,
// // //           'destination/lng': _currentLocation!.longitude,
// // //           'distanceKm': double.parse(_distanceTraveledKm.toStringAsFixed(2)),
// // //           'fare': double.parse(fare.toStringAsFixed(2)),
// // //           'endedAt': ServerValue.timestamp,
// // //         });

// // //         setState(() => _ended = true);
// // //         _showFareSheet(fare);
// // //       } else {
// // //         throw Exception("Failed to end ride");
// // //       }
// // //     } catch (e) {
// // //       debugPrint("End ride error: $e");
// // //       if (mounted) {
// // //         ScaffoldMessenger.of(context).showSnackBar(
// // //           SnackBar(content: Text("Error ending ride: $e")),
// // //         );
// // //       }
// // //     }
// // //   }

// // //   double _computeFare(double traveledKm) => baseFare + traveledKm * perKmFare;

// // //   double _haversineKm(LatLng a, LatLng b) {
// // //     const R = 6371.0;
// // //     final dLat = _degToRad(b.latitude - a.latitude);
// // //     final dLng = _degToRad(b.longitude - a.longitude);
// // //     final aa = math.sin(dLat / 2) * math.sin(dLat / 2) +
// // //         math.cos(_degToRad(a.latitude)) *
// // //             math.cos(_degToRad(b.latitude)) *
// // //             math.sin(dLng / 2) *
// // //             math.sin(dLng / 2);
// // //     return R * 2 * math.atan2(math.sqrt(aa), math.sqrt(1 - aa));
// // //   }

// // //   double _degToRad(double d) => d * math.pi / 180.0;

// // //   void _showFareSheet(double fare) {
// // //     if (!mounted) return;
// // //     showModalBottomSheet(
// // //       context: context,
// // //       isDismissible: false,
// // //       enableDrag: false,
// // //       shape: const RoundedRectangleBorder(
// // //         borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
// // //       ),
// // //       builder: (_) => Container(
// // //         padding: const EdgeInsets.all(24),
// // //         height: 220,
// // //         child: Column(
// // //           mainAxisAlignment: MainAxisAlignment.center,
// // //           children: [
// // //             const Icon(Icons.check_circle, color: Colors.green, size: 48),
// // //             const SizedBox(height: 16),
// // //             const Text(
// // //               'Trip Completed',
// // //               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
// // //             ),
// // //             const SizedBox(height: 8),
// // //             Text(
// // //               'Distance: ${_distanceTraveledKm.toStringAsFixed(2)} km',
// // //               style: const TextStyle(fontSize: 16),
// // //             ),
// // //             const SizedBox(height: 8),
// // //             Text(
// // //               'Amount: KES ${fare.toStringAsFixed(2)}',
// // //               style: const TextStyle(
// // //                 fontSize: 20,
// // //                 fontWeight: FontWeight.bold,
// // //                 color: Colors.red,
// // //               ),
// // //             ),
// // //             const SizedBox(height: 16),
// // //             ElevatedButton(
// // //               onPressed: () {
// // //                 Navigator.pop(context); // close bottom sheet
// // //                 Navigator.pop(context); // back to main
// // //               },
// // //               style: ElevatedButton.styleFrom(
// // //                 backgroundColor: Colors.red,
// // //                 padding:
// // //                     const EdgeInsets.symmetric(vertical: 12, horizontal: 32),
// // //               ),
// // //               child: const Text('Close', style: TextStyle(fontSize: 16)),
// // //             ),
// // //           ],
// // //         ),
// // //       ),
// // //     );
// // //   }

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     return Scaffold(
// // //       appBar: AppBar(title: const Text('Live Ride Tracking'), centerTitle: true),
// // //       body: _currentLocation == null
// // //           ? const Center(child: CircularProgressIndicator())
// // //           : GoogleMap(
// // //               initialCameraPosition: CameraPosition(
// // //                 target: _currentLocation!,
// // //                 zoom: 16,
// // //               ),
// // //               markers: _driverMarker != null ? {_driverMarker!} : {},
// // //               polylines: _polylines,
// // //               myLocationEnabled: true,
// // //               myLocationButtonEnabled: true,
// // //               onMapCreated: (c) => _mapController = c,
// // //             ),
// // //       bottomNavigationBar: Padding(
// // //         padding: const EdgeInsets.all(16),
// // //         child: ElevatedButton(
// // //           onPressed: _endRide,
// // //           style: ElevatedButton.styleFrom(
// // //             backgroundColor: Colors.red,
// // //             padding: const EdgeInsets.symmetric(vertical: 16),
// // //           ),
// // //           child: const Text("End Ride"),
// // //         ),
// // //       ),
// // //     );
// // //   }
// // // }
// // // // import 'dart:async';
// // // // import 'dart:convert';
// // // // import 'dart:math' as math;
// // // // import 'package:aminidriver/Container/utils/keys.dart';
// // // // import 'package:flutter/material.dart';
// // // // import 'package:firebase_auth/firebase_auth.dart';
// // // // import 'package:firebase_database/firebase_database.dart';
// // // // import 'package:geolocator/geolocator.dart';
// // // // import 'package:google_maps_flutter/google_maps_flutter.dart';
// // // // import 'package:audioplayers/audioplayers.dart';
// // // // import 'package:http/http.dart' as http;

// // // // const double baseFare = 100;
// // // // const double perKmFare = 50;

// // // // class LiveTrackingScreen extends StatefulWidget {
// // // //   final String rideId;
// // // //   final LatLng? pickup;
// // // //   final LatLng? destination;

// // // //   const LiveTrackingScreen({
// // // //     super.key,
// // // //     required this.rideId,
// // // //     this.pickup,
// // // //     this.destination,
// // // //   });

// // // //   @override
// // // //   State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
// // // // }

// // // // class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
// // // //   LatLng? _currentLocation;
// // // //   GoogleMapController? _mapController;
// // // //   Marker? _driverMarker;
// // // //   Set<Polyline> _polylines = {};
// // // //   double _distanceTraveledKm = 0;
// // // //   bool _ended = false;
// // // //   final DatabaseReference _rideRef = FirebaseDatabase.instance.ref();
// // // //   final AudioPlayer _audioPlayer = AudioPlayer();
// // // //   Timer? _locationTimer;

// // // //   @override
// // // //   void initState() {
// // // //     super.initState();
// // // //     _startLocationTracking();
// // // //   }

// // // //   @override
// // // //   void dispose() {
// // // //     _locationTimer?.cancel();
// // // //     _mapController?.dispose();
// // // //     super.dispose();
// // // //   }

// // // //   Future<void> checkOngoingTrip(BuildContext context) async {
// // // //     final userId = FirebaseAuth.instance.currentUser!.uid;
// // // //     final rideSnapshot =
// // // //         await FirebaseDatabase.instance
// // // //             .ref('rides')
// // // //             .orderByChild('driverId')
// // // //             .equalTo(userId)
// // // //             .get();

// // // //     if (rideSnapshot.exists) {
// // // //       final rides = rideSnapshot.value as Map<dynamic, dynamic>;

// // // //       MapEntry<dynamic, dynamic>? ongoingRide;
// // // //       for (final entry in rides.entries) {
// // // //         if (entry.value['status'] == 'in-progress') {
// // // //           ongoingRide = entry;
// // // //           break;
// // // //         }
// // // //       }

// // // //       if (ongoingRide != null) {
// // // //         final rideId = ongoingRide.key;
// // // //         final pickupLat = ongoingRide.value['pickup']['lat'];
// // // //         final pickupLng = ongoingRide.value['pickup']['lng'];
// // // //         final destLat = ongoingRide.value['destination']['lat'];
// // // //         final destLng = ongoingRide.value['destination']['lng'];

// // // //         Navigator.pushReplacement(
// // // //           context,
// // // //           MaterialPageRoute(
// // // //             builder:
// // // //                 (_) => LiveTrackingScreen(
// // // //                   rideId: rideId,
// // // //                   pickup: LatLng(pickupLat, pickupLng),
// // // //                   destination: LatLng(destLat, destLng),
// // // //                 ),
// // // //           ),
// // // //         );
// // // //       }
// // // //     }
// // // //   }

// // // //   void _startLocationTracking() {
// // // //     _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
// // // //       Position pos = await Geolocator.getCurrentPosition();
// // // //       LatLng newLoc = LatLng(pos.latitude, pos.longitude);

// // // //       // Track distance
// // // //       if (_currentLocation != null) {
// // // //         _distanceTraveledKm += _haversineKm(_currentLocation!, newLoc);
// // // //       }

// // // //       setState(() {
// // // //         _currentLocation = newLoc;
// // // //         _driverMarker = Marker(
// // // //           markerId: const MarkerId("driver"),
// // // //           position: newLoc,
// // // //           icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
// // // //         );
// // // //       });

// // // //       // Animate camera to new location
// // // //       _mapController?.animateCamera(CameraUpdate.newLatLng(newLoc));

// // // //       // Update Firebase Realtime DB
// // // //       FirebaseDatabase.instance
// // // //           .ref('drivers/${FirebaseAuth.instance.currentUser!.uid}/location')
// // // //           .set({
// // // //             'lat': pos.latitude,
// // // //             'lng': pos.longitude,
// // // //             'timestamp': ServerValue.timestamp,
// // // //           });
// // // //       if (widget.destination != null &&
// // // //           _haversineKm(newLoc, widget.destination!) < 0.1) {
// // // //         _audioPlayer.play(AssetSource('sounds/alert.mp3'));
// // // //       }
// // // //       // // Play sound when near destination
// // // //       // if (_haversineKm(newLoc, widget.destination!) < 0.1) {
// // // //       //   _audioPlayer.play(AssetSource('sounds/alert.mp3'));
// // // //       // }
// // // //     });
// // // //   }

// // // //   Future<void> _endRide() async {
// // // //     if (_ended || _currentLocation == null) return;
// // // //     final user = FirebaseAuth.instance.currentUser;
// // // //     final idToken = await user?.getIdToken();

// // // //     final url = Uri.parse('$baseUrl/rides/${widget.rideId}/end');

// // // //     try {
// // // //       final response = await http.post(
// // // //         url,
// // // //         headers: {
// // // //           'Content-Type': 'application/json',
// // // //           //'Authorization': 'Bearer $idToken',
// // // //         },
// // // //         body: jsonEncode({
// // // //           'latitude': _currentLocation?.latitude,
// // // //           'longitude': _currentLocation?.longitude,
// // // //         }),
// // // //       );

// // // //       if (response.statusCode == 200) {
// // // //         // final rideRef = FirebaseDatabase.instance.ref("rides/${widget.rideId}");
// // // //         // await rideRef.update({
// // // //         //   "status": "completed",
// // // //         //   "destination/lat": _currentLocation?.latitude,
// // // //         //   "destination/lng": _currentLocation?.longitude,
// // // //         //   "endTime": DateTime.now().toIso8601String(),

// // // //         // });
// // // //         double fare = _computeFare(_distanceTraveledKm);

// // // //         await _rideRef.child('rides/${widget.rideId}').update({
// // // //           'status': 'completed',
// // // //           'destination/lat': _currentLocation!.latitude,
// // // //           'destination/lng': _currentLocation!.longitude,
// // // //           'distanceKm': double.parse(_distanceTraveledKm.toStringAsFixed(2)),
// // // //           'fare': double.parse(fare.toStringAsFixed(2)),
// // // //           'endedAt': ServerValue.timestamp,
// // // //         });
// // // //         setState(() => _ended = true);
// // // //         //_showFareDialog(fare);
// // // //         _showFareSheet(fare);

// // // //         ScaffoldMessenger.of(context).showSnackBar(
// // // //           const SnackBar(content: Text("Ride ended successfully")),
// // // //         );
// // // //         Navigator.pop(context); // go back after ending ride
// // // //       } else {
// // // //         throw Exception("Failed to end ride");
// // // //       }
// // // //     } catch (e) {
// // // //       debugPrint("End ride error: $e");
// // // //       ScaffoldMessenger.of(
// // // //         context,
// // // //       ).showSnackBar(SnackBar(content: Text("Error ending ride: $e")));
// // // //     }
// // // //   }

// // // //   // Future<void> _endRide() async {
// // // //   //   if (_ended || _currentLocation == null) return;

// // // //   //   double fare = _computeFare(_distanceTraveledKm);

// // // //   //   // Update Firebase ride node
// // // //   //   await _rideRef.child('rides/${widget.rideId}').update({
// // // //   //     'status': 'completed',
// // // //   //     'destination/lat': _currentLocation!.latitude,
// // // //   //     'destination/lng': _currentLocation!.longitude,
// // // //   //     'distanceKm': double.parse(_distanceTraveledKm.toStringAsFixed(2)),
// // // //   //     'fare': double.parse(fare.toStringAsFixed(2)),
// // // //   //     'endedAt': ServerValue.timestamp,
// // // //   //   });

// // // //   //   setState(() => _ended = true);
// // // //   //   //_showFareDialog(fare);
// // // //   //   _showFareSheet(fare);
// // // //   // }

// // // //   double _computeFare(double traveledKm) => baseFare + traveledKm * perKmFare;

// // // //   double _haversineKm(LatLng a, LatLng b) {
// // // //     const R = 6371.0;
// // // //     final dLat = _degToRad(b.latitude - a.latitude);
// // // //     final dLng = _degToRad(b.longitude - a.longitude);
// // // //     final s1 = math.sin(dLat / 2);
// // // //     final s2 = math.sin(dLng / 2);
// // // //     final aa =
// // // //         s1 * s1 +
// // // //         math.cos(_degToRad(a.latitude)) *
// // // //             math.cos(_degToRad(b.latitude)) *
// // // //             s2 *
// // // //             s2;
// // // //     return R * 2 * math.atan2(math.sqrt(aa), math.sqrt(1 - aa));
// // // //   }

// // // //   double _degToRad(double d) => d * math.pi / 180.0;

// // // //   void _showFareDialog(double fare) {
// // // //     showDialog(
// // // //       context: context,
// // // //       builder:
// // // //           (_) => AlertDialog(
// // // //             title: const Text('Trip Completed'),
// // // //             content: Text(
// // // //               'Distance: ${_distanceTraveledKm.toStringAsFixed(2)} km\n'
// // // //               'Amount to pay: KES ${fare.toStringAsFixed(2)}',
// // // //             ),
// // // //             actions: [
// // // //               TextButton(
// // // //                 onPressed: () {
// // // //                   Navigator.pop(context);
// // // //                   Navigator.pop(context); // Back to main
// // // //                 },
// // // //                 child: const Text('Close'),
// // // //               ),
// // // //             ],
// // // //           ),
// // // //     );
// // // //   }

// // // //   void _showFareSheet(double fare) {
// // // //     showModalBottomSheet(
// // // //       context: context,
// // // //       isDismissible: false,
// // // //       enableDrag: false,
// // // //       shape: const RoundedRectangleBorder(
// // // //         borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
// // // //       ),
// // // //       builder:
// // // //           (_) => Container(
// // // //             padding: const EdgeInsets.all(24),
// // // //             height: 220,
// // // //             decoration: const BoxDecoration(
// // // //               color: Colors.white,
// // // //               borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
// // // //             ),
// // // //             child: Column(
// // // //               mainAxisAlignment: MainAxisAlignment.center,
// // // //               children: [
// // // //                 const Icon(Icons.check_circle, color: Colors.green, size: 48),
// // // //                 const SizedBox(height: 16),
// // // //                 const Text(
// // // //                   'Trip Completed',
// // // //                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
// // // //                 ),
// // // //                 const SizedBox(height: 8),
// // // //                 Text(
// // // //                   'Distance: ${_distanceTraveledKm.toStringAsFixed(2)} km',
// // // //                   style: const TextStyle(fontSize: 16),
// // // //                 ),
// // // //                 const SizedBox(height: 8),
// // // //                 Text(
// // // //                   'Amount to Pay: KES ${fare.toStringAsFixed(2)}',
// // // //                   style: const TextStyle(
// // // //                     fontSize: 20,
// // // //                     fontWeight: FontWeight.bold,
// // // //                     color: Colors.red,
// // // //                   ),
// // // //                 ),
// // // //                 const SizedBox(height: 16),
// // // //                 ElevatedButton(
// // // //                   onPressed: () {
// // // //                     Navigator.pop(context); // Close bottom sheet
// // // //                     Navigator.pop(context); // Back to main screen
// // // //                   },
// // // //                   style: ElevatedButton.styleFrom(
// // // //                     backgroundColor: Colors.red,
// // // //                     padding: const EdgeInsets.symmetric(
// // // //                       vertical: 12,
// // // //                       horizontal: 32,
// // // //                     ),
// // // //                     shape: RoundedRectangleBorder(
// // // //                       borderRadius: BorderRadius.circular(8),
// // // //                     ),
// // // //                   ),
// // // //                   child: const Text('Close', style: TextStyle(fontSize: 16)),
// // // //                 ),
// // // //               ],
// // // //             ),
// // // //           ),
// // // //     );
// // // //   }

// // // //   @override
// // // //   Widget build(BuildContext context) {
// // // //     return Scaffold(
// // // //       appBar: AppBar(
// // // //         title: const Text('Live Ride Tracking'),
// // // //         centerTitle: true,
// // // //       ),
// // // //       body:
// // // //           _currentLocation == null
// // // //               ? const Center(child: CircularProgressIndicator())
// // // //               : GoogleMap(
// // // //                 initialCameraPosition: CameraPosition(
// // // //                   target: _currentLocation!,
// // // //                   zoom: 16,
// // // //                 ),
// // // //                 markers: _driverMarker != null ? {_driverMarker!} : {},
// // // //                 polylines: _polylines,
// // // //                 myLocationEnabled: true,
// // // //                 myLocationButtonEnabled: true,
// // // //                 onMapCreated: (c) => _mapController = c,
// // // //               ),
// // // //       bottomNavigationBar: Padding(
// // // //         padding: const EdgeInsets.all(16),
// // // //         child: ElevatedButton(
// // // //           onPressed: _endRide,
// // // //           style: ElevatedButton.styleFrom(
// // // //             backgroundColor: Colors.red,
// // // //             padding: const EdgeInsets.symmetric(vertical: 16),
// // // //           ),
// // // //           child: const Text("End Ride"),
// // // //         ),
// // // //       ),
// // // //     );
// // // //   }
// // // // }

// // // // // import 'dart:async';
// // // // // import 'dart:convert';

// // // // // import 'package:aminidriver/Container/utils/api_constant.dart';
// // // // // import 'package:aminidriver/Container/utils/keys.dart';
// // // // // import 'package:firebase_auth/firebase_auth.dart';
// // // // // import 'package:firebase_database/firebase_database.dart';
// // // // // import 'package:flutter/material.dart';
// // // // // import 'package:geolocator/geolocator.dart';
// // // // // import 'package:google_maps_flutter/google_maps_flutter.dart';
// // // // // import 'package:http/http.dart' as http;

// // // // // class LiveTrackingScreen extends StatefulWidget {
// // // // //   final String rideId;

// // // // //   const LiveTrackingScreen({required this.rideId, Key? key}) : super(key: key);

// // // // //   @override
// // // // //   _LiveTrackingScreenState createState() => _LiveTrackingScreenState();
// // // // // }

// // // // // class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
// // // // //   LatLng? _currentLocation;
// // // // //   Timer? _locationTimer;
// // // // //   GoogleMapController? _mapController;
// // // // //   Marker? _driverMarker;

// // // // //   @override
// // // // //   void initState() {
// // // // //     super.initState();
// // // // //     _startLocationTracking();
// // // // //   }

// // // // //   Future<void> _endRide() async {
// // // // //     final user = FirebaseAuth.instance.currentUser;
// // // // //     final idToken = await user?.getIdToken();

// // // // //     final url = Uri.parse('$baseUrl/rides/${widget.rideId}/end');

// // // // //     try {
// // // // //       final response = await http.put(
// // // // //         url,
// // // // //         headers: {
// // // // //           'Content-Type': 'application/json',
// // // // //           'Authorization': 'Bearer $idToken',
// // // // //         },
// // // // //         body: jsonEncode({
// // // // //           'latitude': _currentLocation?.latitude,
// // // // //           'longitude': _currentLocation?.longitude,
// // // // //         }),
// // // // //       );

// // // // //       if (response.statusCode == 200) {
// // // // //         final rideRef = FirebaseDatabase.instance.ref("rides/${widget.rideId}");
// // // // //         await rideRef.update({
// // // // //           "status": "completed",
// // // // //           "destination/lat": _currentLocation?.latitude,
// // // // //           "destination/lng": _currentLocation?.longitude,
// // // // //           "endTime": DateTime.now().toIso8601String(),

// // // // //         });

// // // // //         ScaffoldMessenger.of(context).showSnackBar(
// // // // //           const SnackBar(content: Text("Ride ended successfully")),
// // // // //         );
// // // // //         Navigator.pop(context); // go back after ending ride
// // // // //       } else {
// // // // //         throw Exception("Failed to end ride");
// // // // //       }
// // // // //     } catch (e) {
// // // // //       debugPrint("End ride error: $e");
// // // // //       ScaffoldMessenger.of(
// // // // //         context,
// // // // //       ).showSnackBar(SnackBar(content: Text("Error ending ride: $e")));
// // // // //     }
// // // // //   }

// // // // //   void _startLocationTracking() {
// // // // //     _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
// // // // //       Position pos = await Geolocator.getCurrentPosition();
// // // // //       LatLng newLocation = LatLng(pos.latitude, pos.longitude);

// // // // //       setState(() {
// // // // //         _currentLocation = newLocation;
// // // // //         _driverMarker = Marker(
// // // // //           markerId: const MarkerId("driver"),
// // // // //           position: newLocation,
// // // // //           icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
// // // // //         );
// // // // //       });

// // // // //       // Animate camera to new location
// // // // //       if (_mapController != null) {
// // // // //         _mapController!.animateCamera(CameraUpdate.newLatLng(newLocation));
// // // // //       }

// // // // //       // Update Firebase realtime DB
// // // // //       FirebaseDatabase.instance
// // // // //           .ref('drivers/${FirebaseAuth.instance.currentUser!.uid}/location')
// // // // //           .set({
// // // // //             'latitude': pos.latitude,
// // // // //             'longitude': pos.longitude,
// // // // //             'timestamp': ServerValue.timestamp,
// // // // //           });
// // // // //     });
// // // // //   }

// // // // //   @override
// // // // //   void dispose() {
// // // // //     _locationTimer?.cancel();
// // // // //     _mapController?.dispose();
// // // // //     super.dispose();
// // // // //   }

// // // // //   @override
// // // // //   Widget build(BuildContext context) {
// // // // //     return Scaffold(
// // // // //       backgroundColor: Colors.white,
// // // // //       appBar: AppBar(
// // // // //         title: const Text("Live Ride Tracking"),
// // // // //         centerTitle: true,
// // // // //         backgroundColor: Colors.white,
// // // // //         elevation: 0,
// // // // //         foregroundColor: Colors.black,
// // // // //       ),
// // // // //       body:
// // // // //           _currentLocation == null
// // // // //               ? const Center(child: CircularProgressIndicator())
// // // // //               : GoogleMap(
// // // // //                 initialCameraPosition: CameraPosition(
// // // // //                   target: _currentLocation!,
// // // // //                   zoom: 16,
// // // // //                 ),
// // // // //                 myLocationEnabled: true,
// // // // //                 myLocationButtonEnabled: true,
// // // // //                 markers: _driverMarker != null ? {_driverMarker!} : {},
// // // // //                 onMapCreated: (controller) => _mapController = controller,
// // // // //               ),
// // // // //       bottomNavigationBar: Padding(
// // // // //         padding: const EdgeInsets.all(16),
// // // // //         child: ElevatedButton(
// // // // //           onPressed: _endRide,
// // // // //           style: ElevatedButton.styleFrom(
// // // // //             backgroundColor: Colors.red,
// // // // //             padding: const EdgeInsets.symmetric(vertical: 16),
// // // // //           ),
// // // // //           child: const Text("End Ride"),
// // // // //         ),
// // // // //       ),
// // // // //     );
// // // // //   }
// // // // // }

// // // // // // import 'dart:async';
// // // // // // import 'dart:convert';

// // // // // // import 'package:aminidriver/Container/utils/api_constant.dart';
// // // // // // import 'package:firebase_auth/firebase_auth.dart';
// // // // // // import 'package:firebase_database/firebase_database.dart';
// // // // // // import 'package:flutter/material.dart';
// // // // // // import 'package:flutter/widgets.dart';
// // // // // // import 'package:flutter_map/flutter_map.dart';
// // // // // // import 'package:geolocator/geolocator.dart';
// // // // // // import 'package:http/http.dart' as http;
// // // // // // import 'package:latlong2/latlong.dart';

// // // // // // class LiveTrackingScreen extends StatefulWidget {
// // // // // //   final String rideId;

// // // // // //   const LiveTrackingScreen({required this.rideId});

// // // // // //   @override
// // // // // //   _LiveTrackingScreenState createState() => _LiveTrackingScreenState();
// // // // // // }

// // // // // // class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
// // // // // //   LatLng? _currentLocation;
// // // // // //   Timer? _locationTimer;

// // // // // //   @override
// // // // // //   void initState() {
// // // // // //     super.initState();
// // // // // //     _startLocationTracking();
// // // // // //   }

// // // // // //   Future<void> _endRide() async {
// // // // // //     final user = FirebaseAuth.instance.currentUser;
// // // // // //     final idToken = await user?.getIdToken();

// // // // // //     final url = Uri.parse('$baseUrl/rides/${widget.rideId}/end');

// // // // // //     try {
// // // // // //       final response = await http.put(
// // // // // //         url,
// // // // // //         headers: {
// // // // // //           'Content-Type': 'application/json',
// // // // // //           //'Authorization': 'Bearer $idToken',
// // // // // //         },
// // // // // //         body: jsonEncode({
// // // // // //           'latitude': _currentLocation!.latitude,
// // // // // //           'longitude': _currentLocation!.longitude,
// // // // // //         }),
// // // // // //       );

// // // // // //       if (response.statusCode == 200) {
// // // // // //         ScaffoldMessenger.of(context).showSnackBar(
// // // // // //           const SnackBar(content: Text("Ride started successfully")),
// // // // // //         );

// // // // // //         // Optional: Navigate to live tracking screen or update UI state
// // // // // //       } else {
// // // // // //         throw Exception("Failed to start ride");
// // // // // //       }
// // // // // //     } catch (e) {
// // // // // //       debugPrint("Start ride error: $e");
// // // // // //       ScaffoldMessenger.of(
// // // // // //         context,
// // // // // //       ).showSnackBar(SnackBar(content: Text("Error starting ride: $e")));
// // // // // //     }
// // // // // //   }

// // // // // //   void _startLocationTracking() {
// // // // // //     _locationTimer = Timer.periodic(Duration(seconds: 5), (_) async {
// // // // // //       Position pos = await Geolocator.getCurrentPosition();
// // // // // //       setState(() {
// // // // // //         _currentLocation = LatLng(pos.latitude, pos.longitude);
// // // // // //       });

// // // // // //       // Optionally send location to backend or Firebase
// // // // // //       FirebaseDatabase.instance
// // // // // //           .ref('drivers/${FirebaseAuth.instance.currentUser!.uid}/location')
// // // // // //           .set({
// // // // // //             'latitude': pos.latitude,
// // // // // //             'longitude': pos.longitude,
// // // // // //             'timestamp': ServerValue.timestamp,
// // // // // //           });
// // // // // //     });
// // // // // //   }

// // // // // //   @override
// // // // // //   void dispose() {
// // // // // //     _locationTimer?.cancel();
// // // // // //     super.dispose();
// // // // // //   }

// // // // // //   @override
// // // // // //   Widget build(BuildContext context) {
// // // // // //     return Scaffold(
// // // // // //       backgroundColor: Colors.white,
// // // // // //       appBar: AppBar(
// // // // // //         title: Text("Live Ride Tracking"),
// // // // // //         centerTitle: true,
// // // // // //         backgroundColor: Colors.white,
// // // // // //         elevation: 0,
// // // // // //         foregroundColor: Colors.black,
// // // // // //       ),
// // // // // //       body:
// // // // // //           _currentLocation == null
// // // // // //               ? Center(child: CircularProgressIndicator())
// // // // // //               : FlutterMap(
// // // // // //                 options: MapOptions(center: _currentLocation, zoom: 16),
// // // // // //                 children: [
// // // // // //                   TileLayer(
// // // // // //                     urlTemplate:
// // // // // //                         "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
// // // // // //                   ),
// // // // // //                   MarkerLayer(
// // // // // //                     markers: [
// // // // // //                       Marker(
// // // // // //                         point: _currentLocation!,
// // // // // //                         width: 40,
// // // // // //                         height: 40,
// // // // // //                         builder:
// // // // // //                             (context) =>
// // // // // //                                 Icon(Icons.local_taxi, color: Colors.blue),
// // // // // //                       ),
// // // // // //                     ],
// // // // // //                   ),
// // // // // //                 ],
// // // // // //               ),
// // // // // //       bottomNavigationBar: Padding(
// // // // // //         padding: EdgeInsets.all(16),
// // // // // //         child: ElevatedButton(
// // // // // //           onPressed: () {
// // // // // //             // Trigger end ride API
// // // // // //           },
// // // // // //           child: Text("End Ride"),
// // // // // //         ),
// // // // // //       ),
// // // // // //     );
// // // // // //   }
// // // // // // }
