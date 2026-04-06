import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:aminidriver/Container/utils/keys.dart';
import 'package:aminidriver/View/Routes/routes.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';

class LiveTrackingScreen extends StatefulWidget {
  final String rideId;
  final LatLng pickup;
  final LatLng destination;
  final String? pickupName;
  final String? destinationName;

  const LiveTrackingScreen({
    super.key,
    required this.rideId,
    required this.pickup,
    required this.destination,
    this.pickupName,
    this.destinationName,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  GoogleMapController? _mapController;
  LatLng? _driverLocation;
  Marker? _driverMarker;

  Set<Polyline> _polylines = {};
  List<LatLng> _routePoints = [];
  int _lastRouteIndex = 0;

  Timer? _locationTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();

  double _distanceTraveledKm = 0;

  bool _tripStarted = false;
  bool _rideCompleted = false;
  bool _paid = false;

  double _finalFare = 0;

  @override
  void dispose() {
    _locationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _startTracking();
  }

  // ================= LOCATION TRACKING =================
  void _startTracking() {
    _locationTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition();
        final newLoc = LatLng(pos.latitude, pos.longitude);

        if (_driverLocation != null) {
          _distanceTraveledKm += _haversineKm(_driverLocation!, newLoc);
        }

        _driverLocation = newLoc;

        _updateDriverMarker(newLoc);
        _updateRouteProgress(newLoc);

        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: newLoc, zoom: 16, tilt: 45),
          ),
        );

        // ARRIVED PICKUP
        if (!_tripStarted && _haversineKm(newLoc, widget.pickup) < 0.05) {
          _tripStarted = true;
          _loadRoute(widget.pickup, widget.destination);
        }

