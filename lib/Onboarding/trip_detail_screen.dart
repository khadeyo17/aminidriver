import 'dart:convert';
import 'dart:math';
import 'package:aminidriver/Container/utils/api_constant.dart';
import 'package:aminidriver/Container/utils/keys.dart';
import 'package:aminidriver/Onboarding/live_tracking_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
//import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class TripDetailScreen extends StatefulWidget {
  final String rideId;
  final String rider;
  final String pickupName;
  final String destinationName;
  final double pickupLat;
  final double pickupLng;
  final double destLat;
  final double destLng;

  const TripDetailScreen({
    required this.rideId,
    required this.pickupName,
    required this.destinationName,
    required this.pickupLat,
    required this.pickupLng,
    required this.destLat,
    required this.destLng,
    required this.rider,
    Key? key,
  }) : super(key: key);

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  // final MapController _mapController = MapController();
  // List<LatLng> _routePoints = [];
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  double? _distance;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _startRide() async {
    final user = FirebaseAuth.instance.currentUser;
    final idToken = await user?.getIdToken();

    final url = Uri.parse('$baseUrl/rides/${widget.rideId}/start');

    try {
      // 1. Call backend API
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken', // add back if you secure API
        },
        body: jsonEncode({"startTime": DateTime.now().toIso8601String()}),
      );

      if (response.statusCode == 200) {
        // 2. Update Firebase Realtime DB
        final rideRef = FirebaseDatabase.instance.ref("rides/${widget.rideId}");
        await rideRef.update({
          "status": "in_progress",
          "driverId": user?.uid,
          "pickup": {
            "lat": widget.pickupLat,
            "lng": widget.pickupLng,
            "name": widget.pickupName,
          },
          "destination": {
            "lat": widget.destLat,
            "lng": widget.destLng,
            "name": widget.destinationName,
          },
          "startTime": DateTime.now().toIso8601String(),
        });

        // 3. Notify driver
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Ride started successfully")),
        );

        // 4. Navigate driver to live tracking
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => LiveTrackingScreen(rideId: widget.rideId),
          ),
        );
      } else {
        throw Exception("Failed to start ride");
      }
    } catch (e) {
      debugPrint("Start ride error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error starting ride: $e")));
    }
  }

  Future<void> _loadRoute() async {
    final start = LatLng(widget.pickupLat, widget.pickupLng);
    final end = LatLng(widget.destLat, widget.destLng);

    final apiKey = mapKey;
    final url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&mode=driving&key=$apiKey";

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        if ((data["routes"] as List).isEmpty) return;

        final points = data["routes"][0]["overview_polyline"]["points"];
        final distance =
            data["routes"][0]["legs"][0]["distance"]["value"] / 1000;

        final polylinePoints = PolylinePoints().decodePolyline(points);

        setState(() {
          _distance = distance;
          _polylines.add(
            Polyline(
              polylineId: const PolylineId("route"),
              color: Colors.blue,
              width: 5,
              points:
                  polylinePoints
                      .map((p) => LatLng(p.latitude, p.longitude))
                      .toList(),
            ),
          );

          _markers.add(
            Marker(
              markerId: const MarkerId("pickup"),
              position: start,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
              infoWindow: InfoWindow(title: widget.pickupName),
            ),
          );

          _markers.add(
            Marker(
              markerId: const MarkerId("destination"),
              position: end,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen,
              ),
              infoWindow: InfoWindow(title: widget.destinationName),
            ),
          );
        });

        _mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(southwest: start, northeast: end),
            80,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error loading route: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final pickup = LatLng(widget.pickupLat, widget.pickupLng);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Trip Details",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // MAP
          Expanded(
            flex: 2,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: pickup, zoom: 14),
              onMapCreated: (controller) => _mapController = controller,
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: SingleChildScrollView(
                    // ✅ Prevent overflow
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Rider + ID
                        Text(
                          "Ride ID: ${widget.rideId}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Rider: ${widget.rider}",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Pickup + Destination
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Pickup: ${widget.pickupName}",
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.flag,
                              color: Colors.green,
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Destination: ${widget.destinationName}",
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Distance
                        if (_distance != null)
                          Text(
                            "Distance: ${_distance!.toStringAsFixed(2)} km",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: Colors.blueAccent,
                            ),
                          ),

                        const SizedBox(height: 20),

                        // Start Ride Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _startRide,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Start Ride",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // DETAILS CARD
          // Expanded(
          //   flex: 1,
          //   child: Container(
          //     width: double.infinity,
          //     decoration: const BoxDecoration(
          //       color: Colors.white,
          //       borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          //       boxShadow: [
          //         BoxShadow(
          //           color: Colors.black12,
          //           blurRadius: 10,
          //           offset: Offset(0, -4),
          //         ),
          //       ],
          //     ),
          //     child: Padding(
          //       padding: const EdgeInsets.all(20.0),
          //       child: Column(
          //         crossAxisAlignment: CrossAxisAlignment.start,
          //         children: [
          //           // Rider + ID
          //           Text(
          //             "Ride ID: ${widget.rideId}",
          //             style: const TextStyle(
          //               fontSize: 18,
          //               fontWeight: FontWeight.bold,
          //               color: Colors.black54,
          //             ),
          //           ),
          //           const SizedBox(height: 8),
          //           Text(
          //             "Rider: ${widget.rider}",
          //             style: const TextStyle(
          //               fontSize: 22,
          //               fontWeight: FontWeight.w600,
          //               color: Colors.black87,
          //             ),
          //           ),
          //           const SizedBox(height: 16),

          //           // Pickup + Destination
          //           Row(
          //             crossAxisAlignment: CrossAxisAlignment.start,
          //             children: [
          //               const Icon(
          //                 Icons.location_on,
          //                 color: Colors.red,
          //                 size: 28,
          //               ),
          //               const SizedBox(width: 8),
          //               Expanded(
          //                 child: Text(
          //                   "Pickup: ${widget.pickupName}",
          //                   style: const TextStyle(fontSize: 18),
          //                 ),
          //               ),
          //             ],
          //           ),
          //           const SizedBox(height: 10),
          //           Row(
          //             crossAxisAlignment: CrossAxisAlignment.start,
          //             children: [
          //               const Icon(Icons.flag, color: Colors.green, size: 28),
          //               const SizedBox(width: 8),
          //               Expanded(
          //                 child: Text(
          //                   "Destination: ${widget.destinationName}",
          //                   style: const TextStyle(fontSize: 18),
          //                 ),
          //               ),
          //             ],
          //           ),
          //           const SizedBox(height: 16),

          //           // Distance
          //           if (_distance != null)
          //             Text(
          //               "Distance: ${_distance!.toStringAsFixed(2)} km",
          //               style: const TextStyle(
          //                 fontSize: 20,
          //                 fontWeight: FontWeight.w500,
          //                 color: Colors.blueAccent,
          //               ),
          //             ),

          //           const Spacer(),

          //           // START RIDE BUTTON
          //           SizedBox(
          //             width: double.infinity,
          //             child: ElevatedButton(
          //               onPressed: _startRide,
          //               style: ElevatedButton.styleFrom(
          //                 backgroundColor: Colors.blueAccent,
          //                 padding: const EdgeInsets.symmetric(vertical: 16),
          //                 shape: RoundedRectangleBorder(
          //                   borderRadius: BorderRadius.circular(12),
          //                 ),
          //               ),
          //               child: const Text(
          //                 "Start Ride",
          //                 style: TextStyle(
          //                   fontSize: 20,
          //                   fontWeight: FontWeight.bold,
          //                   color: Colors.white,
          //                 ),
          //               ),
          //             ),
          //           ),
          //         ],
          //       ),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }
}