        // NEAR DESTINATION ALERT
        if (_tripStarted && _haversineKm(newLoc, widget.destination) < 0.05) {
          _audioPlayer.play(AssetSource('sounds/alert.mp3'));
        }
      } catch (e) {
        debugPrint("Tracking error: $e");
      }
    });

    // Initial route → pickup
    _loadRoute(widget.pickup, widget.pickup);
  }

  void _updateDriverMarker(LatLng pos) {
    setState(() {
      _driverMarker = Marker(
        markerId: const MarkerId("driver"),
        position: pos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: "You"),
      );
    });
  }

  // ================= ROUTE =================
  Future<void> _loadRoute(LatLng start, LatLng end) async {
    final url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&key=$mapKey";

    final res = await http.get(Uri.parse(url));
    final data = jsonDecode(res.body);

    if (data['routes'].isNotEmpty) {
      final points = data['routes'][0]['overview_polyline']['points'];
      final decoded = _decodePolyline(points);

      setState(() {
        _routePoints = decoded;
        _lastRouteIndex = 0;
        _polylines = {
          Polyline(
            polylineId: const PolylineId("route"),
            points: _routePoints,
            color: Colors.blue,
            width: 6,
          ),
        };
      });
    }
  }

  void _updateRouteProgress(LatLng current) {
    if (_routePoints.isEmpty) return;

    for (int i = _lastRouteIndex; i < _routePoints.length; i++) {
      if (_haversineKm(current, _routePoints[i]) < 0.03) {
        _lastRouteIndex = i;
      }
    }

    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId("route"),
          points: _routePoints.sublist(0, _lastRouteIndex + 1),
          color: Colors.blue,
          width: 6,
        ),
      };
    });
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, lat = 0, lng = 0;

    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      polyline.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return polyline;
  }

  // ================= END RIDE =================
  Future<void> _endRide() async {
    if (_driverLocation == null) return;

    final url = Uri.parse('$baseUrl/rides/${widget.rideId}/end');

    try {
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'latitude': _driverLocation!.latitude,
          'longitude': _driverLocation!.longitude,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _finalFare = double.parse(data['fare'].toString());

        setState(() {
          _rideCompleted = true;
        });

        _showPaymentSheet();
      }
    } catch (e) {
      debugPrint("End error: $e");
    }
  }

  // ================= PAYMENT FLOW =================
  // void _showPaymentSheet() {
  //   showModalBottomSheet(
  //     context: context,
  //     isDismissible: false,
  //     enableDrag: false,
  //     shape: const RoundedRectangleBorder(
  //       borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  //     ),
  //     builder: (_) {
  //       return StatefulBuilder(
  //         builder: (context, setModalState) {
  //           return Padding(
  //             padding: const EdgeInsets.all(24),
  //             child: Column(
  //               mainAxisSize: MainAxisSize.min,
  //               children: [
  //                 Icon(
  //                   _paid ? Icons.check_circle : Icons.payments,
  //                   size: 60,
  //                   color: _paid ? Colors.green : Colors.orange,
  //                 ),
  //                 const SizedBox(height: 16),

  //                 Text(
  //                   _paid ? "Payment Completed" : "Awaiting Payment",
  //                   style: const TextStyle(
  //                     fontSize: 20,
  //                     fontWeight: FontWeight.bold,
  //                   ),
  //                 ),

  //                 const SizedBox(height: 10),

  //                 Text(
  //                   "UGX ${_finalFare.toStringAsFixed(0)}",
  //                   style: const TextStyle(
  //                     fontSize: 28,
  //                     fontWeight: FontWeight.bold,
  //                   ),
  //                 ),

  //                 const SizedBox(height: 20),

  //                 if (!_paid)
  //                   // ElevatedButton(
  //                   //   onPressed: () async {
  //                   //     // simulate payment success
  //                   //     await Future.delayed(const Duration(seconds: 2));
  //                   //     setModalState(() => _paid = true);
  //                   //   },
  //                   //   style: ElevatedButton.styleFrom(
  //                   //     backgroundColor: Colors.green,
  //                   //     minimumSize: const Size(double.infinity, 55),
  //                   //   ),
  //                   //   child: const Text("Confirm Payment"),
  //                   // ),
  //                   ElevatedButton(
  //                     onPressed: () async {
  //                       await Future.delayed(const Duration(seconds: 2));
  //                       setModalState(() => _paid = true);
  //                     },
  //                     style: ElevatedButton.styleFrom(
  //                       backgroundColor: Colors.black,
  //                       foregroundColor: Colors.white,
  //                       minimumSize: const Size(double.infinity, 55),
  //                     ),
  //                     child: const Text("Confirm Payment"),
  //                   ),

  //                 if (_paid)
  //                   ElevatedButton(
  //                     onPressed: () {
  //                       Navigator.pop(context);
  //                       context.goNamed(Routes().navigationScreen);
  //                     },
  //                     style: ElevatedButton.styleFrom(
  //                       backgroundColor: Colors.black,
  //                       foregroundColor: Colors.white,
  //                       minimumSize: const Size(double.infinity, 55),
  //                     ),
  //                     child: const Text("Finish"),
  //                   ),
  //               ],
  //             ),
  //           );
  //         },
  //       );
  //     },
  //   );
  // }

  void _showPaymentSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _paid ? Icons.check_circle : Icons.payments,
                    size: 70,
                    color: _paid ? Colors.green : Colors.black,
                  ),

                  const SizedBox(height: 16),

                  Text(
                    _paid ? "Payment Completed" : "Awaiting Payment",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    "UGX ${_finalFare.toStringAsFixed(0)}",
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  /// BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (!_paid) {
                          await Future.delayed(const Duration(seconds: 2));
                          setModalState(() => _paid = true);
                        } else {
                          Navigator.pop(context);
                          context.goNamed(Routes().navigationScreen);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 55),
                      ),
                      child: Text(_paid ? "Finish" : "Confirm Payment"),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ================= UTILS =================
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

  double _degToRad(double d) => d * math.pi / 180;

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final remainingKm =
        _driverLocation == null
            ? 0
            : _haversineKm(
              _driverLocation!,
              _tripStarted ? widget.destination : widget.pickup,
            );

    final eta = (remainingKm * 3).toStringAsFixed(0);
    final fare = (100 + (_distanceTraveledKm * 50)).toStringAsFixed(0);

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.pickup,
              zoom: 14,
            ),
            markers: {
              if (_driverMarker != null) _driverMarker!,
              Marker(
                markerId: const MarkerId("pickup"),
                position: widget.pickup,
                infoWindow: InfoWindow(title: widget.pickupName ?? "Pickup"),
              ),
              Marker(
                markerId: const MarkerId("destination"),
                position: widget.destination,
                infoWindow: InfoWindow(
                  title: widget.destinationName ?? "Destination",
                ),
              ),
            },
            polylines: _polylines,
            myLocationEnabled: true,
            onMapCreated: _onMapCreated,
          ),

          /// TOP CARD
          Positioned(top: 50, left: 16, right: 16, child: _topCard()),

          /// BOTTOM SHEET
          Positioned(bottom: 0, left: 0, right: 0, child: _bottomSheet(eta)),
        ],
      ),
    );
  }

  Widget _topCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.circle, size: 10, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.pickupName ?? "Pickup")),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on, size: 14, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.destinationName ?? "Destination")),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bottomSheet(String eta) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: screenHeight * 0.3, // occupy 30% of screen
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info rows
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.confirmation_number, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        "Ride ID: ${widget.rideId}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        "Rider: ${widget.pickupName ?? 'Unknown'}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 20),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "Pickup: ${widget.pickupName ?? ''}",
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.flag, size: 20),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "Destination: ${widget.destinationName ?? ''}",
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 20),
                      const SizedBox(width: 6),
                      Text("ETA: $eta min"),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // End Ride Button
            ElevatedButton(
              onPressed: _endRide,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "End Ride",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget _bottomSheet(String eta) {
  //   final screenHeight = MediaQuery.of(context).size.height;

  //   return Positioned(
  //     bottom: 0,
  //     left: 0,
  //     right: 0,
  //     child: Container(
  //       height: screenHeight * 0.3, // occupy 1/4 of screen
  //       padding: const EdgeInsets.all(20),
  //       decoration: const BoxDecoration(
  //         color: Colors.white,
  //         borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  //         boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
  //       ),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.stretch,
  //         children: [
  //           // Rider & ride info using _infoCard
  //           Expanded(
  //             child: Row(
  //               children: [
  //                 _infoCard(
  //                   Icons.confirmation_number,
  //                   "Ride ID",
  //                   widget.rideId,
  //                 ),
  //                 const SizedBox(width: 8),
  //                 _infoCard(
  //                   Icons.person,
  //                   "Rider",
  //                   widget.pickupName ?? "Unknown",
  //                 ), // replace with actual rider name if available
  //                 const SizedBox(width: 8),
  //                 _infoCard(
  //                   Icons.location_on,
  //                   "Pickup",
  //                   widget.pickupName ?? "",
  //                 ),
  //                 const SizedBox(width: 8),
  //                 _infoCard(
  //                   Icons.flag,
  //                   "Destination",
  //                   widget.destinationName ?? "",
  //                 ),
  //                 const SizedBox(width: 8),
  //                 _infoCard(Icons.access_time, "ETA", "$eta min"),
  //               ],
  //             ),
  //           ),

  //           const SizedBox(height: 10),

  //           // End Ride Button
  //           ElevatedButton(
  //             onPressed: _endRide,
  //             style: ElevatedButton.styleFrom(
  //               backgroundColor: Colors.black,
  //               foregroundColor: Colors.white,
  //               minimumSize: const Size(double.infinity, 50),
  //               shape: RoundedRectangleBorder(
  //                 borderRadius: BorderRadius.circular(12),
  //               ),
  //             ),
  //             child: const Text(
  //               "End Ride",
  //               style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // Info card helper
  Widget _infoCard(IconData icon, String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.black54),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
// import 'dart:async';
// import 'dart:convert';
// import 'dart:math' as math;
// import 'package:aminidriver/Container/utils/keys.dart';
// import 'package:aminidriver/View/Routes/routes.dart';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:audioplayers/audioplayers.dart';
// import 'package:http/http.dart' as http;
// import 'package:go_router/go_router.dart';

// class LiveTrackingScreen extends StatefulWidget {
//   final String rideId;
//   final LatLng pickup;
//   final LatLng destination;
//   final String? pickupName;
//   final String? destinationName;

//   const LiveTrackingScreen({
//     super.key,
//     required this.rideId,
//     required this.pickup,
//     required this.destination,
//     this.pickupName,
//     this.destinationName,
//   });

//   @override
//   State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
// }

// class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
//   GoogleMapController? _mapController;
//   LatLng? _driverLocation;
//   Marker? _driverMarker;

//   Set<Polyline> _polylines = {};
//   List<LatLng> _routePoints = [];
//   int _lastRouteIndex = 0;

//   Timer? _locationTimer;
//   final AudioPlayer _audioPlayer = AudioPlayer();

//   double _distanceTraveledKm = 0;
//   bool _tripStarted = false;

//   @override
//   void dispose() {
//     _locationTimer?.cancel();
//     _mapController?.dispose();
//     super.dispose();
//   }

//   void _onMapCreated(GoogleMapController controller) {
//     _mapController = controller;

//     _startLocationTracking();

//     // Initial route: driver → pickup
//     _loadRoute(widget.pickup, widget.pickup);
//   }

//   void _startLocationTracking() {
//     _locationTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
//       try {
//         final pos = await Geolocator.getCurrentPosition();
//         final newLoc = LatLng(pos.latitude, pos.longitude);

//         if (_driverLocation != null) {
//           _distanceTraveledKm += _haversineKm(_driverLocation!, newLoc);
//         }

//         _driverLocation = newLoc;

//         _updateDriverMarker(newLoc);
//         _updateRouteProgress(newLoc);

//         _mapController?.animateCamera(
//           CameraUpdate.newCameraPosition(
//             CameraPosition(target: newLoc, zoom: 16, tilt: 45),
//           ),
//         );

//         // Auto detect arrival at pickup
//         if (!_tripStarted && _haversineKm(newLoc, widget.pickup) < 0.05) {
//           _tripStarted = true;

//           // Load route pickup → destination
//           _loadRoute(widget.pickup, widget.destination);
//         }

//         // Alert near destination
//         if (_tripStarted && _haversineKm(newLoc, widget.destination) < 0.05) {
//           _audioPlayer.play(AssetSource('sounds/alert.mp3'));
//         }
//       } catch (e) {
//         debugPrint("Tracking error: $e");
//       }
//     });
//   }

//   void _updateDriverMarker(LatLng pos) {
//     setState(() {
//       _driverMarker = Marker(
//         markerId: const MarkerId("driver"),
//         position: pos,
//         icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
//         infoWindow: const InfoWindow(title: "You"),
//       );
//     });
//   }

//   List<LatLng> _decodePolyline(String encoded) {
//     List<LatLng> polyline = [];
//     int index = 0, lat = 0, lng = 0;

//     while (index < encoded.length) {
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

//   Future<void> _loadRoute(LatLng start, LatLng end) async {
//     final url =
//         "https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&key=$mapKey";

//     final res = await http.get(Uri.parse(url));
//     final data = jsonDecode(res.body);

//     if (data['routes'].isNotEmpty) {
//       final points = data['routes'][0]['overview_polyline']['points'];
//       final decoded = _decodePolyline(points);

//       setState(() {
//         _routePoints = decoded;
//         _lastRouteIndex = 0;
//         _polylines = {
//           Polyline(
//             polylineId: const PolylineId("route"),
//             points: _routePoints,
//             color: Colors.blue,
//             width: 5,
//           ),
//         };
//       });
//     }
//   }

//   void _updateRouteProgress(LatLng current) {
//     if (_routePoints.isEmpty) return;

//     for (int i = _lastRouteIndex; i < _routePoints.length; i++) {
//       if (_haversineKm(current, _routePoints[i]) < 0.03) {
//         _lastRouteIndex = i;
//       }
//     }

//     setState(() {
//       _polylines = {
//         Polyline(
//           polylineId: const PolylineId("route"),
//           points: _routePoints.sublist(0, _lastRouteIndex + 1),
//           color: Colors.blue,
//           width: 5,
//         ),
//       };
//     });
//   }

//   Future<void> _endRide() async {
//     if (_driverLocation == null) return;

//     final url = Uri.parse('$baseUrl/rides/${widget.rideId}/end');

//     try {
//       final res = await http.post(
//         url,
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({
//           'latitude': _driverLocation!.latitude,
//           'longitude': _driverLocation!.longitude,
//         }),
//       );

//       if (res.statusCode == 200) {
//         final data = jsonDecode(res.body);
//         final fare = double.tryParse(data['fare'].toString()) ?? 0;

//         _showFareDialog(fare);
//       }
//     } catch (e) {
//       debugPrint("End error: $e");
//     }
//   }

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

//   double _degToRad(double d) => d * math.pi / 180;

//   @override
//   Widget build(BuildContext context) {
//     final remainingKm =
//         _driverLocation == null
//             ? 0
//             : _haversineKm(
//               _driverLocation!,
//               _tripStarted ? widget.destination : widget.pickup,
//             );

//     final eta = (remainingKm * 3).toStringAsFixed(0);
//     final fare = (100 + (_distanceTraveledKm * 50)).toStringAsFixed(0);

//     return Scaffold(
//       body: Stack(
//         children: [
//           GoogleMap(
//             initialCameraPosition: CameraPosition(
//               target: widget.pickup,
//               zoom: 14,
//             ),
//             markers: {
//               if (_driverMarker != null) _driverMarker!,
//               Marker(
//                 markerId: const MarkerId("pickup"),
//                 position: widget.pickup,
//                 infoWindow: InfoWindow(title: widget.pickupName ?? "Pickup"),
//               ),
//               Marker(
//                 markerId: const MarkerId("destination"),
//                 position: widget.destination,
//                 infoWindow: InfoWindow(
//                   title: widget.destinationName ?? "Destination",
//                 ),
//               ),
//             },
//             polylines: _polylines,
//             myLocationEnabled: true,
//             onMapCreated: _onMapCreated,
//           ),

//           /// TOP CARD
//           Positioned(
//             top: 50,
//             left: 16,
//             right: 16,
//             child: Container(
//               padding: const EdgeInsets.all(14),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(14),
//                 boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
//               ),
//               child: Column(
//                 children: [
//                   Text(widget.pickupName ?? "Pickup"),
//                   Text(widget.destinationName ?? "Destination"),
//                 ],
//               ),
//             ),
//           ),

//           /// BOTTOM SHEET
//           Positioned(
//             bottom: 0,
//             left: 0,
//             right: 0,
//             child: Container(
//               padding: const EdgeInsets.all(20),
//               decoration: const BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Text("ETA: $eta min"),
//                   Text("Fare: UGX $fare"),
//                   const SizedBox(height: 10),
//                   ElevatedButton(
//                     onPressed: _endRide,
//                     child: const Text("End Ride"),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showFareDialog(double fare) {
//     showModalBottomSheet(
//       context: context,
//       builder:
//           (_) => Padding(
//             padding: const EdgeInsets.all(20),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text("Fare: UGX $fare"),
//                 ElevatedButton(
//                   onPressed: () {
//                     Navigator.pop(context);
//                     context.goNamed(Routes().navigationScreen);
//                   },
//                   child: const Text("Done"),
//                 ),
//               ],
//             ),
//           ),
//     );
//   }
// }

// // import 'dart:async';
// // import 'dart:convert';
// // import 'dart:math' as math;
// // import 'package:aminidriver/Container/utils/keys.dart';
// // import 'package:aminidriver/View/Routes/routes.dart';
// // import 'package:flutter/material.dart';
// // import 'package:firebase_auth/firebase_auth.dart';
// // import 'package:geolocator/geolocator.dart';
// // import 'package:google_maps_flutter/google_maps_flutter.dart';
// // import 'package:audioplayers/audioplayers.dart';
// // import 'package:http/http.dart' as http;
// // import 'package:go_router/go_router.dart';

// // class LiveTrackingScreen extends StatefulWidget {
// //   final String rideId;
// //   final LatLng pickup;
// //   final LatLng destination;
// //   final String? pickupName;
// //   final String? destinationName;

// //   const LiveTrackingScreen({
// //     super.key,
// //     required this.rideId,
// //     required this.pickup,
// //     required this.destination,
// //     this.pickupName,
// //     this.destinationName,
// //   });

// //   @override
// //   State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
// // }

// // class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
// //   GoogleMapController? _mapController;
// //   LatLng? _driverLocation;
// //   Marker? _driverMarker;
// //   Set<Polyline> _polylines = {};
// //   List<LatLng> _routePoints = [];
// //   int _lastRouteIndex = 0;
// //   Timer? _locationTimer;
// //   final AudioPlayer _audioPlayer = AudioPlayer();
// //   double _distanceTraveledKm = 0;

// //   @override
// //   void initState() {
// //     super.initState();
// //   }

// //   @override
// //   void dispose() {
// //     _locationTimer?.cancel();
// //     _mapController?.dispose();
// //     super.dispose();
// //   }

// //   void _onMapCreated(GoogleMapController controller) {
// //     _mapController = controller;

// //     // Add pickup and destination markers
// //     _addPickupDestinationMarkers();

// //     // Load polyline route
// //     _loadRoute(widget.pickup, widget.destination);

// //     // Start driver location tracking
// //     _startLocationTracking();
// //   }

// //   void _addPickupDestinationMarkers() {
// //     setState(() {
// //       _driverMarker = Marker(
// //         markerId: const MarkerId("driver"),
// //         position: widget.pickup,
// //         icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
// //       );

// //       _polylines = {}; // reset

// //       final markers = <Marker>{
// //         _driverMarker!,
// //         Marker(
// //           markerId: const MarkerId("pickup"),
// //           position: widget.pickup,
// //           infoWindow: InfoWindow(title: widget.pickupName ?? "Pickup"),
// //           icon: BitmapDescriptor.defaultMarkerWithHue(
// //             BitmapDescriptor.hueGreen,
// //           ),
// //         ),
// //         Marker(
// //           markerId: const MarkerId("destination"),
// //           position: widget.destination,
// //           infoWindow: InfoWindow(
// //             title: widget.destinationName ?? "Destination",
// //           ),
// //           icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
// //         ),
// //       };

// //       _driverMarker = markers.firstWhere((m) => m.markerId.value == "driver");
// //     });
// //   }

// //   void _startLocationTracking() {
// //     const locationSettings = LocationSettings(
// //       accuracy: LocationAccuracy.high,
// //       distanceFilter: 5,
// //     );

// //     _locationTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
// //       try {
// //         Position pos = await Geolocator.getCurrentPosition(
// //           desiredAccuracy: LocationAccuracy.high,
// //         );
// //         LatLng newLoc = LatLng(pos.latitude, pos.longitude);

// //         if (_driverLocation != null) {
// //           _distanceTraveledKm += _haversineKm(_driverLocation!, newLoc);
// //         }

// //         _driverLocation = newLoc;
// //         _updateDriverMarker(newLoc);
// //         _updateRouteProgress(newLoc);

// //         // Move camera smoothly
// //         _mapController?.animateCamera(CameraUpdate.newLatLngZoom(newLoc, 16));

// //         // Play alert when close to destination
// //         if (_haversineKm(newLoc, widget.destination) < 0.05) {
// //           _audioPlayer.play(AssetSource('sounds/alert.mp3'));
// //         }
// //       } catch (e) {
// //         debugPrint("Location tracking error: $e");
// //       }
// //     });
// //   }

// //   void _updateDriverMarker(LatLng pos) {
// //     setState(() {
// //       _driverMarker = Marker(
// //         markerId: const MarkerId("driver"),
// //         position: pos,
// //         icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
// //         infoWindow: const InfoWindow(title: "You"),
// //       );
// //     });
// //   }

// //   Future<void> _loadRoute(LatLng start, LatLng end) async {
// //     final url =
// //         "https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&mode=driving&key=$mapKey";

// //     final res = await http.get(Uri.parse(url));
// //     final data = jsonDecode(res.body);

// //     if (data['routes'].isNotEmpty) {
// //       final points = data['routes'][0]['overview_polyline']['points'];
// //       final decoded = _decodePolyline(points);
// //       setState(() {
// //         _routePoints = decoded;
// //         _polylines.add(
// //           Polyline(
// //             polylineId: const PolylineId("route"),
// //             points: _routePoints,
// //             color: Colors.blue,
// //             width: 5,
// //           ),
// //         );
// //       });
// //     }
// //   }

// //   void _updateRouteProgress(LatLng current) {
// //     if (_routePoints.isEmpty) return;

// //     for (int i = _lastRouteIndex; i < _routePoints.length; i++) {
// //       if (_haversineKm(current, _routePoints[i]) < 0.03) {
// //         _lastRouteIndex = i;
// //       }
// //     }

// //     setState(() {
// //       _polylines = {
// //         Polyline(
// //           polylineId: const PolylineId("route"),
// //           points: _routePoints.sublist(0, _lastRouteIndex + 1),
// //           color: Colors.blue,
// //           width: 5,
// //         ),
// //       };
// //     });
// //   }

// //   List<LatLng> _decodePolyline(String encoded) {
// //     List<LatLng> polyline = [];
// //     int index = 0, lat = 0, lng = 0;

// //     while (index < encoded.length) {
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

// //   Future<void> _endRide() async {
// //     if (_currentLocation == null) return;

// //     final url = Uri.parse('$baseUrl/rides/${widget.rideId}/end');

// //     try {
// //       final response = await http.post(
// //         url,
// //         headers: {'Content-Type': 'application/json'},
// //         body: jsonEncode({
// //           'latitude': _currentLocation!.latitude,
// //           'longitude': _currentLocation!.longitude,
// //         }),
// //       );

// //       if (response.statusCode == 200) {
// //         final data = jsonDecode(response.body);
// //         final fare = double.tryParse(data['fare'].toString()) ?? 0;

// //         if (!mounted) return;

// //         _showFareDialog(fare);
// //       } else {
// //         throw Exception("Failed to end ride");
// //       }
// //     } catch (e) {
// //       debugPrint("End ride error: $e");
// //       if (mounted) {
// //         ScaffoldMessenger.of(
// //           context,
// //         ).showSnackBar(SnackBar(content: Text("Error ending ride: $e")));
// //       }
// //     }
// //   }

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

// //   double _degToRad(double d) => d * math.pi / 180;

// //   @override
// //   @override
// //   Widget build(BuildContext context) {
// //     final etaMinutes = (_distanceTraveledKm * 2).toStringAsFixed(
// //       0,
// //     ); // simple estimate
// //     final fare = (100 + (_distanceTraveledKm * 50)).toStringAsFixed(0);

// //     return Scaffold(
// //       body: Stack(
// //         children: [
// //           GoogleMap(
// //             initialCameraPosition: CameraPosition(
// //               target: widget.pickup,
// //               zoom: 14,
// //             ),
// //             markers: {
// //               if (_driverMarker != null) _driverMarker!,
// //               Marker(
// //                 markerId: const MarkerId("pickup"),
// //                 position: widget.pickup,
// //                 infoWindow: InfoWindow(title: widget.pickupName ?? "Pickup"),
// //                 icon: BitmapDescriptor.defaultMarkerWithHue(
// //                   BitmapDescriptor.hueGreen,
// //                 ),
// //               ),
// //               Marker(
// //                 markerId: const MarkerId("destination"),
// //                 position: widget.destination,
// //                 infoWindow: InfoWindow(
// //                   title: widget.destinationName ?? "Destination",
// //                 ),
// //                 icon: BitmapDescriptor.defaultMarkerWithHue(
// //                   BitmapDescriptor.hueRed,
// //                 ),
// //               ),
// //             },
// //             polylines: _polylines,
// //             myLocationEnabled: true,
// //             zoomControlsEnabled: false,
// //             onMapCreated: _onMapCreated,
// //           ),

// //           /// TOP GLASS CARD (like Uber)
// //           Positioned(
// //             top: 50,
// //             left: 16,
// //             right: 16,
// //             child: Container(
// //               padding: const EdgeInsets.all(14),
// //               decoration: BoxDecoration(
// //                 color: Colors.white.withOpacity(0.9),
// //                 borderRadius: BorderRadius.circular(16),
// //                 boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
// //               ),
// //               child: Column(
// //                 crossAxisAlignment: CrossAxisAlignment.start,
// //                 children: [
// //                   Row(
// //                     children: [
// //                       const Icon(Icons.circle, color: Colors.green, size: 10),
// //                       const SizedBox(width: 8),
// //                       Expanded(child: Text(widget.pickupName ?? "Pickup")),
// //                     ],
// //                   ),
// //                   const SizedBox(height: 8),
// //                   Row(
// //                     children: [
// //                       const Icon(
// //                         Icons.location_on,
// //                         color: Colors.red,
// //                         size: 14,
// //                       ),
// //                       const SizedBox(width: 8),
// //                       Expanded(
// //                         child: Text(widget.destinationName ?? "Destination"),
// //                       ),
// //                     ],
// //                   ),
// //                 ],
// //               ),
// //             ),
// //           ),

// //           /// BOTTOM SHEET
// //           DraggableScrollableSheet(
// //             initialChildSize: 0.28,
// //             minChildSize: 0.22,
// //             maxChildSize: 0.45,
// //             builder: (_, controller) {
// //               return Container(
// //                 padding: const EdgeInsets.all(20),
// //                 decoration: const BoxDecoration(
// //                   color: Colors.white,
// //                   borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
// //                 ),
// //                 child: SingleChildScrollView(
// //                   controller: controller,
// //                   child: Column(
// //                     crossAxisAlignment: CrossAxisAlignment.start,
// //                     children: [
// //                       /// DRAG HANDLE
// //                       Center(
// //                         child: Container(
// //                           width: 50,
// //                           height: 5,
// //                           decoration: BoxDecoration(
// //                             color: Colors.grey[300],
// //                             borderRadius: BorderRadius.circular(10),
// //                           ),
// //                         ),
// //                       ),

// //                       const SizedBox(height: 20),

// //                       /// ETA + FARE ROW
// //                       Row(
// //                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //                         children: [
// //                           _infoCard(Icons.timer, "$etaMinutes min"),
// //                           _infoCard(Icons.attach_money, "UGX $fare"),
// //                         ],
// //                       ),

// //                       const SizedBox(height: 20),

// //                       /// DRIVER INFO
// //                       Row(
// //                         children: [
// //                           CircleAvatar(
// //                             radius: 24,
// //                             backgroundColor: Colors.grey[300],
// //                             child: const Icon(Icons.person),
// //                           ),
// //                           const SizedBox(width: 12),
// //                           Expanded(
// //                             child: Column(
// //                               crossAxisAlignment: CrossAxisAlignment.start,
// //                               children: const [
// //                                 Text(
// //                                   "You (Driver)",
// //                                   style: TextStyle(fontWeight: FontWeight.bold),
// //                                 ),
// //                                 Text("Toyota • UBA 123A"),
// //                               ],
// //                             ),
// //                           ),
// //                           const Icon(Icons.star, color: Colors.amber),
// //                           const Text("4.8"),
// //                         ],
// //                       ),

// //                       const SizedBox(height: 20),

// //                       /// END RIDE BUTTON
// //                       SizedBox(
// //                         width: double.infinity,
// //                         child: ElevatedButton(
// //                           onPressed: _endRide,
// //                           style: ElevatedButton.styleFrom(
// //                             backgroundColor: Colors.red,
// //                             minimumSize: const Size(double.infinity, 55),
// //                             shape: RoundedRectangleBorder(
// //                               borderRadius: BorderRadius.circular(14),
// //                             ),
// //                           ),
// //                           child: const Text(
// //                             "End Ride",
// //                             style: TextStyle(fontSize: 18),
// //                           ),
// //                         ),
// //                       ),
// //                     ],
// //                   ),
// //                 ),
// //               );
// //             },
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   Widget _infoCard(IconData icon, String text) {
// //     return Container(
// //       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
// //       decoration: BoxDecoration(
// //         color: const Color(0xFFF2F2F2),
// //         borderRadius: BorderRadius.circular(12),
// //       ),
// //       child: Row(
// //         children: [
// //           Icon(icon, size: 18),
// //           const SizedBox(width: 6),
// //           Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
// //         ],
// //       ),
// //     );
// //   }

// //   void _showFareDialog(double fare) {
// //     showModalBottomSheet(
// //       context: context,
// //       isDismissible: false,
// //       enableDrag: false,
// //       shape: const RoundedRectangleBorder(
// //         borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
// //       ),
// //       builder: (_) {
// //         return Padding(
// //           padding: const EdgeInsets.all(24),
// //           child: Column(
// //             mainAxisSize: MainAxisSize.min,
// //             children: [
// //               const Icon(Icons.check_circle, color: Colors.green, size: 60),
// //               const SizedBox(height: 16),
// //               const Text(
// //                 "Ride Completed",
// //                 style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
// //               ),
// //               const SizedBox(height: 10),
// //               Text(
// //                 "Fare: UGX ${fare.toStringAsFixed(0)}",
// //                 style: const TextStyle(fontSize: 20, color: Colors.red),
// //               ),
// //               const SizedBox(height: 20),
// //               ElevatedButton(
// //                 onPressed: () {
// //                    Navigator.pop(context);
// //                   context.goNamed(Routes().navigationScreen);

// //                   //context.go('/navigationscreen'); // adjust your route
// //                 },
// //                 child: const Text("Done"),
// //               ),
// //             ],
// //           ),
// //         );
// //       },
// //     );
// //   }
// // }

// // // import 'dart:async';
// // // import 'dart:convert';
// // // import 'dart:math' as math;
// // // import 'package:aminidriver/Container/utils/keys.dart';
// // // import 'package:aminidriver/View/Routes/routes.dart';
// // // import 'package:aminidriver/main.dart';
// // // import 'package:flutter/material.dart';
// // // import 'package:firebase_auth/firebase_auth.dart';
// // // import 'package:firebase_database/firebase_database.dart';
// // // import 'package:geolocator/geolocator.dart';
// // // import 'package:go_router/go_router.dart';
// // // import 'package:google_maps_flutter/google_maps_flutter.dart';
// // // import 'package:audioplayers/audioplayers.dart';
// // // import 'package:http/http.dart' as http;
// // // import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_screen.dart';

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
// // //   Set<Polyline> _polylines = {};
// // //   double _distanceTraveledKm = 0;
// // //   bool _ended = false;
// // //   final DatabaseReference _rideRef = FirebaseDatabase.instance.ref();
// // //   final AudioPlayer _audioPlayer = AudioPlayer();
// // //   Timer? _locationTimer;
// // //   List<LatLng> _routePoints = [];
// // //   int _lastRouteIndex = 0; // Last point drawn on the map

// // //   @override
// // //   void dispose() {
// // //     _locationTimer?.cancel();
// // //     _mapController?.dispose();
// // //     super.dispose();
// // //   }

// // //   void _onMapCreated(GoogleMapController controller) {
// // //     _mapController = controller;

// // //     _initTracking();

// // //     if (widget.pickup != null && widget.destination != null) {
// // //       _loadRoute(widget.pickup!, widget.destination!);
// // //     }
// // //   }

// // //   void _initTracking() {
// // //     _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
// // //       try {
// // //         Position pos = await Geolocator.getCurrentPosition(
// // //           desiredAccuracy: LocationAccuracy.high,
// // //         );
// // //         LatLng newLoc = LatLng(pos.latitude, pos.longitude);

// // //         if (_currentLocation != null) {
// // //           _distanceTraveledKm += _haversineKm(_currentLocation!, newLoc);
// // //         }

// // //         _currentLocation = newLoc;
// // //         _updateDriverMarker(newLoc);
// // //         _updateRouteProgress(newLoc);

// // //         _mapController?.animateCamera(CameraUpdate.newLatLng(newLoc));

// // //         FirebaseDatabase.instance
// // //             .ref('drivers/${FirebaseAuth.instance.currentUser!.uid}/location')
// // //             .set({
// // //               'lat': pos.latitude,
// // //               'lng': pos.longitude,
// // //               'timestamp': ServerValue.timestamp,
// // //             });

// // //         if (widget.destination != null &&
// // //             _haversineKm(newLoc, widget.destination!) < 0.1) {
// // //           _audioPlayer.play(AssetSource('sounds/alert.mp3'));
// // //         }
// // //       } catch (e) {
// // //         debugPrint("Location tracking error: $e");
// // //       }
// // //     });
// // //   }

// // //   void _updateDriverMarker(LatLng newLoc) {
// // //     setState(() {
// // //       _driverMarker = Marker(
// // //         markerId: const MarkerId("driver"),
// // //         position: newLoc,
// // //         icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
// // //       );
// // //     });
// // //   }

// // //   /// Incrementally draw route polyline up to the current location
// // //   void _updateRouteProgress(LatLng current) {
// // //     if (_routePoints.isEmpty) return;

// // //     // Find the closest point ahead
// // //     for (int i = _lastRouteIndex; i < _routePoints.length; i++) {
// // //       if (_haversineKm(current, _routePoints[i]) < 0.05) {
// // //         _lastRouteIndex = i;
// // //       }
// // //     }

// // //     setState(() {
// // //       _polylines = {
// // //         Polyline(
// // //           polylineId: const PolylineId("route"),
// // //           points: _routePoints.sublist(0, _lastRouteIndex + 1),
// // //           color: Colors.blue,
// // //           width: 5,
// // //         ),
// // //       };
// // //     });
// // //   }

// // //   Future<void> _loadRoute(LatLng pickup, LatLng dest) async {
// // //     final url =
// // //         "https://maps.googleapis.com/maps/api/directions/json?origin=${pickup.latitude},${pickup.longitude}&destination=${dest.latitude},${dest.longitude}&mode=driving&key=$mapKey";

// // //     try {
// // //       final response = await http.get(Uri.parse(url));
// // //       final data = jsonDecode(response.body);

// // //       if (data['routes'].isNotEmpty) {
// // //         final points = data['routes'][0]['overview_polyline']['points'];
// // //         final decoded = _decodePolyline(points);
// // //         final simplified = _simplifyPolyline(decoded, factor: 5);
// // //         setState(() {
// // //           _routePoints = simplified;
// // //         });
// // //       }
// // //     } catch (e) {
// // //       debugPrint("Error loading route: $e");
// // //     }
// // //   }

// // //   List<LatLng> _simplifyPolyline(List<LatLng> points, {int factor = 3}) {
// // //     final simplified = <LatLng>[];
// // //     for (var i = 0; i < points.length; i += factor) simplified.add(points[i]);
// // //     if (points.isNotEmpty) simplified.add(points.last);
// // //     return simplified;
// // //   }

// // //   List<LatLng> _decodePolyline(String encoded) {
// // //     List<LatLng> polyline = [];
// // //     int index = 0, len = encoded.length;
// // //     int lat = 0, lng = 0;

// // //     while (index < len) {
// // //       int b, shift = 0, result = 0;
// // //       do {
// // //         b = encoded.codeUnitAt(index++) - 63;
// // //         result |= (b & 0x1F) << shift;
// // //         shift += 5;
// // //       } while (b >= 0x20);
// // //       int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
// // //       lat += dlat;

// // //       shift = 0;
// // //       result = 0;
// // //       do {
// // //         b = encoded.codeUnitAt(index++) - 63;
// // //         result |= (b & 0x1F) << shift;
// // //         shift += 5;
// // //       } while (b >= 0x20);
// // //       int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
// // //       lng += dlng;

// // //       polyline.add(LatLng(lat / 1E5, lng / 1E5));
// // //     }
// // //     return polyline;
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
// // //         final responseData = jsonDecode(response.body);
// // //         final double fare = double.parse(responseData['fare'].toString());

// // //         final db = FirebaseDatabase.instanceFor(app: passengerApp);
// // //         final rideRef = db.ref("rides/${widget.rideId}");

// // //         await rideRef.update({
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
// // //         ScaffoldMessenger.of(
// // //           context,
// // //         ).showSnackBar(SnackBar(content: Text("Error ending ride: $e")));
// // //       }
// // //     }
// // //   }

// // //   double _computeFare(double traveledKm) => baseFare + traveledKm * perKmFare;

// // //   double _haversineKm(LatLng a, LatLng b) {
// // //     const R = 6371.0;
// // //     final dLat = _degToRad(b.latitude - a.latitude);
// // //     final dLng = _degToRad(b.longitude - a.longitude);
// // //     final aa =
// // //         math.sin(dLat / 2) * math.sin(dLat / 2) +
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
// // //       backgroundColor: Colors.white,
// // //       shape: const RoundedRectangleBorder(
// // //         borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
// // //       ),
// // //       builder: (_) {
// // //         final screenHeight = MediaQuery.of(context).size.height;
// // //         return SizedBox(
// // //           height: screenHeight * 0.5,
// // //           child: Padding(
// // //             padding: const EdgeInsets.all(24),
// // //             child: Column(
// // //               children: [
// // //                 const Icon(Icons.check_circle, color: Colors.green, size: 56),
// // //                 const SizedBox(height: 16),
// // //                 const Text(
// // //                   'Trip Completed',
// // //                   style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
// // //                 ),
// // //                 const SizedBox(height: 8),
// // //                 Text(
// // //                   'Distance: ${_distanceTraveledKm.toStringAsFixed(2)} km',
// // //                   style: const TextStyle(fontSize: 16),
// // //                 ),
// // //                 const SizedBox(height: 8),
// // //                 Text(
// // //                   'Fare: KES ${fare.toStringAsFixed(2)}',
// // //                   style: const TextStyle(
// // //                     fontSize: 22,
// // //                     fontWeight: FontWeight.bold,
// // //                     color: Colors.red,
// // //                   ),
// // //                 ),
// // //                 const Spacer(),
// // //                 SizedBox(
// // //                   width: double.infinity,
// // //                   child: ElevatedButton(
// // //                     onPressed: () {
// // //                       context.goNamed(Routes().navigationScreen);
// // //                       // Navigator.push(
// // //                       //   context,
// // //                       //   MaterialPageRoute(builder: (_) => const HomeScreen()),
// // //                       // );
// // //                       // Navigator.of(context).pushNamed(const HomeScreen()
// // //                       //   MaterialPageRoute(builder: (_) => const HomeScreen()),
// // //                       //   // (route) => false, // ✅ clear back stack
// // //                       // );
// // //                       // Navigator.pop(context);
// // //                       // Navigator.pop(context);
// // //                     },
// // //                     style: ElevatedButton.styleFrom(
// // //                       backgroundColor: Colors.red,
// // //                       padding: const EdgeInsets.symmetric(vertical: 16),
// // //                       shape: RoundedRectangleBorder(
// // //                         borderRadius: BorderRadius.circular(12),
// // //                       ),
// // //                     ),
// // //                     child: const Text("OK", style: TextStyle(fontSize: 18)),
// // //                   ),
// // //                 ),
// // //               ],
// // //             ),
// // //           ),
// // //         );
// // //       },
// // //     );
// // //   }

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     return Scaffold(
// // //       appBar: AppBar(title: const Text('Live Ride Tracking')),
// // //       body: GoogleMap(
// // //         initialCameraPosition: CameraPosition(
// // //           target: widget.pickup ?? const LatLng(-1.286389, 36.817223),
// // //           zoom: 14,
// // //         ),
// // //         markers: _driverMarker != null ? {_driverMarker!} : {},
// // //         polylines: _polylines,
// // //         myLocationEnabled: true,
// // //         myLocationButtonEnabled: true,
// // //         onMapCreated: _onMapCreated,
// // //       ),
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
// // // // import 'package:aminidriver/Container/utils/keys.dart'; // put your Google Maps API key in keys.dart
// // // // import 'package:aminidriver/main.dart';
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

// // // // class _LiveTrackingScreenState extends State<LiveTrackingScreen>
// // // //     with TickerProviderStateMixin {
// // // //   LatLng? _currentLocation;
// // // //   GoogleMapController? _mapController;
// // // //   Marker? _driverMarker;
// // // //   Set<Polyline> _polylines = {};
// // // //   double _distanceTraveledKm = 0;
// // // //   bool _ended = false;
// // // //   final DatabaseReference _rideRef = FirebaseDatabase.instance.ref();
// // // //   final AudioPlayer _audioPlayer = AudioPlayer();
// // // //   Timer? _locationTimer;
// // // //   List<LatLng> _routePoints = [];
// // // //   int _currentRouteIndex = 0;

// // // //   @override
// // // //   void dispose() {
// // // //     _locationTimer?.cancel();
// // // //     _mapController?.dispose();
// // // //     super.dispose();
// // // //   }

// // // //   /// Map created → now safe to start tracking + route
// // // //   void _onMapCreated(GoogleMapController controller) {
// // // //     _mapController = controller;

// // // //     if (widget.pickup != null && widget.destination != null) {
// // // //       _loadRoute(widget.pickup!, widget.destination!);
// // // //     }

// // // //     _initTracking();
// // // //   }

// // // //   /// Start location tracking like Uber
// // // //   void _initTracking() {
// // // //     _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
// // // //       try {
// // // //         Position pos = await Geolocator.getCurrentPosition(
// // // //           desiredAccuracy: LocationAccuracy.best,
// // // //         );
// // // //         LatLng newLoc = LatLng(pos.latitude, pos.longitude);

// // // //         if (_currentLocation != null) {
// // // //           _distanceTraveledKm += _haversineKm(_currentLocation!, newLoc);
// // // //         }

// // // //         _animateMarker(newLoc); // ✅ smooth animation
// // // //         _currentLocation = newLoc;

// // // //         // Smooth camera update
// // // //         _mapController?.animateCamera(CameraUpdate.newLatLng(newLoc));

// // // //         // Update Firebase driver location
// // // //         FirebaseDatabase.instance
// // // //             .ref('drivers/${FirebaseAuth.instance.currentUser!.uid}/location')
// // // //             .set({
// // // //               'lat': pos.latitude,
// // // //               'lng': pos.longitude,
// // // //               'timestamp': ServerValue.timestamp,
// // // //             });

// // // //         // Play alert near destination
// // // //         if (widget.destination != null &&
// // // //             _haversineKm(newLoc, widget.destination!) < 0.1) {
// // // //           _audioPlayer.play(AssetSource('sounds/alert.mp3'));
// // // //         }
// // // //       } catch (e) {
// // // //         debugPrint("Location tracking error: $e");
// // // //       }
// // // //     });
// // // //   }

// // // //   /// Animate marker smoothly
// // // //   void _animateMarker(LatLng newLoc) {
// // // //     final old = _driverMarker?.position ?? newLoc;
// // // //     final tweenLat = Tween<double>(begin: old.latitude, end: newLoc.latitude);
// // // //     final tweenLng = Tween<double>(begin: old.longitude, end: newLoc.longitude);

// // // //     final controller = AnimationController(
// // // //       duration: const Duration(seconds: 2),
// // // //       vsync: this,
// // // //     );

// // // //     final animation = CurvedAnimation(
// // // //       parent: controller,
// // // //       curve: Curves.easeInOut,
// // // //     );

// // // //     controller.addListener(() {
// // // //       final lat = tweenLat.evaluate(animation);
// // // //       final lng = tweenLng.evaluate(animation);
// // // //       setState(() {
// // // //         _driverMarker = Marker(
// // // //           markerId: const MarkerId("driver"),
// // // //           position: LatLng(lat, lng),
// // // //           icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
// // // //         );
// // // //       });
// // // //     });

// // // //     controller.forward().whenComplete(controller.dispose);
// // // //   }

// // // //   /// Fetch and draw polyline route
// // // //   Future<void> _loadRoute(LatLng pickup, LatLng dest) async {
// // // //     final url =
// // // //         "https://maps.googleapis.com/maps/api/directions/json?origin=${pickup.latitude},${pickup.longitude}&destination=${dest.latitude},${dest.longitude}&mode=driving&key=$mapKey";

// // // //     try {
// // // //       final response = await http.get(Uri.parse(url));
// // // //       final data = jsonDecode(response.body);

// // // //       if (data['routes'].isNotEmpty) {
// // // //         final points = data['routes'][0]['overview_polyline']['points'];
// // // //         final decoded = _decodePolyline(points);

// // // //         // setState(() {
// // // //         //   _polylines.add(
// // // //         //     Polyline(
// // // //         //       polylineId: const PolylineId("route"),
// // // //         //       points: decoded,
// // // //         //       color: Colors.blue,
// // // //         //       width: 5,
// // // //         //     ),
// // // //         //   );
// // // //         // });
// // // //         setState(() {
// // // //           _routePoints = decoded;
// // // //           _polylines.add(
// // // //             Polyline(
// // // //               polylineId: const PolylineId("route"),
// // // //               points: decoded,
// // // //               color: Colors.blue,
// // // //               width: 5,
// // // //             ),
// // // //           );
// // // //         });
// // // //       }
// // // //     } catch (e) {
// // // //       debugPrint("Error loading route: $e");
// // // //     }
// // // //   }

// // // //   /// Decode Google polyline string
// // // //   List<LatLng> _decodePolyline(String encoded) {
// // // //     List<LatLng> polyline = [];
// // // //     int index = 0, len = encoded.length;
// // // //     int lat = 0, lng = 0;

// // // //     while (index < len) {
// // // //       int b, shift = 0, result = 0;
// // // //       do {
// // // //         b = encoded.codeUnitAt(index++) - 63;
// // // //         result |= (b & 0x1F) << shift;
// // // //         shift += 5;
// // // //       } while (b >= 0x20);
// // // //       int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
// // // //       lat += dlat;

// // // //       shift = 0;
// // // //       result = 0;
// // // //       do {
// // // //         b = encoded.codeUnitAt(index++) - 63;
// // // //         result |= (b & 0x1F) << shift;
// // // //         shift += 5;
// // // //       } while (b >= 0x20);
// // // //       int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
// // // //       lng += dlng;

// // // //       polyline.add(LatLng(lat / 1E5, lng / 1E5));
// // // //     }
// // // //     return polyline;
// // // //   }

// // // //   Future<void> _endRide() async {
// // // //     if (_ended || _currentLocation == null) return;

// // // //     final url = Uri.parse('$baseUrl/rides/${widget.rideId}/end');

// // // //     try {
// // // //       final response = await http.post(
// // // //         url,
// // // //         headers: {'Content-Type': 'application/json'},
// // // //         body: jsonEncode({
// // // //           'latitude': _currentLocation?.latitude,
// // // //           'longitude': _currentLocation?.longitude,
// // // //         }),
// // // //       );

// // // //       if (response.statusCode == 200) {
// // // //         final responseData = jsonDecode(response.body);

// // // //         // Assume backend returns fare in decimal-compatible format
// // // //         final String fareString = responseData['fare'].toString();
// // // //         final double fare = double.parse(fareString);
// // // //         //  double fare = _computeFare(_distanceTraveledKm);

// // // //         final db = FirebaseDatabase.instanceFor(app: passengerApp);
// // // //         final rideRef = db.ref("rides/${widget.rideId}");

// // // //         await rideRef.update({
// // // //           'status': 'completed',
// // // //           'destination/lat': _currentLocation!.latitude,
// // // //           'destination/lng': _currentLocation!.longitude,
// // // //           'distanceKm': double.parse(_distanceTraveledKm.toStringAsFixed(2)),
// // // //           'fare': double.parse(fare.toStringAsFixed(2)),
// // // //           'endedAt': ServerValue.timestamp,
// // // //         });

// // // //         setState(() => _ended = true);
// // // //         _showFareSheet(fare);
// // // //       } else {
// // // //         throw Exception("Failed to end ride");
// // // //       }
// // // //     } catch (e) {
// // // //       debugPrint("End ride error: $e");
// // // //       if (mounted) {
// // // //         ScaffoldMessenger.of(
// // // //           context,
// // // //         ).showSnackBar(SnackBar(content: Text("Error ending ride: $e")));
// // // //       }
// // // //     }
// // // //   }

// // // //   /// End the ride
// // // //   // Future<void> _endRide() async {
// // // //   //   if (_ended || _currentLocation == null) return;

// // // //   //   try {
// // // //   //     double fare = _computeFare(_distanceTraveledKm);

// // // //   //     await _rideRef.child('rides/${widget.rideId}').update({
// // // //   //       'status': 'completed',
// // // //   //       'destination/lat': _currentLocation!.latitude,
// // // //   //       'destination/lng': _currentLocation!.longitude,
// // // //   //       'distanceKm': double.parse(_distanceTraveledKm.toStringAsFixed(2)),
// // // //   //       'fare': double.parse(fare.toStringAsFixed(2)),
// // // //   //       'endedAt': ServerValue.timestamp,
// // // //   //     });

// // // //   //     setState(() => _ended = true);

// // // //   //     _showFareSheet(fare);
// // // //   //   } catch (e) {
// // // //   //     debugPrint("End ride error: $e");
// // // //   //     if (mounted) {
// // // //   //       ScaffoldMessenger.of(
// // // //   //         context,
// // // //   //       ).showSnackBar(SnackBar(content: Text("Error ending ride: $e")));
// // // //   //     }
// // // //   //   }
// // // //   // }

// // // //   double _computeFare(double traveledKm) => baseFare + traveledKm * perKmFare;

// // // //   double _haversineKm(LatLng a, LatLng b) {
// // // //     const R = 6371.0;
// // // //     final dLat = _degToRad(b.latitude - a.latitude);
// // // //     final dLng = _degToRad(b.longitude - a.longitude);
// // // //     final aa =
// // // //         math.sin(dLat / 2) * math.sin(dLat / 2) +
// // // //         math.cos(_degToRad(a.latitude)) *
// // // //             math.cos(_degToRad(b.latitude)) *
// // // //             math.sin(dLng / 2) *
// // // //             math.sin(dLng / 2);
// // // //     return R * 2 * math.atan2(math.sqrt(aa), math.sqrt(1 - aa));
// // // //   }

// // // //   double _degToRad(double d) => d * math.pi / 180.0;

// // // //   // void _showFareSheet(double fare) {
// // // //   //   if (!mounted) return;
// // // //   //   showModalBottomSheet(
// // // //   //     context: context,
// // // //   //     isDismissible: false,
// // // //   //     enableDrag: false,
// // // //   //     shape: const RoundedRectangleBorder(
// // // //   //       borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
// // // //   //     ),
// // // //   //     builder:
// // // //   //         (_) => Container(
// // // //   //           padding: const EdgeInsets.all(24),
// // // //   //           height: 240,
// // // //   //           child: Column(
// // // //   //             mainAxisAlignment: MainAxisAlignment.center,
// // // //   //             children: [
// // // //   //               const Icon(Icons.check_circle, color: Colors.green, size: 48),
// // // //   //               const SizedBox(height: 16),
// // // //   //               const Text(
// // // //   //                 'Trip Completed',
// // // //   //                 style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
// // // //   //               ),
// // // //   //               const SizedBox(height: 8),
// // // //   //               Text('Distance: ${_distanceTraveledKm.toStringAsFixed(2)} km'),
// // // //   //               const SizedBox(height: 8),
// // // //   //               Text(
// // // //   //                 'Fare: KES ${fare.toStringAsFixed(2)}',
// // // //   //                 style: const TextStyle(
// // // //   //                   fontSize: 20,
// // // //   //                   fontWeight: FontWeight.bold,
// // // //   //                   color: Colors.red,
// // // //   //                 ),
// // // //   //               ),
// // // //   //               const SizedBox(height: 20),
// // // //   //               ElevatedButton(
// // // //   //                 onPressed: () {
// // // //   //                   Navigator.pop(context);
// // // //   //                   Navigator.pop(context);
// // // //   //                 },
// // // //   //                 style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
// // // //   //                 child: const Text("OK"),
// // // //   //               ),
// // // //   //             ],
// // // //   //           ),
// // // //   //         ),
// // // //   //   );
// // // //   // }

// // // //   void _showFareSheet(double fare) {
// // // //     if (!mounted) return;
// // // //     showModalBottomSheet(
// // // //       context: context,
// // // //       isDismissible: false,
// // // //       enableDrag: false,
// // // //       backgroundColor: Colors.white, // fill screen sides
// // // //       shape: const RoundedRectangleBorder(
// // // //         borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
// // // //       ),
// // // //       builder: (_) {
// // // //         final screenHeight = MediaQuery.of(context).size.height;
// // // //         return SizedBox(
// // // //           height: screenHeight * 0.5, // half the screen
// // // //           child: Padding(
// // // //             padding: const EdgeInsets.all(24),
// // // //             child: Column(
// // // //               children: [
// // // //                 const Icon(Icons.check_circle, color: Colors.green, size: 56),
// // // //                 const SizedBox(height: 16),
// // // //                 const Text(
// // // //                   'Trip Completed',
// // // //                   style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
// // // //                 ),
// // // //                 const SizedBox(height: 8),
// // // //                 Text(
// // // //                   'Distance: ${_distanceTraveledKm.toStringAsFixed(2)} km',
// // // //                   style: const TextStyle(fontSize: 16),
// // // //                 ),
// // // //                 const SizedBox(height: 8),
// // // //                 Text(
// // // //                   'Fare: KES ${fare.toStringAsFixed(2)}',
// // // //                   style: const TextStyle(
// // // //                     fontSize: 22,
// // // //                     fontWeight: FontWeight.bold,
// // // //                     color: Colors.red,
// // // //                   ),
// // // //                 ),
// // // //                 const Spacer(),
// // // //                 SizedBox(
// // // //                   width: double.infinity,
// // // //                   child: ElevatedButton(
// // // //                     onPressed: () {
// // // //                       Navigator.pop(context); // close sheet
// // // //                       Navigator.pop(context); // close ride screen
// // // //                     },
// // // //                     style: ElevatedButton.styleFrom(
// // // //                       backgroundColor: Colors.red,
// // // //                       padding: const EdgeInsets.symmetric(vertical: 16),
// // // //                       shape: RoundedRectangleBorder(
// // // //                         borderRadius: BorderRadius.circular(12),
// // // //                       ),
// // // //                     ),
// // // //                     child: const Text("OK", style: TextStyle(fontSize: 18)),
// // // //                   ),
// // // //                 ),
// // // //               ],
// // // //             ),
// // // //           ),
// // // //         );
// // // //       },
// // // //     );
// // // //   }

// // // //   @override
// // // //   Widget build(BuildContext context) {
// // // //     return Scaffold(
// // // //       appBar: AppBar(title: const Text('Live Ride Tracking')),
// // // //       body: GoogleMap(
// // // //         initialCameraPosition: CameraPosition(
// // // //           target:
// // // //               widget.pickup ??
// // // //               const LatLng(-1.286389, 36.817223), // Nairobi fallback
// // // //           zoom: 14,
// // // //         ),
// // // //         markers: _driverMarker != null ? {_driverMarker!} : {},
// // // //         polylines: _polylines,
// // // //         myLocationEnabled: true,
// // // //         myLocationButtonEnabled: true,
// // // //         onMapCreated: _onMapCreated,
// // // //       ),
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
// // // // // import 'dart:math' as math;
// // // // // import 'package:aminidriver/Container/utils/keys.dart'; // put your Google Maps API key in keys.dart
// // // // // import 'package:flutter/material.dart';
// // // // // import 'package:firebase_auth/firebase_auth.dart';
// // // // // import 'package:firebase_database/firebase_database.dart';
// // // // // import 'package:geolocator/geolocator.dart';
// // // // // import 'package:google_maps_flutter/google_maps_flutter.dart';
// // // // // import 'package:audioplayers/audioplayers.dart';
// // // // // import 'package:http/http.dart' as http;

// // // // // const double baseFare = 100;
// // // // // const double perKmFare = 50;

// // // // // class LiveTrackingScreen extends StatefulWidget {
// // // // //   final String rideId;
// // // // //   final LatLng? pickup;
// // // // //   final LatLng? destination;

// // // // //   const LiveTrackingScreen({
// // // // //     super.key,
// // // // //     required this.rideId,
// // // // //     this.pickup,
// // // // //     this.destination,
// // // // //   });

// // // // //   @override
// // // // //   State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
// // // // // }

// // // // // class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
// // // // //   LatLng? _currentLocation;
// // // // //   GoogleMapController? _mapController;
// // // // //   Marker? _driverMarker;
// // // // //   Set<Polyline> _polylines = {};
// // // // //   double _distanceTraveledKm = 0;
// // // // //   bool _ended = false;
// // // // //   final DatabaseReference _rideRef = FirebaseDatabase.instance.ref();
// // // // //   final AudioPlayer _audioPlayer = AudioPlayer();
// // // // //   Timer? _locationTimer;

// // // // //   @override
// // // // //   void initState() {
// // // // //     super.initState();

// // // // //     if (widget.pickup != null && widget.destination != null) {
// // // // //       _loadRoute(widget.pickup!, widget.destination!);

// // // // //       _initTracking();
// // // // //     }
// // // // //   }

// // // // //   @override
// // // // //   void dispose() {
// // // // //     _locationTimer?.cancel();
// // // // //     _mapController?.dispose();
// // // // //     super.dispose();
// // // // //   }

// // // // //   /// Start location tracking like Uber
// // // // //   void _initTracking() {
// // // // //     _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
// // // // //       try {
// // // // //         Position pos = await Geolocator.getCurrentPosition(
// // // // //           desiredAccuracy: LocationAccuracy.best,
// // // // //         );
// // // // //         LatLng newLoc = LatLng(pos.latitude, pos.longitude);

// // // // //         if (_currentLocation != null) {
// // // // //           _distanceTraveledKm += _haversineKm(_currentLocation!, newLoc);
// // // // //         }

// // // // //         setState(() {
// // // // //           _currentLocation = newLoc;
// // // // //           _driverMarker = Marker(
// // // // //             markerId: const MarkerId("driver"),
// // // // //             position: newLoc,
// // // // //             icon: BitmapDescriptor.defaultMarkerWithHue(
// // // // //               BitmapDescriptor.hueBlue,
// // // // //             ),
// // // // //           );
// // // // //         });

// // // // //         // Smooth camera update
// // // // //         _mapController?.animateCamera(CameraUpdate.newLatLng(newLoc));

// // // // //         // Update Firebase driver location
// // // // //         FirebaseDatabase.instance
// // // // //             .ref('drivers/${FirebaseAuth.instance.currentUser!.uid}/location')
// // // // //             .set({
// // // // //               'lat': pos.latitude,
// // // // //               'lng': pos.longitude,
// // // // //               'timestamp': ServerValue.timestamp,
// // // // //             });

// // // // //         // Play alert near destination
// // // // //         if (widget.destination != null &&
// // // // //             _haversineKm(newLoc, widget.destination!) < 0.1) {
// // // // //           _audioPlayer.play(AssetSource('sounds/alert.mp3'));
// // // // //         }
// // // // //       } catch (e) {
// // // // //         debugPrint("Location tracking error: $e");
// // // // //       }
// // // // //     });
// // // // //   }

// // // // //   /// Fetch and draw polyline route
// // // // //   Future<void> _loadRoute(LatLng pickup, LatLng dest) async {
// // // // //     final url =
// // // // //         "https://maps.googleapis.com/maps/api/directions/json?origin=${pickup.latitude},${pickup.longitude}&destination=${dest.latitude},${dest.longitude}&mode=driving&key=$mapKey";

// // // // //     try {
// // // // //       final response = await http.get(Uri.parse(url));
// // // // //       final data = jsonDecode(response.body);

// // // // //       if (data['routes'].isNotEmpty) {
// // // // //         final points = data['routes'][0]['overview_polyline']['points'];
// // // // //         final decoded = _decodePolyline(points);

// // // // //         setState(() {
// // // // //           _polylines.add(
// // // // //             Polyline(
// // // // //               polylineId: const PolylineId("route"),
// // // // //               points: decoded,
// // // // //               color: Colors.blue,
// // // // //               width: 5,
// // // // //             ),
// // // // //           );
// // // // //         });
// // // // //       }
// // // // //     } catch (e) {
// // // // //       debugPrint("Error loading route: $e");
// // // // //     }
// // // // //   }

// // // // //   /// Decode Google polyline string
// // // // //   List<LatLng> _decodePolyline(String encoded) {
// // // // //     List<LatLng> polyline = [];
// // // // //     int index = 0, len = encoded.length;
// // // // //     int lat = 0, lng = 0;

// // // // //     while (index < len) {
// // // // //       int b, shift = 0, result = 0;
// // // // //       do {
// // // // //         b = encoded.codeUnitAt(index++) - 63;
// // // // //         result |= (b & 0x1F) << shift;
// // // // //         shift += 5;
// // // // //       } while (b >= 0x20);
// // // // //       int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
// // // // //       lat += dlat;

// // // // //       shift = 0;
// // // // //       result = 0;
// // // // //       do {
// // // // //         b = encoded.codeUnitAt(index++) - 63;
// // // // //         result |= (b & 0x1F) << shift;
// // // // //         shift += 5;
// // // // //       } while (b >= 0x20);
// // // // //       int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
// // // // //       lng += dlng;

// // // // //       polyline.add(LatLng(lat / 1E5, lng / 1E5));
// // // // //     }
// // // // //     return polyline;
// // // // //   }

// // // // //   /// End the ride
// // // // //   Future<void> _endRide() async {
// // // // //     if (_ended || _currentLocation == null) return;

// // // // //     try {
// // // // //       double fare = _computeFare(_distanceTraveledKm);

// // // // //       await _rideRef.child('rides/${widget.rideId}').update({
// // // // //         'status': 'completed',
// // // // //         'destination/lat': _currentLocation!.latitude,
// // // // //         'destination/lng': _currentLocation!.longitude,
// // // // //         'distanceKm': double.parse(_distanceTraveledKm.toStringAsFixed(2)),
// // // // //         'fare': double.parse(fare.toStringAsFixed(2)),
// // // // //         'endedAt': ServerValue.timestamp,
// // // // //       });

// // // // //       setState(() => _ended = true);

// // // // //       _showFareSheet(fare);
// // // // //     } catch (e) {
// // // // //       debugPrint("End ride error: $e");
// // // // //       ScaffoldMessenger.of(
// // // // //         context,
// // // // //       ).showSnackBar(SnackBar(content: Text("Error ending ride: $e")));
// // // // //     }
// // // // //   }

// // // // //   double _computeFare(double traveledKm) => baseFare + traveledKm * perKmFare;

// // // // //   double _haversineKm(LatLng a, LatLng b) {
// // // // //     const R = 6371.0;
// // // // //     final dLat = _degToRad(b.latitude - a.latitude);
// // // // //     final dLng = _degToRad(b.longitude - a.longitude);
// // // // //     final aa =
// // // // //         math.sin(dLat / 2) * math.sin(dLat / 2) +
// // // // //         math.cos(_degToRad(a.latitude)) *
// // // // //             math.cos(_degToRad(b.latitude)) *
// // // // //             math.sin(dLng / 2) *
// // // // //             math.sin(dLng / 2);
// // // // //     return R * 2 * math.atan2(math.sqrt(aa), math.sqrt(1 - aa));
// // // // //   }

// // // // //   double _degToRad(double d) => d * math.pi / 180.0;

// // // // //   void _showFareSheet(double fare) {
// // // // //     showModalBottomSheet(
// // // // //       context: context,
// // // // //       isDismissible: false,
// // // // //       enableDrag: false,
// // // // //       shape: const RoundedRectangleBorder(
// // // // //         borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
// // // // //       ),
// // // // //       builder:
// // // // //           (_) => Container(
// // // // //             padding: const EdgeInsets.all(24),
// // // // //             height: 240,
// // // // //             child: Column(
// // // // //               mainAxisAlignment: MainAxisAlignment.center,
// // // // //               children: [
// // // // //                 const Icon(Icons.check_circle, color: Colors.green, size: 48),
// // // // //                 const SizedBox(height: 16),
// // // // //                 const Text(
// // // // //                   'Trip Completed',
// // // // //                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
// // // // //                 ),
// // // // //                 const SizedBox(height: 8),
// // // // //                 Text('Distance: ${_distanceTraveledKm.toStringAsFixed(2)} km'),
// // // // //                 const SizedBox(height: 8),
// // // // //                 Text(
// // // // //                   'Fare: KES ${fare.toStringAsFixed(2)}',
// // // // //                   style: const TextStyle(
// // // // //                     fontSize: 20,
// // // // //                     fontWeight: FontWeight.bold,
// // // // //                     color: Colors.red,
// // // // //                   ),
// // // // //                 ),
// // // // //                 const SizedBox(height: 20),
// // // // //                 ElevatedButton(
// // // // //                   onPressed: () {
// // // // //                     Navigator.pop(context);
// // // // //                     Navigator.pop(context);
// // // // //                   },
// // // // //                   style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
// // // // //                   child: const Text("OK"),
// // // // //                 ),
// // // // //               ],
// // // // //             ),
// // // // //           ),
// // // // //     );
// // // // //   }

// // // // //   @override
// // // // //   Widget build(BuildContext context) {
// // // // //     return Scaffold(
// // // // //       appBar: AppBar(title: const Text('Live Ride Tracking')),
// // // // //       body:
// // // // //           _currentLocation == null
// // // // //               ? const Center(child: CircularProgressIndicator())
// // // // //               : GoogleMap(
// // // // //                 initialCameraPosition: CameraPosition(
// // // // //                   target: _currentLocation!,
// // // // //                   zoom: 16,
// // // // //                 ),
// // // // //                 markers: _driverMarker != null ? {_driverMarker!} : {},
// // // // //                 polylines: _polylines,
// // // // //                 myLocationEnabled: true,
// // // // //                 myLocationButtonEnabled: true,
// // // // //                 onMapCreated: (c) => _mapController = c,
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
// // // // // // import 'dart:math' as math;
// // // // // // import 'package:aminidriver/Container/utils/keys.dart';
// // // // // // import 'package:flutter/material.dart';
// // // // // // import 'package:firebase_auth/firebase_auth.dart';
// // // // // // import 'package:firebase_database/firebase_database.dart';
// // // // // // import 'package:geolocator/geolocator.dart';
// // // // // // import 'package:google_maps_flutter/google_maps_flutter.dart';
// // // // // // import 'package:audioplayers/audioplayers.dart';
// // // // // // import 'package:http/http.dart' as http;

// // // // // // const double baseFare = 100;
// // // // // // const double perKmFare = 50;

// // // // // // class LiveTrackingScreen extends StatefulWidget {
// // // // // //   final String rideId;
// // // // // //   final LatLng? pickup;
// // // // // //   final LatLng? destination;

// // // // // //   const LiveTrackingScreen({
// // // // // //     super.key,
// // // // // //     required this.rideId,
// // // // // //     this.pickup,
// // // // // //     this.destination,
// // // // // //   });

// // // // // //   @override
// // // // // //   State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
// // // // // // }

// // // // // // class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
// // // // // //   LatLng? _currentLocation;
// // // // // //   GoogleMapController? _mapController;
// // // // // //   Marker? _driverMarker;
// // // // // //   final Set<Polyline> _polylines = {};
// // // // // //   double _distanceTraveledKm = 0;
// // // // // //   bool _ended = false;
// // // // // //   final DatabaseReference _rideRef = FirebaseDatabase.instance.ref();
// // // // // //   final AudioPlayer _audioPlayer = AudioPlayer();
// // // // // //   StreamSubscription<Position>? _positionSub;

// // // // // //   @override
// // // // // //   void initState() {
// // // // // //     super.initState();
// // // // // //     _startLocationTracking();
// // // // // //   }

// // // // // //   @override
// // // // // //   void dispose() {
// // // // // //     _positionSub?.cancel();
// // // // // //     _mapController?.dispose();
// // // // // //     super.dispose();
// // // // // //   }

// // // // // //   void _startLocationTracking() {
// // // // // //     const settings = LocationSettings(
// // // // // //       accuracy: LocationAccuracy.high,
// // // // // //       distanceFilter: 10, // only update if moved >10m
// // // // // //     );

// // // // // //     _positionSub = Geolocator.getPositionStream(locationSettings: settings)
// // // // // //         .listen((Position pos) async {
// // // // // //       final newLoc = LatLng(pos.latitude, pos.longitude);

// // // // // //       if (_currentLocation != null) {
// // // // // //         _distanceTraveledKm += _haversineKm(_currentLocation!, newLoc);
// // // // // //       }

// // // // // //       setState(() {
// // // // // //         _currentLocation = newLoc;
// // // // // //         _driverMarker = Marker(
// // // // // //           markerId: const MarkerId("driver"),
// // // // // //           position: newLoc,
// // // // // //           icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
// // // // // //         );
// // // // // //       });

// // // // // //       // update DB (only every ~5s to save bandwidth)
// // // // // //       FirebaseDatabase.instance
// // // // // //           .ref('drivers/${FirebaseAuth.instance.currentUser!.uid}/location')
// // // // // //           .set({
// // // // // //         'lat': pos.latitude,
// // // // // //         'lng': pos.longitude,
// // // // // //         'timestamp': ServerValue.timestamp,
// // // // // //       });

// // // // // //       // Animate smoothly (like Uber)
// // // // // //       _mapController?.animateCamera(
// // // // // //         CameraUpdate.newLatLng(newLoc),
// // // // // //       );

// // // // // //       // Play alert near destination
// // // // // //       if (widget.destination != null &&
// // // // // //           _haversineKm(newLoc, widget.destination!) < 0.15) {
// // // // // //         _audioPlayer.play(AssetSource('sounds/alert.mp3'));
// // // // // //       }
// // // // // //     });
// // // // // //   }

// // // // // //   Future<void> _endRide() async {
// // // // // //     if (_ended || _currentLocation == null) return;

// // // // // //     final url = Uri.parse('$baseUrl/rides/${widget.rideId}/end');

// // // // // //     try {
// // // // // //       final response = await http.post(
// // // // // //         url,
// // // // // //         headers: {'Content-Type': 'application/json'},
// // // // // //         body: jsonEncode({
// // // // // //           'latitude': _currentLocation?.latitude,
// // // // // //           'longitude': _currentLocation?.longitude,
// // // // // //         }),
// // // // // //       );

// // // // // //       if (response.statusCode == 200) {
// // // // // //         double fare = _computeFare(_distanceTraveledKm);

// // // // // //         await _rideRef.child('rides/${widget.rideId}').update({
// // // // // //           'status': 'completed',
// // // // // //           'destination/lat': _currentLocation!.latitude,
// // // // // //           'destination/lng': _currentLocation!.longitude,
// // // // // //           'distanceKm': double.parse(_distanceTraveledKm.toStringAsFixed(2)),
// // // // // //           'fare': double.parse(fare.toStringAsFixed(2)),
// // // // // //           'endedAt': ServerValue.timestamp,
// // // // // //         });

// // // // // //         setState(() => _ended = true);
// // // // // //         _showFareSheet(fare);
// // // // // //       } else {
// // // // // //         throw Exception("Failed to end ride");
// // // // // //       }
// // // // // //     } catch (e) {
// // // // // //       debugPrint("End ride error: $e");
// // // // // //       if (mounted) {
// // // // // //         ScaffoldMessenger.of(context).showSnackBar(
// // // // // //           SnackBar(content: Text("Error ending ride: $e")),
// // // // // //         );
// // // // // //       }
// // // // // //     }
// // // // // //   }

// // // // // //   double _computeFare(double traveledKm) => baseFare + traveledKm * perKmFare;

// // // // // //   double _haversineKm(LatLng a, LatLng b) {
// // // // // //     const R = 6371.0;
// // // // // //     final dLat = _degToRad(b.latitude - a.latitude);
// // // // // //     final dLng = _degToRad(b.longitude - a.longitude);
// // // // // //     final aa = math.sin(dLat / 2) * math.sin(dLat / 2) +
// // // // // //         math.cos(_degToRad(a.latitude)) *
// // // // // //             math.cos(_degToRad(b.latitude)) *
// // // // // //             math.sin(dLng / 2) *
// // // // // //             math.sin(dLng / 2);
// // // // // //     return R * 2 * math.atan2(math.sqrt(aa), math.sqrt(1 - aa));
// // // // // //   }

// // // // // //   double _degToRad(double d) => d * math.pi / 180.0;

// // // // // //   void _showFareSheet(double fare) {
// // // // // //     if (!mounted) return;
// // // // // //     showModalBottomSheet(
// // // // // //       context: context,
// // // // // //       isDismissible: false,
// // // // // //       enableDrag: false,
// // // // // //       shape: const RoundedRectangleBorder(
// // // // // //         borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
// // // // // //       ),
// // // // // //       builder: (_) => Container(
// // // // // //         padding: const EdgeInsets.all(24),
// // // // // //         height: 220,
// // // // // //         child: Column(
// // // // // //           mainAxisAlignment: MainAxisAlignment.center,
// // // // // //           children: [
// // // // // //             const Icon(Icons.check_circle, color: Colors.green, size: 48),
// // // // // //             const SizedBox(height: 16),
// // // // // //             const Text(
// // // // // //               'Trip Completed',
// // // // // //               style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
// // // // // //             ),
// // // // // //             const SizedBox(height: 8),
// // // // // //             Text(
// // // // // //               'Distance: ${_distanceTraveledKm.toStringAsFixed(2)} km',
// // // // // //               style: const TextStyle(fontSize: 16),
// // // // // //             ),
// // // // // //             const SizedBox(height: 8),
// // // // // //             Text(
// // // // // //               'Amount: KES ${fare.toStringAsFixed(2)}',
// // // // // //               style: const TextStyle(
// // // // // //                 fontSize: 20,
// // // // // //                 fontWeight: FontWeight.bold,
// // // // // //                 color: Colors.red,
// // // // // //               ),
// // // // // //             ),
// // // // // //             const SizedBox(height: 16),
// // // // // //             ElevatedButton(
// // // // // //               onPressed: () {
// // // // // //                 Navigator.pop(context); // close bottom sheet
// // // // // //                 Navigator.pop(context); // back to main
// // // // // //               },
// // // // // //               style: ElevatedButton.styleFrom(
// // // // // //                 backgroundColor: Colors.red,
// // // // // //                 padding:
// // // // // //                     const EdgeInsets.symmetric(vertical: 12, horizontal: 32),
// // // // // //               ),
// // // // // //               child: const Text('Close', style: TextStyle(fontSize: 16)),
// // // // // //             ),
// // // // // //           ],
// // // // // //         ),
// // // // // //       ),
// // // // // //     );
// // // // // //   }

// // // // // //   @override
// // // // // //   Widget build(BuildContext context) {
// // // // // //     return Scaffold(
// // // // // //       appBar: AppBar(title: const Text('Live Ride Tracking'), centerTitle: true),
// // // // // //       body: _currentLocation == null
// // // // // //           ? const Center(child: CircularProgressIndicator())
// // // // // //           : GoogleMap(
// // // // // //               initialCameraPosition: CameraPosition(
// // // // // //                 target: _currentLocation!,
// // // // // //                 zoom: 16,
// // // // // //               ),
// // // // // //               markers: _driverMarker != null ? {_driverMarker!} : {},
// // // // // //               polylines: _polylines,
// // // // // //               myLocationEnabled: true,
// // // // // //               myLocationButtonEnabled: true,
// // // // // //               onMapCreated: (c) => _mapController = c,
// // // // // //             ),
// // // // // //       bottomNavigationBar: Padding(
// // // // // //         padding: const EdgeInsets.all(16),
// // // // // //         child: ElevatedButton(
// // // // // //           onPressed: _endRide,
// // // // // //           style: ElevatedButton.styleFrom(
// // // // // //             backgroundColor: Colors.red,
// // // // // //             padding: const EdgeInsets.symmetric(vertical: 16),
// // // // // //           ),
// // // // // //           child: const Text("End Ride"),
// // // // // //         ),
// // // // // //       ),
// // // // // //     );
// // // // // //   }
// // // // // // }
// // // // // // // import 'dart:async';
// // // // // // // import 'dart:convert';
// // // // // // // import 'dart:math' as math;
// // // // // // // import 'package:aminidriver/Container/utils/keys.dart';
// // // // // // // import 'package:flutter/material.dart';
// // // // // // // import 'package:firebase_auth/firebase_auth.dart';
// // // // // // // import 'package:firebase_database/firebase_database.dart';
// // // // // // // import 'package:geolocator/geolocator.dart';
// // // // // // // import 'package:google_maps_flutter/google_maps_flutter.dart';
// // // // // // // import 'package:audioplayers/audioplayers.dart';
// // // // // // // import 'package:http/http.dart' as http;

// // // // // // // const double baseFare = 100;
// // // // // // // const double perKmFare = 50;

// // // // // // // class LiveTrackingScreen extends StatefulWidget {
// // // // // // //   final String rideId;
// // // // // // //   final LatLng? pickup;
// // // // // // //   final LatLng? destination;

// // // // // // //   const LiveTrackingScreen({
// // // // // // //     super.key,
// // // // // // //     required this.rideId,
// // // // // // //     this.pickup,
// // // // // // //     this.destination,
// // // // // // //   });

// // // // // // //   @override
// // // // // // //   State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
// // // // // // // }

// // // // // // // class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
// // // // // // //   LatLng? _currentLocation;
// // // // // // //   GoogleMapController? _mapController;
// // // // // // //   Marker? _driverMarker;
// // // // // // //   Set<Polyline> _polylines = {};
// // // // // // //   double _distanceTraveledKm = 0;
// // // // // // //   bool _ended = false;
// // // // // // //   final DatabaseReference _rideRef = FirebaseDatabase.instance.ref();
// // // // // // //   final AudioPlayer _audioPlayer = AudioPlayer();
// // // // // // //   Timer? _locationTimer;

// // // // // // //   @override
// // // // // // //   void initState() {
// // // // // // //     super.initState();
// // // // // // //     _startLocationTracking();
// // // // // // //   }

// // // // // // //   @override
// // // // // // //   void dispose() {
// // // // // // //     _locationTimer?.cancel();
// // // // // // //     _mapController?.dispose();
// // // // // // //     super.dispose();
// // // // // // //   }

// // // // // // //   Future<void> checkOngoingTrip(BuildContext context) async {
// // // // // // //     final userId = FirebaseAuth.instance.currentUser!.uid;
// // // // // // //     final rideSnapshot =
// // // // // // //         await FirebaseDatabase.instance
// // // // // // //             .ref('rides')
// // // // // // //             .orderByChild('driverId')
// // // // // // //             .equalTo(userId)
// // // // // // //             .get();

// // // // // // //     if (rideSnapshot.exists) {
// // // // // // //       final rides = rideSnapshot.value as Map<dynamic, dynamic>;

// // // // // // //       MapEntry<dynamic, dynamic>? ongoingRide;
// // // // // // //       for (final entry in rides.entries) {
// // // // // // //         if (entry.value['status'] == 'in-progress') {
// // // // // // //           ongoingRide = entry;
// // // // // // //           break;
// // // // // // //         }
// // // // // // //       }

// // // // // // //       if (ongoingRide != null) {
// // // // // // //         final rideId = ongoingRide.key;
// // // // // // //         final pickupLat = ongoingRide.value['pickup']['lat'];
// // // // // // //         final pickupLng = ongoingRide.value['pickup']['lng'];
// // // // // // //         final destLat = ongoingRide.value['destination']['lat'];
// // // // // // //         final destLng = ongoingRide.value['destination']['lng'];

// // // // // // //         Navigator.pushReplacement(
// // // // // // //           context,
// // // // // // //           MaterialPageRoute(
// // // // // // //             builder:
// // // // // // //                 (_) => LiveTrackingScreen(
// // // // // // //                   rideId: rideId,
// // // // // // //                   pickup: LatLng(pickupLat, pickupLng),
// // // // // // //                   destination: LatLng(destLat, destLng),
// // // // // // //                 ),
// // // // // // //           ),
// // // // // // //         );
// // // // // // //       }
// // // // // // //     }
// // // // // // //   }

// // // // // // //   void _startLocationTracking() {
// // // // // // //     _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
// // // // // // //       Position pos = await Geolocator.getCurrentPosition();
// // // // // // //       LatLng newLoc = LatLng(pos.latitude, pos.longitude);

// // // // // // //       // Track distance
// // // // // // //       if (_currentLocation != null) {
// // // // // // //         _distanceTraveledKm += _haversineKm(_currentLocation!, newLoc);
// // // // // // //       }

// // // // // // //       setState(() {
// // // // // // //         _currentLocation = newLoc;
// // // // // // //         _driverMarker = Marker(
// // // // // // //           markerId: const MarkerId("driver"),
// // // // // // //           position: newLoc,
// // // // // // //           icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
// // // // // // //         );
// // // // // // //       });

// // // // // // //       // Animate camera to new location
// // // // // // //       _mapController?.animateCamera(CameraUpdate.newLatLng(newLoc));

// // // // // // //       // Update Firebase Realtime DB
// // // // // // //       FirebaseDatabase.instance
// // // // // // //           .ref('drivers/${FirebaseAuth.instance.currentUser!.uid}/location')
// // // // // // //           .set({
// // // // // // //             'lat': pos.latitude,
// // // // // // //             'lng': pos.longitude,
// // // // // // //             'timestamp': ServerValue.timestamp,
// // // // // // //           });
// // // // // // //       if (widget.destination != null &&
// // // // // // //           _haversineKm(newLoc, widget.destination!) < 0.1) {
// // // // // // //         _audioPlayer.play(AssetSource('sounds/alert.mp3'));
// // // // // // //       }
// // // // // // //       // // Play sound when near destination
// // // // // // //       // if (_haversineKm(newLoc, widget.destination!) < 0.1) {
// // // // // // //       //   _audioPlayer.play(AssetSource('sounds/alert.mp3'));
// // // // // // //       // }
// // // // // // //     });
// // // // // // //   }

// // // // // // //   Future<void> _endRide() async {
// // // // // // //     if (_ended || _currentLocation == null) return;
// // // // // // //     final user = FirebaseAuth.instance.currentUser;
// // // // // // //     final idToken = await user?.getIdToken();

// // // // // // //     final url = Uri.parse('$baseUrl/rides/${widget.rideId}/end');

// // // // // // //     try {
// // // // // // //       final response = await http.post(
// // // // // // //         url,
// // // // // // //         headers: {
// // // // // // //           'Content-Type': 'application/json',
// // // // // // //           //'Authorization': 'Bearer $idToken',
// // // // // // //         },
// // // // // // //         body: jsonEncode({
// // // // // // //           'latitude': _currentLocation?.latitude,
// // // // // // //           'longitude': _currentLocation?.longitude,
// // // // // // //         }),
// // // // // // //       );

// // // // // // //       if (response.statusCode == 200) {
// // // // // // //         // final rideRef = FirebaseDatabase.instance.ref("rides/${widget.rideId}");
// // // // // // //         // await rideRef.update({
// // // // // // //         //   "status": "completed",
// // // // // // //         //   "destination/lat": _currentLocation?.latitude,
// // // // // // //         //   "destination/lng": _currentLocation?.longitude,
// // // // // // //         //   "endTime": DateTime.now().toIso8601String(),

// // // // // // //         // });
// // // // // // //         double fare = _computeFare(_distanceTraveledKm);

// // // // // // //         await _rideRef.child('rides/${widget.rideId}').update({
// // // // // // //           'status': 'completed',
// // // // // // //           'destination/lat': _currentLocation!.latitude,
// // // // // // //           'destination/lng': _currentLocation!.longitude,
// // // // // // //           'distanceKm': double.parse(_distanceTraveledKm.toStringAsFixed(2)),
// // // // // // //           'fare': double.parse(fare.toStringAsFixed(2)),
// // // // // // //           'endedAt': ServerValue.timestamp,
// // // // // // //         });
// // // // // // //         setState(() => _ended = true);
// // // // // // //         //_showFareDialog(fare);
// // // // // // //         _showFareSheet(fare);

// // // // // // //         ScaffoldMessenger.of(context).showSnackBar(
// // // // // // //           const SnackBar(content: Text("Ride ended successfully")),
// // // // // // //         );
// // // // // // //         Navigator.pop(context); // go back after ending ride
// // // // // // //       } else {
// // // // // // //         throw Exception("Failed to end ride");
// // // // // // //       }
// // // // // // //     } catch (e) {
// // // // // // //       debugPrint("End ride error: $e");
// // // // // // //       ScaffoldMessenger.of(
// // // // // // //         context,
// // // // // // //       ).showSnackBar(SnackBar(content: Text("Error ending ride: $e")));
// // // // // // //     }
// // // // // // //   }

// // // // // // //   // Future<void> _endRide() async {
// // // // // // //   //   if (_ended || _currentLocation == null) return;

// // // // // // //   //   double fare = _computeFare(_distanceTraveledKm);

// // // // // // //   //   // Update Firebase ride node
// // // // // // //   //   await _rideRef.child('rides/${widget.rideId}').update({
// // // // // // //   //     'status': 'completed',
// // // // // // //   //     'destination/lat': _currentLocation!.latitude,
// // // // // // //   //     'destination/lng': _currentLocation!.longitude,
// // // // // // //   //     'distanceKm': double.parse(_distanceTraveledKm.toStringAsFixed(2)),
// // // // // // //   //     'fare': double.parse(fare.toStringAsFixed(2)),
// // // // // // //   //     'endedAt': ServerValue.timestamp,
// // // // // // //   //   });

// // // // // // //   //   setState(() => _ended = true);
// // // // // // //   //   //_showFareDialog(fare);
// // // // // // //   //   _showFareSheet(fare);
// // // // // // //   // }

// // // // // // //   double _computeFare(double traveledKm) => baseFare + traveledKm * perKmFare;

// // // // // // //   double _haversineKm(LatLng a, LatLng b) {
// // // // // // //     const R = 6371.0;
// // // // // // //     final dLat = _degToRad(b.latitude - a.latitude);
// // // // // // //     final dLng = _degToRad(b.longitude - a.longitude);
// // // // // // //     final s1 = math.sin(dLat / 2);
// // // // // // //     final s2 = math.sin(dLng / 2);
// // // // // // //     final aa =
// // // // // // //         s1 * s1 +
// // // // // // //         math.cos(_degToRad(a.latitude)) *
// // // // // // //             math.cos(_degToRad(b.latitude)) *
// // // // // // //             s2 *
// // // // // // //             s2;
// // // // // // //     return R * 2 * math.atan2(math.sqrt(aa), math.sqrt(1 - aa));
// // // // // // //   }

// // // // // // //   double _degToRad(double d) => d * math.pi / 180.0;

// // // // // // //   void _showFareDialog(double fare) {
// // // // // // //     showDialog(
// // // // // // //       context: context,
// // // // // // //       builder:
// // // // // // //           (_) => AlertDialog(
// // // // // // //             title: const Text('Trip Completed'),
// // // // // // //             content: Text(
// // // // // // //               'Distance: ${_distanceTraveledKm.toStringAsFixed(2)} km\n'
// // // // // // //               'Amount to pay: KES ${fare.toStringAsFixed(2)}',
// // // // // // //             ),
// // // // // // //             actions: [
// // // // // // //               TextButton(
// // // // // // //                 onPressed: () {
// // // // // // //                   Navigator.pop(context);
// // // // // // //                   Navigator.pop(context); // Back to main
// // // // // // //                 },
// // // // // // //                 child: const Text('Close'),
// // // // // // //               ),
// // // // // // //             ],
// // // // // // //           ),
// // // // // // //     );
// // // // // // //   }

// // // // // // //   void _showFareSheet(double fare) {
// // // // // // //     showModalBottomSheet(
// // // // // // //       context: context,
// // // // // // //       isDismissible: false,
// // // // // // //       enableDrag: false,
// // // // // // //       shape: const RoundedRectangleBorder(
// // // // // // //         borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
// // // // // // //       ),
// // // // // // //       builder:
// // // // // // //           (_) => Container(
// // // // // // //             padding: const EdgeInsets.all(24),
// // // // // // //             height: 220,
// // // // // // //             decoration: const BoxDecoration(
// // // // // // //               color: Colors.white,
// // // // // // //               borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
// // // // // // //             ),
// // // // // // //             child: Column(
// // // // // // //               mainAxisAlignment: MainAxisAlignment.center,
// // // // // // //               children: [
// // // // // // //                 const Icon(Icons.check_circle, color: Colors.green, size: 48),
// // // // // // //                 const SizedBox(height: 16),
// // // // // // //                 const Text(
// // // // // // //                   'Trip Completed',
// // // // // // //                   style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
// // // // // // //                 ),
// // // // // // //                 const SizedBox(height: 8),
// // // // // // //                 Text(
// // // // // // //                   'Distance: ${_distanceTraveledKm.toStringAsFixed(2)} km',
// // // // // // //                   style: const TextStyle(fontSize: 16),
// // // // // // //                 ),
// // // // // // //                 const SizedBox(height: 8),
// // // // // // //                 Text(
// // // // // // //                   'Amount to Pay: KES ${fare.toStringAsFixed(2)}',
// // // // // // //                   style: const TextStyle(
// // // // // // //                     fontSize: 20,
// // // // // // //                     fontWeight: FontWeight.bold,
// // // // // // //                     color: Colors.red,
// // // // // // //                   ),
// // // // // // //                 ),
// // // // // // //                 const SizedBox(height: 16),
// // // // // // //                 ElevatedButton(
// // // // // // //                   onPressed: () {
// // // // // // //                     Navigator.pop(context); // Close bottom sheet
// // // // // // //                     Navigator.pop(context); // Back to main screen
// // // // // // //                   },
// // // // // // //                   style: ElevatedButton.styleFrom(
// // // // // // //                     backgroundColor: Colors.red,
// // // // // // //                     padding: const EdgeInsets.symmetric(
// // // // // // //                       vertical: 12,
// // // // // // //                       horizontal: 32,
// // // // // // //                     ),
// // // // // // //                     shape: RoundedRectangleBorder(
// // // // // // //                       borderRadius: BorderRadius.circular(8),
// // // // // // //                     ),
// // // // // // //                   ),
// // // // // // //                   child: const Text('Close', style: TextStyle(fontSize: 16)),
// // // // // // //                 ),
// // // // // // //               ],
// // // // // // //             ),
// // // // // // //           ),
// // // // // // //     );
// // // // // // //   }

// // // // // // //   @override
// // // // // // //   Widget build(BuildContext context) {
// // // // // // //     return Scaffold(
// // // // // // //       appBar: AppBar(
// // // // // // //         title: const Text('Live Ride Tracking'),
// // // // // // //         centerTitle: true,
// // // // // // //       ),
// // // // // // //       body:
// // // // // // //           _currentLocation == null
// // // // // // //               ? const Center(child: CircularProgressIndicator())
// // // // // // //               : GoogleMap(
// // // // // // //                 initialCameraPosition: CameraPosition(
// // // // // // //                   target: _currentLocation!,
// // // // // // //                   zoom: 16,
// // // // // // //                 ),
// // // // // // //                 markers: _driverMarker != null ? {_driverMarker!} : {},
// // // // // // //                 polylines: _polylines,
// // // // // // //                 myLocationEnabled: true,
// // // // // // //                 myLocationButtonEnabled: true,
// // // // // // //                 onMapCreated: (c) => _mapController = c,
// // // // // // //               ),
// // // // // // //       bottomNavigationBar: Padding(
// // // // // // //         padding: const EdgeInsets.all(16),
// // // // // // //         child: ElevatedButton(
// // // // // // //           onPressed: _endRide,
// // // // // // //           style: ElevatedButton.styleFrom(
// // // // // // //             backgroundColor: Colors.red,
// // // // // // //             padding: const EdgeInsets.symmetric(vertical: 16),
// // // // // // //           ),
// // // // // // //           child: const Text("End Ride"),
// // // // // // //         ),
// // // // // // //       ),
// // // // // // //     );
// // // // // // //   }
// // // // // // // }

// // // // // // // // import 'dart:async';
// // // // // // // // import 'dart:convert';

// // // // // // // // import 'package:aminidriver/Container/utils/api_constant.dart';
// // // // // // // // import 'package:aminidriver/Container/utils/keys.dart';
// // // // // // // // import 'package:firebase_auth/firebase_auth.dart';
// // // // // // // // import 'package:firebase_database/firebase_database.dart';
// // // // // // // // import 'package:flutter/material.dart';
// // // // // // // // import 'package:geolocator/geolocator.dart';
// // // // // // // // import 'package:google_maps_flutter/google_maps_flutter.dart';
// // // // // // // // import 'package:http/http.dart' as http;

// // // // // // // // class LiveTrackingScreen extends StatefulWidget {
// // // // // // // //   final String rideId;

// // // // // // // //   const LiveTrackingScreen({required this.rideId, Key? key}) : super(key: key);

// // // // // // // //   @override
// // // // // // // //   _LiveTrackingScreenState createState() => _LiveTrackingScreenState();
// // // // // // // // }

// // // // // // // // class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
// // // // // // // //   LatLng? _currentLocation;
// // // // // // // //   Timer? _locationTimer;
// // // // // // // //   GoogleMapController? _mapController;
// // // // // // // //   Marker? _driverMarker;

// // // // // // // //   @override
// // // // // // // //   void initState() {
// // // // // // // //     super.initState();
// // // // // // // //     _startLocationTracking();
// // // // // // // //   }

// // // // // // // //   Future<void> _endRide() async {
// // // // // // // //     final user = FirebaseAuth.instance.currentUser;
// // // // // // // //     final idToken = await user?.getIdToken();

// // // // // // // //     final url = Uri.parse('$baseUrl/rides/${widget.rideId}/end');

// // // // // // // //     try {
// // // // // // // //       final response = await http.put(
// // // // // // // //         url,
// // // // // // // //         headers: {
// // // // // // // //           'Content-Type': 'application/json',
// // // // // // // //           'Authorization': 'Bearer $idToken',
// // // // // // // //         },
// // // // // // // //         body: jsonEncode({
// // // // // // // //           'latitude': _currentLocation?.latitude,
// // // // // // // //           'longitude': _currentLocation?.longitude,
// // // // // // // //         }),
// // // // // // // //       );

// // // // // // // //       if (response.statusCode == 200) {
// // // // // // // //         final rideRef = FirebaseDatabase.instance.ref("rides/${widget.rideId}");
// // // // // // // //         await rideRef.update({
// // // // // // // //           "status": "completed",
// // // // // // // //           "destination/lat": _currentLocation?.latitude,
// // // // // // // //           "destination/lng": _currentLocation?.longitude,
// // // // // // // //           "endTime": DateTime.now().toIso8601String(),

// // // // // // // //         });

// // // // // // // //         ScaffoldMessenger.of(context).showSnackBar(
// // // // // // // //           const SnackBar(content: Text("Ride ended successfully")),
// // // // // // // //         );
// // // // // // // //         Navigator.pop(context); // go back after ending ride
// // // // // // // //       } else {
// // // // // // // //         throw Exception("Failed to end ride");
// // // // // // // //       }
// // // // // // // //     } catch (e) {
// // // // // // // //       debugPrint("End ride error: $e");
// // // // // // // //       ScaffoldMessenger.of(
// // // // // // // //         context,
// // // // // // // //       ).showSnackBar(SnackBar(content: Text("Error ending ride: $e")));
// // // // // // // //     }
// // // // // // // //   }

// // // // // // // //   void _startLocationTracking() {
// // // // // // // //     _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
// // // // // // // //       Position pos = await Geolocator.getCurrentPosition();
// // // // // // // //       LatLng newLocation = LatLng(pos.latitude, pos.longitude);

// // // // // // // //       setState(() {
// // // // // // // //         _currentLocation = newLocation;
// // // // // // // //         _driverMarker = Marker(
// // // // // // // //           markerId: const MarkerId("driver"),
// // // // // // // //           position: newLocation,
// // // // // // // //           icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
// // // // // // // //         );
// // // // // // // //       });

// // // // // // // //       // Animate camera to new location
// // // // // // // //       if (_mapController != null) {
// // // // // // // //         _mapController!.animateCamera(CameraUpdate.newLatLng(newLocation));
// // // // // // // //       }

// // // // // // // //       // Update Firebase realtime DB
// // // // // // // //       FirebaseDatabase.instance
// // // // // // // //           .ref('drivers/${FirebaseAuth.instance.currentUser!.uid}/location')
// // // // // // // //           .set({
// // // // // // // //             'latitude': pos.latitude,
// // // // // // // //             'longitude': pos.longitude,
// // // // // // // //             'timestamp': ServerValue.timestamp,
// // // // // // // //           });
// // // // // // // //     });
// // // // // // // //   }

// // // // // // // //   @override
// // // // // // // //   void dispose() {
// // // // // // // //     _locationTimer?.cancel();
// // // // // // // //     _mapController?.dispose();
// // // // // // // //     super.dispose();
// // // // // // // //   }

// // // // // // // //   @override
// // // // // // // //   Widget build(BuildContext context) {
// // // // // // // //     return Scaffold(
// // // // // // // //       backgroundColor: Colors.white,
// // // // // // // //       appBar: AppBar(
// // // // // // // //         title: const Text("Live Ride Tracking"),
// // // // // // // //         centerTitle: true,
// // // // // // // //         backgroundColor: Colors.white,
// // // // // // // //         elevation: 0,
// // // // // // // //         foregroundColor: Colors.black,
// // // // // // // //       ),
// // // // // // // //       body:
// // // // // // // //           _currentLocation == null
// // // // // // // //               ? const Center(child: CircularProgressIndicator())
// // // // // // // //               : GoogleMap(
// // // // // // // //                 initialCameraPosition: CameraPosition(
// // // // // // // //                   target: _currentLocation!,
// // // // // // // //                   zoom: 16,
// // // // // // // //                 ),
// // // // // // // //                 myLocationEnabled: true,
// // // // // // // //                 myLocationButtonEnabled: true,
// // // // // // // //                 markers: _driverMarker != null ? {_driverMarker!} : {},
// // // // // // // //                 onMapCreated: (controller) => _mapController = controller,
// // // // // // // //               ),
// // // // // // // //       bottomNavigationBar: Padding(
// // // // // // // //         padding: const EdgeInsets.all(16),
// // // // // // // //         child: ElevatedButton(
// // // // // // // //           onPressed: _endRide,
// // // // // // // //           style: ElevatedButton.styleFrom(
// // // // // // // //             backgroundColor: Colors.red,
// // // // // // // //             padding: const EdgeInsets.symmetric(vertical: 16),
// // // // // // // //           ),
// // // // // // // //           child: const Text("End Ride"),
// // // // // // // //         ),
// // // // // // // //       ),
// // // // // // // //     );
// // // // // // // //   }
// // // // // // // // }

// // // // // // // // // import 'dart:async';
// // // // // // // // // import 'dart:convert';

// // // // // // // // // import 'package:aminidriver/Container/utils/api_constant.dart';
// // // // // // // // // import 'package:firebase_auth/firebase_auth.dart';
// // // // // // // // // import 'package:firebase_database/firebase_database.dart';
// // // // // // // // // import 'package:flutter/material.dart';
// // // // // // // // // import 'package:flutter/widgets.dart';
// // // // // // // // // import 'package:flutter_map/flutter_map.dart';
// // // // // // // // // import 'package:geolocator/geolocator.dart';
// // // // // // // // // import 'package:http/http.dart' as http;
// // // // // // // // // import 'package:latlong2/latlong.dart';

// // // // // // // // // class LiveTrackingScreen extends StatefulWidget {
// // // // // // // // //   final String rideId;

// // // // // // // // //   const LiveTrackingScreen({required this.rideId});

// // // // // // // // //   @override
// // // // // // // // //   _LiveTrackingScreenState createState() => _LiveTrackingScreenState();
// // // // // // // // // }

// // // // // // // // // class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
// // // // // // // // //   LatLng? _currentLocation;
// // // // // // // // //   Timer? _locationTimer;

// // // // // // // // //   @override
// // // // // // // // //   void initState() {
// // // // // // // // //     super.initState();
// // // // // // // // //     _startLocationTracking();
// // // // // // // // //   }

// // // // // // // // //   Future<void> _endRide() async {
// // // // // // // // //     final user = FirebaseAuth.instance.currentUser;
// // // // // // // // //     final idToken = await user?.getIdToken();

// // // // // // // // //     final url = Uri.parse('$baseUrl/rides/${widget.rideId}/end');

// // // // // // // // //     try {
// // // // // // // // //       final response = await http.put(
// // // // // // // // //         url,
// // // // // // // // //         headers: {
// // // // // // // // //           'Content-Type': 'application/json',
// // // // // // // // //           //'Authorization': 'Bearer $idToken',
// // // // // // // // //         },
// // // // // // // // //         body: jsonEncode({
// // // // // // // // //           'latitude': _currentLocation!.latitude,
// // // // // // // // //           'longitude': _currentLocation!.longitude,
// // // // // // // // //         }),
// // // // // // // // //       );

// // // // // // // // //       if (response.statusCode == 200) {
// // // // // // // // //         ScaffoldMessenger.of(context).showSnackBar(
// // // // // // // // //           const SnackBar(content: Text("Ride started successfully")),
// // // // // // // // //         );

// // // // // // // // //         // Optional: Navigate to live tracking screen or update UI state
// // // // // // // // //       } else {
// // // // // // // // //         throw Exception("Failed to start ride");
// // // // // // // // //       }
// // // // // // // // //     } catch (e) {
// // // // // // // // //       debugPrint("Start ride error: $e");
// // // // // // // // //       ScaffoldMessenger.of(
// // // // // // // // //         context,
// // // // // // // // //       ).showSnackBar(SnackBar(content: Text("Error starting ride: $e")));
// // // // // // // // //     }
// // // // // // // // //   }

// // // // // // // // //   void _startLocationTracking() {
// // // // // // // // //     _locationTimer = Timer.periodic(Duration(seconds: 5), (_) async {
// // // // // // // // //       Position pos = await Geolocator.getCurrentPosition();
// // // // // // // // //       setState(() {
// // // // // // // // //         _currentLocation = LatLng(pos.latitude, pos.longitude);
// // // // // // // // //       });

// // // // // // // // //       // Optionally send location to backend or Firebase
// // // // // // // // //       FirebaseDatabase.instance
// // // // // // // // //           .ref('drivers/${FirebaseAuth.instance.currentUser!.uid}/location')
// // // // // // // // //           .set({
// // // // // // // // //             'latitude': pos.latitude,
// // // // // // // // //             'longitude': pos.longitude,
// // // // // // // // //             'timestamp': ServerValue.timestamp,
// // // // // // // // //           });
// // // // // // // // //     });
// // // // // // // // //   }

// // // // // // // // //   @override
// // // // // // // // //   void dispose() {
// // // // // // // // //     _locationTimer?.cancel();
// // // // // // // // //     super.dispose();
// // // // // // // // //   }

// // // // // // // // //   @override
// // // // // // // // //   Widget build(BuildContext context) {
// // // // // // // // //     return Scaffold(
// // // // // // // // //       backgroundColor: Colors.white,
// // // // // // // // //       appBar: AppBar(
// // // // // // // // //         title: Text("Live Ride Tracking"),
// // // // // // // // //         centerTitle: true,
// // // // // // // // //         backgroundColor: Colors.white,
// // // // // // // // //         elevation: 0,
// // // // // // // // //         foregroundColor: Colors.black,
// // // // // // // // //       ),
// // // // // // // // //       body:
// // // // // // // // //           _currentLocation == null
// // // // // // // // //               ? Center(child: CircularProgressIndicator())
// // // // // // // // //               : FlutterMap(
// // // // // // // // //                 options: MapOptions(center: _currentLocation, zoom: 16),
// // // // // // // // //                 children: [
// // // // // // // // //                   TileLayer(
// // // // // // // // //                     urlTemplate:
// // // // // // // // //                         "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
// // // // // // // // //                   ),
// // // // // // // // //                   MarkerLayer(
// // // // // // // // //                     markers: [
// // // // // // // // //                       Marker(
// // // // // // // // //                         point: _currentLocation!,
// // // // // // // // //                         width: 40,
// // // // // // // // //                         height: 40,
// // // // // // // // //                         builder:
// // // // // // // // //                             (context) =>
// // // // // // // // //                                 Icon(Icons.local_taxi, color: Colors.blue),
// // // // // // // // //                       ),
// // // // // // // // //                     ],
// // // // // // // // //                   ),
// // // // // // // // //                 ],
// // // // // // // // //               ),
// // // // // // // // //       bottomNavigationBar: Padding(
// // // // // // // // //         padding: EdgeInsets.all(16),
// // // // // // // // //         child: ElevatedButton(
// // // // // // // // //           onPressed: () {
// // // // // // // // //             // Trigger end ride API
// // // // // // // // //           },
// // // // // // // // //           child: Text("End Ride"),
// // // // // // // // //         ),
// // // // // // // // //       ),
// // // // // // // // //     );
// // // // // // // // //   }
// // // // // // // // // }