//   @override
//   Widget build(BuildContext context) {
//     final pickup = LatLng(widget.pickupLat, widget.pickupLng);

//     return Scaffold(
//       appBar: AppBar(title: const Text("Trip Details"), centerTitle: true),
//       body: Column(
//         children: [
//           Expanded(
//             flex: 2,
//             child: GoogleMap(
//               initialCameraPosition: CameraPosition(target: pickup, zoom: 14),
//               onMapCreated: (controller) => _mapController = controller,
//               markers: _markers,
//               polylines: _polylines,
//               myLocationEnabled: true,
//               myLocationButtonEnabled: true,
//             ),
//           ),
//           Expanded(
//             flex: 1,
//             child: Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     "Ride ID: ${widget.rideId}",
//                     style: const TextStyle(fontWeight: FontWeight.bold),
//                   ),
//                   Text("Rider: ${widget.rider}"),
//                   Text("Pickup: ${widget.pickupName}"),
//                   Text("Destination: ${widget.destinationName}"),
//                   if (_distance != null)
//                     Text("Distance: ${_distance!.toStringAsFixed(2)} km"),
//                   const SizedBox(height: 10),
//                   ElevatedButton(
//                     onPressed: _startRide,
//                     child: const Text("Start Ride"),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

//   Future<void> _loadRoute() async {
//     final start = LatLng(widget.pickupLat, widget.pickupLng);
//     final end = LatLng(widget.destLat, widget.destLng);

//     final url =
//         'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';

//     try {
//       final res = await http.get(Uri.parse(url));
//       if (res.statusCode == 200) {
//         final data = jsonDecode(res.body);
//         final coords = data['routes'][0]['geometry']['coordinates'] as List;
//         final distance = data['routes'][0]['distance'] / 1000;

//         setState(() {
//           _routePoints = coords.map((c) => LatLng(c[1], c[0])).toList();
//           _distance = distance;
//         });

//         _fitMapBounds(start, end);
//       } else {
//         throw Exception('Failed to load route');
//       }
//     } catch (e) {
//       debugPrint('Error loading route: $e');
//     }
//   }

//   void _fitMapBounds(LatLng start, LatLng end) {
//     final bounds = LatLngBounds(
//       LatLng(
//         min(start.latitude, end.latitude),
//         min(start.longitude, end.longitude),
//       ),
//       LatLng(
//         max(start.latitude, end.latitude),
//         max(start.longitude, end.longitude),
//       ),
//     );

//     _mapController.fitBounds(
//       bounds,
//       options: const FitBoundsOptions(padding: EdgeInsets.all(50)),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final pickupPoint = LatLng(widget.pickupLat, widget.pickupLng);
//     final destinationPoint = LatLng(widget.destLat, widget.destLng);
//     final bool isDark = Theme.of(context).brightness == Brightness.dark;
//     final Color textColor = isDark ? Colors.white : Colors.black;
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         title: const Text("Trip Details"),
//         centerTitle: true,
//         backgroundColor: Colors.white,
//         elevation: 0,
//         foregroundColor: Colors.black,
//       ),
//       body: Column(
//         children: [
//           Expanded(
//             flex: 2,
//             child: FlutterMap(
//               mapController: _mapController,
//               options: MapOptions(center: pickupPoint, zoom: 14.0),
//               children: [
//                 TileLayer(
//                   urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
//                   userAgentPackageName: 'com.example.aminidriver',
//                 ),
//                 if (_routePoints.isNotEmpty)
//                   PolylineLayer(
//                     polylines: [
//                       Polyline(
//                         points: _routePoints,
//                         strokeWidth: 4.0,
//                         color: Colors.blue,
//                       ),
//                     ],
//                   ),
//                 MarkerLayer(
//                   markers: [
//                     Marker(
//                       point: pickupPoint,
//                       width: 40,
//                       height: 40,
//                       builder:
//                           (context) => Icon(
//                             Icons.location_pin,
//                             color: Colors.red,
//                             size: 40,
//                           ),
//                     ),
//                     Marker(
//                       point: destinationPoint,
//                       width: 40,
//                       height: 40,
//                       builder:
//                           (context) =>
//                               Icon(Icons.flag, color: Colors.green, size: 40),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//           Expanded(
//             flex: 1,
//             child: Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     "Ride ID: ${widget.rideId}",
//                     style: const TextStyle(fontWeight: FontWeight.bold),
//                   ),

//                   const SizedBox(height: 8),
//                   Text("Rider: ${widget.rider}"),
//                   Text("Pickup: ${widget.pickupName}"),
//                   Text("Destination: ${widget.destinationName}"),
//                   if (_distance != null)
//                     Text("Distance: ${_distance!.toStringAsFixed(2)} km"),

//                   SizedBox(
//                     width: double.infinity,
//                     child: ElevatedButton(
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.grey[700],
//                         foregroundColor: Colors.white,
//                         padding: const EdgeInsets.symmetric(vertical: 16),
//                       ),
//                       onPressed: () {
//                         // Launch turn-by-turn nav or start logic
//                       },
//                       child: const Text("Navigate"),
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   SizedBox(
//                     width: double.infinity,
//                     child: ElevatedButton(
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.grey[700],
//                         foregroundColor: Colors.white,
//                         padding: const EdgeInsets.symmetric(vertical: 16),
//                       ),
//                       onPressed: _startRide,
//                       child: const Text("Start Ride"),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
