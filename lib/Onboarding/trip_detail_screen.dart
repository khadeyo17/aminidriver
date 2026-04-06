import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:aminidriver/Container/utils/keys.dart';
import 'package:aminidriver/Onboarding/live_tracking_screen.dart';
import 'package:aminidriver/Onboarding/signal_connection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class TripDetailScreen extends StatefulWidget {
  final String rideId;
  final String? rider;
  final String? riderId;
  final String? pickupName;
  final String? destinationName;
  final String? mobile;
  final double pickupLat;
  final double pickupLng;
  final double destLat;
  final double destLng;

  const TripDetailScreen({
    required this.rideId,
    this.pickupName,
    this.destinationName,
    this.mobile,
    required this.pickupLat,
    required this.pickupLng,
    required this.destLat,
    required this.destLng,
    this.rider,
    this.riderId,
    Key? key,
  }) : super(key: key);

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  LatLng? _driverPosition;
  StreamSubscription<Position>? _positionStream;
  SignalRService? _signalR;
  bool _isStartingRide = false;

  @override
  void initState() {
    super.initState();
    _initSignalR();
    _loadRoute();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _signalR?.leaveRideGroup(widget.rideId);
    super.dispose();
  }

  Future<void> _initSignalR() async {
    _signalR = SignalRService();
    await _signalR!.init();

    // Listen to driver location updates from SignalR
    _signalR!.onDriverLocationUpdate((data) {
      if (data == null) return;
      final lat = (data.latitude as num).toDouble();
      final lng = (data.longitude as num).toDouble();
      _updateDriverPosition(LatLng(lat, lng));
    });

    await _signalR!.joinRideGroup(widget.rideId);
  }

  void _updateDriverPosition(LatLng pos) {
    _driverPosition = pos;

    _markers.removeWhere((m) => m.markerId.value == 'driver');
    _markers.add(
      Marker(
        markerId: const MarkerId('driver'),
        position: _driverPosition!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: "You"),
      ),
    );

    // Smooth camera movement
    _mapController?.animateCamera(CameraUpdate.newLatLng(_driverPosition!));

    setState(() {});
  }

  void _startSendingLocation(String driverId) {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) async {
      final pos = LatLng(position.latitude, position.longitude);
      _updateDriverPosition(pos);

      await _signalR?.updateDriverLocation(
        widget.rideId,
        position.latitude,
        position.longitude,
        driverId,
      );
    });
  }

  Future<void> _startRide() async {
    setState(() => _isStartingRide = true);
    final driverId = FirebaseAuth.instance.currentUser!.uid;
    final url = Uri.parse('$baseUrl/rides/${widget.rideId}/start');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"startTime": DateTime.now().toIso8601String()}),
      );

      if (response.statusCode == 200) {
        // Start sending location to SignalR
        _startSendingLocation(driverId);

        // Navigate to LiveTrackingScreen and keep the current state alive
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => LiveTrackingScreen(
                  rideId: widget.rideId,
                  pickup: LatLng(widget.pickupLat, widget.pickupLng),
                  destination: LatLng(widget.destLat, widget.destLng),
                ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to start ride: ${response.statusCode}"),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isStartingRide = false);
    }
  }

  // Future<void> _startRide() async {
  //   setState(() => _isStartingRide = true);
  //   final driverId = FirebaseAuth.instance.currentUser!.uid;
  //   final url = Uri.parse('$baseUrl/rides/${widget.rideId}/start');

  //   try {
  //     final response = await http.post(
  //       url,
  //       headers: {'Content-Type': 'application/json'},
  //       body: jsonEncode({"startTime": DateTime.now().toIso8601String()}),
  //     );

  //     if (response.statusCode == 200) {
  //       _startSendingLocation(driverId);

  //       Navigator.pushReplacement(
  //         context,
  //         MaterialPageRoute(
  //           builder:
  //               (_) => LiveTrackingScreen(
  //                 rideId: widget.rideId,
  //                 pickup: LatLng(widget.pickupLat, widget.pickupLng),
  //                 destination: LatLng(widget.destLat, widget.destLng),
  //               ),
  //         ),
  //       );
  //     }
  //   } catch (e) {
  //     setState(() => _isStartingRide = false);
  //     ScaffoldMessenger.of(
  //       context,
  //     ).showSnackBar(SnackBar(content: Text("Error: $e")));
  //   }
  // }

  Future<void> _loadRoute() async {
    final start = LatLng(widget.pickupLat, widget.pickupLng);
    final end = LatLng(widget.destLat, widget.destLng);

    final url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&key=$mapKey";

    final res = await http.get(Uri.parse(url));
    final data = jsonDecode(res.body);

    if ((data["routes"] as List).isEmpty) return;

    final points = data["routes"][0]["overview_polyline"]["points"];
    final polylinePoints = PolylinePoints().decodePolyline(points);

    _polylines.add(
      Polyline(
        polylineId: const PolylineId("route"),
        color: Colors.blueAccent,
        width: 5,
        points:
            polylinePoints.map((p) => LatLng(p.latitude, p.longitude)).toList(),
      ),
    );

    // Add pickup and destination markers
    _markers.addAll([
      Marker(
        markerId: const MarkerId("pickup"),
        position: start,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: widget.pickupName),
      ),
      Marker(
        markerId: const MarkerId("destination"),
        position: end,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: widget.destinationName),
      ),
    ]);

    setState(() {});
  }

  Future<BitmapDescriptor> _createCustomMarker(String label) async {
    final pictureRecorder = PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final paint = Paint()..color = Colors.green;
    canvas.drawCircle(Offset(50, 50), 50, paint);

    // Draw text
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 20,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(15, 40));

    final image = await pictureRecorder.endRecording().toImage(100, 100);
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    final pickup = LatLng(widget.pickupLat, widget.pickupLng);
    final destination = LatLng(widget.destLat, widget.destLng);

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: pickup, zoom: 14),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            zoomControlsEnabled: false,
            onMapCreated: (controller) => _mapController = controller,
          ),

          // Floating top banner with pickup/destination
          Positioned(
            top: 60,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white70,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Pickup",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(widget.pickupName ?? ""),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        "Destination",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(widget.destinationName ?? ""),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom draggable sheet
          DraggableScrollableSheet(
            initialChildSize: 0.42,
            minChildSize: 0.32,
            maxChildSize: 0.65,
            builder: (_, controller) {
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  controller: controller,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _dragHandle(),
                      const SizedBox(height: 16),
                      _driverCard(),
                      const SizedBox(height: 20),
                      _locationTile(
                        Icons.circle,
                        Colors.green,
                        widget.pickupName ?? "",
                      ),
                      const SizedBox(height: 10),
                      _locationTile(
                        Icons.location_on,
                        Colors.red,
                        widget.destinationName ?? "",
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _infoChip(Icons.timer, "5 min"),
                          _infoChip(Icons.attach_money, "UGX 4500"),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(child: _actionButton(Icons.call, "Call")),
                          const SizedBox(width: 12),
                          Expanded(child: _actionButton(Icons.chat, "Chat")),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isStartingRide ? null : _startRide,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C853),
                            minimumSize: const Size(double.infinity, 55),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child:
                              _isStartingRide
                                  ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                  : const Text(
                                    "Start Ride",
                                    style: TextStyle(fontSize: 18),
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _dragHandle() => Center(
    child: Container(
      height: 5,
      width: 50,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(10),
      ),
    ),
  );

  Widget _driverCard() => Row(
    children: [
      CircleAvatar(
        radius: 28,
        backgroundColor: Colors.grey[300],
        child: const Icon(Icons.person, size: 30),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.rider ?? "Driver",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              children: const [
                Icon(Icons.star, color: Colors.amber, size: 16),
                SizedBox(width: 4),
                Text("4.8"),
                SizedBox(width: 10),
                Text("Toyota Prius • UBA 123A"),
              ],
            ),
          ],
        ),
      ),
    ],
  );

  Widget _locationTile(IconData icon, Color color, String title) => Row(
    children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(title)),
    ],
  );

  Widget _infoChip(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F1F1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(text)],
    ),
  );

  Widget _actionButton(IconData icon, String label) => Container(
    height: 50,
    decoration: BoxDecoration(
      color: Colors.black,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    ),
  );
}

// import 'dart:async';
// import 'dart:convert';
// import 'package:aminidriver/Container/utils/keys.dart';
// import 'package:aminidriver/Onboarding/live_tracking_screen.dart';
// import 'package:aminidriver/Onboarding/signal_connection.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_polyline_points/flutter_polyline_points.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:http/http.dart' as http;

// class TripDetailScreen extends StatefulWidget {
//   final String rideId;
//   final String? rider;
//   final String? riderId;
//   final String? pickupName;
//   final String? destinationName;
//   final String? mobile;
//   final double pickupLat;
//   final double pickupLng;
//   final double destLat;
//   final double destLng;

//   const TripDetailScreen({
//     required this.rideId,
//     this.pickupName,
//     this.destinationName,
//     this.mobile,
//     required this.pickupLat,
//     required this.pickupLng,
//     required this.destLat,
//     required this.destLng,
//     this.rider,
//     this.riderId,
//     Key? key,
//   }) : super(key: key);

//   @override
//   State<TripDetailScreen> createState() => _TripDetailScreenState();
// }

// class _TripDetailScreenState extends State<TripDetailScreen> {
//   GoogleMapController? _mapController;
//   Set<Polyline> _polylines = {};
//   Set<Marker> _markers = {};
//   double? _distance;

//   bool _isStartingRide = false;
//   int _etaMinutes = 5;
//   double _fare = 4500;

//   LatLng? _driverPosition;
//   SignalRService? _signalR;
//   StreamSubscription<Position>? _positionStream;

//   @override
//   void initState() {
//     super.initState();
//     _initSignalR();
//     _loadRoute();
//   }

//   @override
//   void dispose() {
//     _positionStream?.cancel();
//     _signalR?.leaveRideGroup(widget.rideId);
//     super.dispose();
//   }

//   Future<void> _initSignalR() async {
//     try {
//       _signalR = SignalRService();

//       // Initialize the SignalR connection with Firebase JWT
//       await _signalR!.init();

//       // Listen to driver location updates from SignalR
//       _signalR!.onDriverLocationUpdate((data) {
//         if (data == null) return;

//         // SignalR might send numbers as double or int
//         final lat = (data.latitude as num).toDouble();
//         final lng = (data.longitude as num).toDouble();

//         setState(() {
//           _driverPosition = LatLng(lat, lng);

//           // Update driver marker
//           _markers.removeWhere((m) => m.markerId.value == 'driver');
//           _markers.add(
//             Marker(
//               markerId: const MarkerId('driver'),
//               position: _driverPosition!,
//               icon: BitmapDescriptor.defaultMarkerWithHue(
//                 BitmapDescriptor.hueBlue,
//               ),
//             ),
//           );
//         });

//         // Move camera to driver location
//         _mapController?.animateCamera(CameraUpdate.newLatLng(_driverPosition!));
//       });

//       // Join the ride group to receive real-time updates
//       await _signalR!.joinRideGroup(widget.rideId);

//       print('SignalR initialized and joined ride ${widget.rideId}');
//     } catch (e) {
//       print('SignalR initialization error: $e');
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Error initializing SignalR: $e')));
//     }
//   }

//   Future<void> _startRide() async {
//     setState(() => _isStartingRide = true);
//     final driverId = FirebaseAuth.instance.currentUser!.uid;
//     final url = Uri.parse('$baseUrl/rides/${widget.rideId}/start');

//     try {
//       final response = await http.post(
//         url,
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({"startTime": DateTime.now().toIso8601String()}),
//       );

//       if (response.statusCode == 200) {
//         _startSendingLocation(driverId);
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(
//             builder:
//                 (_) => LiveTrackingScreen(
//                   rideId: widget.rideId,
//                   pickup: LatLng(widget.pickupLat, widget.pickupLng),
//                   destination: LatLng(widget.destLat, widget.destLng),
//                 ),
//           ),
//         );
//       }
//     } catch (e) {
//       setState(() => _isStartingRide = false);
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text("Error: $e")));
//     }
//   }

//   void _startSendingLocation(String driverId) {
//     const locationSettings = LocationSettings(
//       accuracy: LocationAccuracy.high,
//       distanceFilter: 5,
//     );

//     _positionStream = Geolocator.getPositionStream(
//       locationSettings: locationSettings,
//     ).listen((position) async {
//       _driverPosition = LatLng(position.latitude, position.longitude);

//       setState(() {
//         _markers.removeWhere((m) => m.markerId.value == 'driver');
//         _markers.add(
//           Marker(
//             markerId: const MarkerId('driver'),
//             position: _driverPosition!,
//             icon: BitmapDescriptor.defaultMarkerWithHue(
//               BitmapDescriptor.hueBlue,
//             ),
//           ),
//         );
//       });

//       await _signalR?.updateDriverLocation(
//         widget.rideId,
//         position.latitude,
//         position.longitude,
//         driverId,
//       );
//     });
//   }

//   Future<void> _loadRoute() async {
//     final start = LatLng(widget.pickupLat, widget.pickupLng);
//     final end = LatLng(widget.destLat, widget.destLng);

//     final url =
//         "https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&key=$mapKey";

//     final res = await http.get(Uri.parse(url));
//     final data = jsonDecode(res.body);

//     if ((data["routes"] as List).isEmpty) return;

//     final points = data["routes"][0]["overview_polyline"]["points"];
//     final distance = data["routes"][0]["legs"][0]["distance"]["value"] / 1000;
//     final polylinePoints = PolylinePoints().decodePolyline(points);

//     setState(() {
//       _distance = distance;
//       _polylines.add(
//         Polyline(
//           polylineId: const PolylineId("route"),
//           color: Colors.black,
//           width: 5,
//           points:
//               polylinePoints
//                   .map((p) => LatLng(p.latitude, p.longitude))
//                   .toList(),
//         ),
//       );

//       _markers.add(
//         Marker(
//           markerId: const MarkerId("pickup"),
//           position: start,
//           icon: BitmapDescriptor.defaultMarkerWithHue(
//             BitmapDescriptor.hueGreen,
//           ),
//         ),
//       );

//       _markers.add(
//         Marker(
//           markerId: const MarkerId("destination"),
//           position: end,
//           icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
//         ),
//       );
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final pickup = LatLng(widget.pickupLat, widget.pickupLng);
//     final destination = LatLng(widget.destLat, widget.destLng);

//     return Scaffold(
//       body: Stack(
//         children: [
//           GoogleMap(
//             initialCameraPosition: CameraPosition(target: pickup, zoom: 14),
//             onMapCreated: (controller) {
//               _mapController = controller;

//               // Add initial markers
//               _markers.addAll([
//                 Marker(
//                   markerId: const MarkerId("pickup"),
//                   position: pickup,
//                   icon: BitmapDescriptor.defaultMarkerWithHue(
//                     BitmapDescriptor.hueGreen,
//                   ),
//                   infoWindow: InfoWindow(title: widget.pickupName),
//                 ),
//                 Marker(
//                   markerId: const MarkerId("destination"),
//                   position: destination,
//                   icon: BitmapDescriptor.defaultMarkerWithHue(
//                     BitmapDescriptor.hueRed,
//                   ),
//                   infoWindow: InfoWindow(title: widget.destinationName),
//                 ),
//               ]);

//               setState(() {});
//             },
//             markers: _markers,
//             polylines: _polylines,
//             myLocationEnabled: true,
//             zoomControlsEnabled: false,
//           ),

//           // Banner overlay on map
//           Positioned(
//             top: 60,
//             left: 16,
//             right: 16,
//             child: Container(
//               padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//               decoration: BoxDecoration(
//                 color: Colors.white70,
//                 borderRadius: BorderRadius.circular(12),
//                 boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
//               ),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         "Pickup",
//                         style: TextStyle(fontWeight: FontWeight.bold),
//                       ),
//                       Text(widget.pickupName ?? ""),
//                     ],
//                   ),
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.end,
//                     children: [
//                       Text(
//                         "Destination",
//                         style: TextStyle(fontWeight: FontWeight.bold),
//                       ),
//                       Text(widget.destinationName ?? ""),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           DraggableScrollableSheet(
//             initialChildSize: 0.42,
//             minChildSize: 0.32,
//             maxChildSize: 0.65,
//             builder: (_, controller) {
//               return Container(
//                 padding: const EdgeInsets.all(20),
//                 decoration: const BoxDecoration(
//                   color: Colors.white,
//                   borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
//                 ),
//                 child: SingleChildScrollView(
//                   controller: controller,
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       _dragHandle(),
//                       const SizedBox(height: 16),
//                       _driverCard(),
//                       const SizedBox(height: 20),
//                       _locationTile(
//                         icon: Icons.circle,
//                         color: Colors.green,
//                         title: widget.pickupName ?? "",
//                       ),
//                       const SizedBox(height: 10),
//                       _locationTile(
//                         icon: Icons.location_on,
//                         color: Colors.red,
//                         title: widget.destinationName ?? "",
//                       ),
//                       const SizedBox(height: 20),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           _infoChip(Icons.timer, "$_etaMinutes min"),
//                           _infoChip(
//                             Icons.attach_money,
//                             "UGX ${_fare.toStringAsFixed(0)}",
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 20),
//                       Row(
//                         children: [
//                           Expanded(child: _actionButton(Icons.call, "Call")),
//                           const SizedBox(width: 12),
//                           Expanded(child: _actionButton(Icons.chat, "Chat")),
//                         ],
//                       ),
//                       const SizedBox(height: 20),
//                       SizedBox(
//                         width: double.infinity,
//                         child: ElevatedButton(
//                           onPressed: _isStartingRide ? null : _startRide,
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: const Color(0xFF00C853),
//                             minimumSize: const Size(double.infinity, 55),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(14),
//                             ),
//                           ),
//                           child:
//                               _isStartingRide
//                                   ? const CircularProgressIndicator(
//                                     color: Colors.white,
//                                   )
//                                   : const Text(
//                                     "Start Ride",
//                                     style: TextStyle(fontSize: 18),
//                                   ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               );
//             },
//           ),
//         ],
//       ),
//     );
//   }

//   // Reusable UI widgets
//   Widget _circleButton(IconData icon, VoidCallback onTap) => GestureDetector(
//     onTap: onTap,
//     child: Container(
//       padding: const EdgeInsets.all(10),
//       decoration: const BoxDecoration(
//         color: Colors.white,
//         shape: BoxShape.circle,
//       ),
//       child: Icon(icon),
//     ),
//   );

//   Widget _locationTile({
//     required IconData icon,
//     required Color color,
//     required String title,
//   }) => Row(
//     children: [
//       Icon(icon, color: color, size: 18),
//       const SizedBox(width: 10),
//       Expanded(child: Text(title)),
//     ],
//   );

//   Widget _dragHandle() => Center(
//     child: Container(
//       height: 5,
//       width: 50,
//       decoration: BoxDecoration(
//         color: Colors.grey[300],
//         borderRadius: BorderRadius.circular(10),
//       ),
//     ),
//   );

//   Widget _driverCard() => Row(
//     children: [
//       CircleAvatar(
//         radius: 28,
//         backgroundColor: Colors.grey[300],
//         child: const Icon(Icons.person, size: 30),
//       ),
//       const SizedBox(width: 12),
//       Expanded(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               widget.rider ?? "Driver",
//               style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 4),
//             Row(
//               children: const [
//                 Icon(Icons.star, color: Colors.amber, size: 16),
//                 SizedBox(width: 4),
//                 Text("4.8"),
//                 SizedBox(width: 10),
//                 Text("Toyota Prius • UBA 123A"),
//               ],
//             ),
//           ],
//         ),
//       ),
//     ],
//   );

//   Widget _infoChip(IconData icon, String text) => Container(
//     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//     decoration: BoxDecoration(
//       color: const Color(0xFFF1F1F1),
//       borderRadius: BorderRadius.circular(12),
//     ),
//     child: Row(
//       children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(text)],
//     ),
//   );

//   Widget _actionButton(IconData icon, String label) => Container(
//     height: 50,
//     decoration: BoxDecoration(
//       color: Colors.black,
//       borderRadius: BorderRadius.circular(12),
//     ),
//     child: Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         Icon(icon, color: Colors.white),
//         const SizedBox(width: 8),
//         Text(label, style: const TextStyle(color: Colors.white)),
//       ],
//     ),
//   );
// }
// // import 'dart:async';
// // import 'dart:convert';
// // import 'package:aminidriver/Container/utils/keys.dart';
// // import 'package:aminidriver/Onboarding/live_tracking_screen.dart';
// // import 'package:aminidriver/Onboarding/signal_connection.dart';
// // import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_screen.dart';
// // import 'package:aminidriver/main.dart';
// // import 'package:firebase_auth/firebase_auth.dart';
// // import 'package:flutter/material.dart';
// // import 'package:flutter_polyline_points/flutter_polyline_points.dart';
// // import 'package:geolocator/geolocator.dart';
// // import 'package:google_maps_flutter/google_maps_flutter.dart';
// // import 'package:http/http.dart' as http;
// // import 'package:aminidriver/Services/signalr_service.dart'; // your SignalR class

// // class TripDetailScreen extends StatefulWidget {
// //   final String rideId;
// //   final String? rider;
// //   final String? riderId;
// //   final String? pickupName;
// //   final String? destinationName;
// //   final String? mobile;
// //   final double pickupLat;
// //   final double pickupLng;
// //   final double destLat;
// //   final double destLng;

// //   const TripDetailScreen({
// //     required this.rideId,
// //     this.pickupName,
// //     this.destinationName,
// //     this.mobile,
// //     required this.pickupLat,
// //     required this.pickupLng,
// //     required this.destLat,
// //     required this.destLng,
// //     this.rider,
// //     this.riderId,
// //     Key? key,
// //   }) : super(key: key);

// //   @override
// //   State<TripDetailScreen> createState() => _TripDetailScreenState();
// // }

// // class _TripDetailScreenState extends State<TripDetailScreen> {
// //   GoogleMapController? _mapController;
// //   Set<Polyline> _polylines = {};
// //   Set<Marker> _markers = {};
// //   double? _distance;

// //   bool _isStartingRide = false;
// //   int _etaMinutes = 5;
// //   double _fare = 4500;

// //   LatLng? _driverPosition;
// //   SignalRService? _signalR;

// //   @override
// //   void initState() {
// //     super.initState();
// //     _initSignalR();
// //     _loadRoute();
// //   }

// //   @override
// //   void dispose() {
// //     _signalR?.leaveRideGroup(widget.rideId);
// //     super.dispose();
// //   }

// //   Future<void> _initSignalR() async {
// //     _signalR = SignalRService(onDriverLocationUpdate: _onDriverLocationUpdate);
// //     await _signalR!.init("YOUR_JWT_TOKEN"); // optional auth token
// //     await _signalR!.joinRideGroup(widget.rideId);
// //   }

// //   void _onDriverLocationUpdate(Map<String, dynamic> data) {
// //     final driverId = data['DriverId'];
// //     final lat = data['Latitude'];
// //     final lng = data['Longitude'];

// //     setState(() {
// //       _driverPosition = LatLng(lat, lng);

// //       // Update driver marker
// //       _markers.removeWhere((m) => m.markerId.value == 'driver');
// //       _markers.add(Marker(
// //         markerId: const MarkerId('driver'),
// //         position: _driverPosition!,
// //         icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
// //         infoWindow: InfoWindow(title: 'Driver $driverId'),
// //       ));
// //     });

// //     // Move camera to driver
// //     _mapController?.animateCamera(
// //       CameraUpdate.newLatLng(_driverPosition!),
// //     );
// //   }

// //   Future<void> _startRide() async {
// //     setState(() => _isStartingRide = true);

// //     final user = FirebaseAuth.instance.currentUser;
// //     final url = Uri.parse('$baseUrl/rides/${widget.rideId}/start');

// //     try {
// //       final response = await http.post(
// //         url,
// //         headers: {'Content-Type': 'application/json'},
// //         body: jsonEncode({"startTime": DateTime.now().toIso8601String()}),
// //       );

// //       if (response.statusCode == 200) {
// //         // Navigate to live tracking
// //         Navigator.pushReplacement(
// //           context,
// //           MaterialPageRoute(
// //             builder: (_) => LiveTrackingScreen(
// //               rideId: widget.rideId,
// //               pickup: LatLng(widget.pickupLat, widget.pickupLng),
// //               destination: LatLng(widget.destLat, widget.destLng),
// //             ),
// //           ),
// //         );
// //       }
// //     } catch (e) {
// //       setState(() => _isStartingRide = false);
// //       ScaffoldMessenger.of(context)
// //           .showSnackBar(SnackBar(content: Text("Error: $e")));
// //     }
// //   }

// //   Future<void> _loadRoute() async {
// //     final start = LatLng(widget.pickupLat, widget.pickupLng);
// //     final end = LatLng(widget.destLat, widget.destLng);

// //     final url =
// //         "https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&key=$mapKey";

// //     final res = await http.get(Uri.parse(url));
// //     final data = jsonDecode(res.body);

// //     if ((data["routes"] as List).isEmpty) return;

// //     final points = data["routes"][0]["overview_polyline"]["points"];
// //     final distance = data["routes"][0]["legs"][0]["distance"]["value"] / 1000;

// //     final polylinePoints = PolylinePoints().decodePolyline(points);

// //     setState(() {
// //       _distance = distance;

// //       _polylines.add(Polyline(
// //         polylineId: const PolylineId("route"),
// //         color: Colors.black,
// //         width: 5,
// //         points: polylinePoints.map((p) => LatLng(p.latitude, p.longitude)).toList(),
// //       ));

// //       _markers.add(Marker(
// //         markerId: const MarkerId("pickup"),
// //         position: start,
// //         icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
// //       ));

// //       _markers.add(Marker(
// //         markerId: const MarkerId("destination"),
// //         position: end,
// //         icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
// //       ));
// //     });
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     final pickup = LatLng(widget.pickupLat, widget.pickupLng);

// //     return Scaffold(
// //       backgroundColor: const Color(0xFFF7F7F7),
// //       body: Stack(
// //         children: [
// //           GoogleMap(
// //             initialCameraPosition: CameraPosition(target: pickup, zoom: 14),
// //             onMapCreated: (controller) => _mapController = controller,
// //             markers: _markers,
// //             polylines: _polylines,
// //             myLocationEnabled: true,
// //             zoomControlsEnabled: false,
// //           ),

// //           SafeArea(
// //             child: Padding(
// //               padding: const EdgeInsets.symmetric(horizontal: 16),
// //               child: Row(
// //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //                 children: [
// //                   _circleButton(Icons.arrow_back, () => Navigator.pop(context)),
// //                   const Text(
// //                     "Trip",
// //                     style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
// //                   ),
// //                   _circleButton(Icons.more_vert, () {}),
// //                 ],
// //               ),
// //             ),
// //           ),

// //           DraggableScrollableSheet(
// //             initialChildSize: 0.42,
// //             minChildSize: 0.32,
// //             maxChildSize: 0.65,
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
// //                       _dragHandle(),
// //                       const SizedBox(height: 16),
// //                       _driverCard(),
// //                       const SizedBox(height: 20),
// //                       _locationTile(icon: Icons.circle, color: Colors.green, title: widget.pickupName ?? ""),
// //                       const SizedBox(height: 10),
// //                       _locationTile(icon: Icons.location_on, color: Colors.red, title: widget.destinationName ?? ""),
// //                       const SizedBox(height: 20),
// //                       Row(
// //                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //                         children: [
// //                           _infoChip(Icons.timer, "$_etaMinutes min"),
// //                           _infoChip(Icons.attach_money, "UGX ${_fare.toStringAsFixed(0)}"),
// //                         ],
// //                       ),
// //                       const SizedBox(height: 20),
// //                       Row(
// //                         children: [
// //                           Expanded(child: _actionButton(Icons.call, "Call")),
// //                           const SizedBox(width: 12),
// //                           Expanded(child: _actionButton(Icons.chat, "Chat")),
// //                         ],
// //                       ),
// //                       const SizedBox(height: 20),
// //                       SizedBox(
// //                         width: double.infinity,
// //                         child: ElevatedButton(
// //                           onPressed: _isStartingRide ? null : _startRide,
// //                           style: ElevatedButton.styleFrom(
// //                             backgroundColor: const Color(0xFF00C853),
// //                             minimumSize: const Size(double.infinity, 55),
// //                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
// //                           ),
// //                           child: _isStartingRide
// //                               ? const CircularProgressIndicator(color: Colors.white)
// //                               : const Text("Start Ride", style: TextStyle(fontSize: 18)),
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

// //   Widget _circleButton(IconData icon, VoidCallback onTap) => GestureDetector(
// //     onTap: onTap,
// //     child: Container(
// //       padding: const EdgeInsets.all(10),
// //       decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
// //       child: Icon(icon),
// //     ),
// //   );

// //   Widget _locationTile({required IconData icon, required Color color, required String title}) => Row(
// //     children: [
// //       Icon(icon, color: color, size: 18),
// //       const SizedBox(width: 10),
// //       Expanded(child: Text(title)),
// //     ],
// //   );

// //   Widget _dragHandle() => Center(
// //     child: Container(
// //       height: 5,
// //       width: 50,
// //       decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
// //     ),
// //   );

// //   Widget _driverCard() => Row(
// //     children: [
// //       CircleAvatar(radius: 28, backgroundColor: Colors.grey[300], child: const Icon(Icons.person, size: 30)),
// //       const SizedBox(width: 12),
// //       Expanded(
// //         child: Column(
// //           crossAxisAlignment: CrossAxisAlignment.start,
// //           children: [
// //             Text(widget.rider ?? "Driver", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
// //             const SizedBox(height: 4),
// //             Row(
// //               children: const [
// //                 Icon(Icons.star, color: Colors.amber, size: 16),
// //                 SizedBox(width: 4),
// //                 Text("4.8"),
// //                 SizedBox(width: 10),
// //                 Text("Toyota Prius • UBA 123A"),
// //               ],
// //             ),
// //           ],
// //         ),
// //       ),
// //     ],
// //   );

// //   Widget _infoChip(IconData icon, String text) => Container(
// //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
// //     decoration: BoxDecoration(color: const Color(0xFFF1F1F1), borderRadius: BorderRadius.circular(12)),
// //     child: Row(children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(text)]),
// //   );

// //   Widget _actionButton(IconData icon, String label) => Container(
// //     height: 50,
// //     decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)),
// //     child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
// //       Icon(icon, color: Colors.white),
// //       const SizedBox(width: 8),
// //       Text(label, style: const TextStyle(color: Colors.white)),
// //     ]),
// //   );
// // }

// // // import 'dart:async';
// // // import 'dart:convert';
// // // import 'package:aminidriver/Container/utils/keys.dart';
// // // import 'package:aminidriver/Onboarding/live_tracking_screen.dart';
// // // import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_screen.dart';
// // // import 'package:aminidriver/main.dart';
// // // import 'package:firebase_auth/firebase_auth.dart';
// // // import 'package:firebase_database/firebase_database.dart';
// // // import 'package:flutter/material.dart';
// // // import 'package:flutter_polyline_points/flutter_polyline_points.dart';
// // // import 'package:geolocator/geolocator.dart';
// // // import 'package:google_maps_flutter/google_maps_flutter.dart';
// // // import 'package:http/http.dart' as http;

// // // class TripDetailScreen extends StatefulWidget {
// // //   final String rideId;
// // //   final String? rider;
// // //   final String? riderId;
// // //   final String? pickupName;
// // //   final String? destinationName;
// // //   final String? mobile;
// // //   final double pickupLat;
// // //   final double pickupLng;
// // //   final double destLat;
// // //   final double destLng;

// // //   const TripDetailScreen({
// // //     required this.rideId,
// // //     this.pickupName,
// // //     this.destinationName,
// // //     this.mobile,
// // //     required this.pickupLat,
// // //     required this.pickupLng,
// // //     required this.destLat,
// // //     required this.destLng,
// // //     this.rider,
// // //     this.riderId,
// // //     Key? key,
// // //   }) : super(key: key);

// // //   @override
// // //   State<TripDetailScreen> createState() => _TripDetailScreenState();
// // // }

// // // class _TripDetailScreenState extends State<TripDetailScreen> {
// // //   GoogleMapController? _mapController;
// // //   Set<Polyline> _polylines = {};
// // //   Set<Marker> _markers = {};
// // //   double? _distance;

// // //   StreamSubscription<Position>? _positionStream;
// // //   StreamSubscription<DatabaseEvent>? _rideStatusSub;
// // //   bool _isStartingRide = false;
// // //   int _etaMinutes = 5; // simulate ETA (you can replace with API later)
// // //   double _fare = 4500; // simulate fare

// // //   @override
// // //   void initState() {
// // //     super.initState();
// // //     _listenToRideStatus();
// // //     _loadRoute();
// // //   }

// // //   @override
// // //   void dispose() {
// // //     _positionStream?.cancel();
// // //     _rideStatusSub?.cancel();
// // //     super.dispose();
// // //   }

// // //   void _listenToRideStatus() {
// // //     final db = FirebaseDatabase.instanceFor(app: passengerApp);
// // //     final rideRef = db.ref("rides/${widget.rideId}");

// // //     _rideStatusSub = rideRef.child("status").onValue.listen((event) {
// // //       final status = event.snapshot.value?.toString();

// // //       if (status == "cancelled" && mounted) {
// // //         Navigator.pushAndRemoveUntil(
// // //           context,
// // //           MaterialPageRoute(builder: (_) => const HomeScreen()),
// // //           (route) => false,
// // //         );
// // //       }
// // //     });
// // //   }

// // //   Future<void> _startTrackingDriver(String rideId) async {
// // //     await _positionStream?.cancel();

// // //     final db = FirebaseDatabase.instanceFor(app: passengerApp);
// // //     final rideRef = db.ref("rides/$rideId");

// // //     const locationSettings = LocationSettings(
// // //       accuracy: LocationAccuracy.high,
// // //       distanceFilter: 5,
// // //     );

// // //     _positionStream = Geolocator.getPositionStream(
// // //       locationSettings: locationSettings,
// // //     ).listen((position) async {
// // //       await rideRef.update({
// // //         "driverlocation": {"lat": position.latitude, "lng": position.longitude},
// // //       });
// // //     });
// // //   }

// // //   Future<void> _startRide() async {
// // //     setState(() => _isStartingRide = true);

// // //     final user = FirebaseAuth.instance.currentUser;
// // //     final url = Uri.parse('$baseUrl/rides/${widget.rideId}/start');

// // //     try {
// // //       final response = await http.post(
// // //         url,
// // //         headers: {'Content-Type': 'application/json'},
// // //         body: jsonEncode({"startTime": DateTime.now().toIso8601String()}),
// // //       );

// // //       if (response.statusCode == 200) {
// // //         final db = FirebaseDatabase.instanceFor(app: passengerApp);
// // //         final rideRef = db.ref("rides/${widget.rideId}");

// // //         await rideRef.update({
// // //           "status": "in_progress",
// // //           "driverId": user?.uid,
// // //           "riderId": widget.riderId,
// // //           "startTime": DateTime.now().toIso8601String(),
// // //         });

// // //         _startTrackingDriver(widget.rideId);

// // //         Navigator.pushReplacement(
// // //           context,
// // //           MaterialPageRoute(
// // //             builder:
// // //                 (_) => LiveTrackingScreen(
// // //                   rideId: widget.rideId,
// // //                   pickup: LatLng(widget.pickupLat, widget.pickupLng),
// // //                   destination: LatLng(widget.destLat, widget.destLng),
// // //                 ),
// // //           ),
// // //         );
// // //       }
// // //     } catch (e) {
// // //       setState(() => _isStartingRide = false);
// // //       ScaffoldMessenger.of(
// // //         context,
// // //       ).showSnackBar(SnackBar(content: Text("Error: $e")));
// // //     }
// // //   }

// // //   Future<void> _loadRoute() async {
// // //     final start = LatLng(widget.pickupLat, widget.pickupLng);
// // //     final end = LatLng(widget.destLat, widget.destLng);

// // //     final url =
// // //         "https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&key=$mapKey";

// // //     final res = await http.get(Uri.parse(url));
// // //     final data = jsonDecode(res.body);

// // //     if ((data["routes"] as List).isEmpty) return;

// // //     final points = data["routes"][0]["overview_polyline"]["points"];
// // //     final distance = data["routes"][0]["legs"][0]["distance"]["value"] / 1000;

// // //     final polylinePoints = PolylinePoints().decodePolyline(points);

// // //     setState(() {
// // //       _distance = distance;

// // //       _polylines.add(
// // //         Polyline(
// // //           polylineId: const PolylineId("route"),
// // //           color: Colors.black,
// // //           width: 5,
// // //           points:
// // //               polylinePoints
// // //                   .map((p) => LatLng(p.latitude, p.longitude))
// // //                   .toList(),
// // //         ),
// // //       );

// // //       _markers.add(
// // //         Marker(
// // //           markerId: const MarkerId("pickup"),
// // //           position: start,
// // //           icon: BitmapDescriptor.defaultMarkerWithHue(
// // //             BitmapDescriptor.hueGreen,
// // //           ),
// // //         ),
// // //       );

// // //       _markers.add(
// // //         Marker(
// // //           markerId: const MarkerId("destination"),
// // //           position: end,
// // //           icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
// // //         ),
// // //       );
// // //     });
// // //   }

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     final pickup = LatLng(widget.pickupLat, widget.pickupLng);

// // //     return Scaffold(
// // //       backgroundColor: const Color(0xFFF7F7F7),
// // //       body: Stack(
// // //         children: [
// // //           /// MAP
// // //           GoogleMap(
// // //             initialCameraPosition: CameraPosition(target: pickup, zoom: 14),
// // //             onMapCreated: (controller) => _mapController = controller,
// // //             markers: _markers,
// // //             polylines: _polylines,
// // //             myLocationEnabled: true,
// // //             zoomControlsEnabled: false,
// // //           ),

// // //           /// TOP BAR
// // //           SafeArea(
// // //             child: Padding(
// // //               padding: const EdgeInsets.symmetric(horizontal: 16),
// // //               child: Row(
// // //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
// // //                 children: [
// // //                   _circleButton(Icons.arrow_back, () {
// // //                     Navigator.pop(context);
// // //                   }),
// // //                   const Text(
// // //                     "Trip",
// // //                     style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
// // //                   ),
// // //                   _circleButton(Icons.more_vert, () {}),
// // //                 ],
// // //               ),
// // //             ),
// // //           ),

// // //           /// BOTTOM SHEET
// // //           DraggableScrollableSheet(
// // //             initialChildSize: 0.42,
// // //             minChildSize: 0.32,
// // //             maxChildSize: 0.65,
// // //             builder: (_, controller) {
// // //               return Container(
// // //                 padding: const EdgeInsets.all(20),
// // //                 decoration: const BoxDecoration(
// // //                   color: Colors.white,
// // //                   borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
// // //                 ),
// // //                 child: SingleChildScrollView(
// // //                   controller: controller,
// // //                   child: Column(
// // //                     crossAxisAlignment: CrossAxisAlignment.start,
// // //                     children: [
// // //                       _dragHandle(),

// // //                       const SizedBox(height: 16),

// // //                       /// 🚗 DRIVER CARD
// // //                       _driverCard(),

// // //                       const SizedBox(height: 20),

// // //                       /// 📍 LOCATIONS
// // //                       _locationTile(
// // //                         icon: Icons.circle,
// // //                         color: Colors.green,
// // //                         title: widget.pickupName ?? "",
// // //                       ),
// // //                       const SizedBox(height: 10),
// // //                       _locationTile(
// // //                         icon: Icons.location_on,
// // //                         color: Colors.red,
// // //                         title: widget.destinationName ?? "",
// // //                       ),

// // //                       const SizedBox(height: 20),

// // //                       /// ⏱ ETA + 💰 FARE
// // //                       Row(
// // //                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
// // //                         children: [
// // //                           _infoChip(Icons.timer, "$_etaMinutes min"),
// // //                           _infoChip(
// // //                             Icons.attach_money,
// // //                             "UGX ${_fare.toStringAsFixed(0)}",
// // //                           ),
// // //                         ],
// // //                       ),

// // //                       const SizedBox(height: 20),

// // //                       /// 📞 ACTION BUTTONS
// // //                       Row(
// // //                         children: [
// // //                           Expanded(child: _actionButton(Icons.call, "Call")),
// // //                           const SizedBox(width: 12),
// // //                           Expanded(child: _actionButton(Icons.chat, "Chat")),
// // //                         ],
// // //                       ),

// // //                       const SizedBox(height: 20),

// // //                       /// 🚀 START BUTTON
// // //                       SizedBox(
// // //                         width: double.infinity,
// // //                         child: ElevatedButton(
// // //                           onPressed: _isStartingRide ? null : _startRide,
// // //                           style: ElevatedButton.styleFrom(
// // //                             backgroundColor: const Color(0xFF00C853),
// // //                             minimumSize: const Size(double.infinity, 55),
// // //                             shape: RoundedRectangleBorder(
// // //                               borderRadius: BorderRadius.circular(14),
// // //                             ),
// // //                           ),
// // //                           child:
// // //                               _isStartingRide
// // //                                   ? const CircularProgressIndicator(
// // //                                     color: Colors.white,
// // //                                   )
// // //                                   : const Text(
// // //                                     "Start Ride",
// // //                                     style: TextStyle(fontSize: 18),
// // //                                   ),
// // //                         ),
// // //                       ),
// // //                     ],
// // //                   ),
// // //                 ),
// // //               );
// // //             },
// // //           ),
// // //         ],
// // //       ),
// // //     );
// // //   }

// // //   Widget _circleButton(IconData icon, VoidCallback onTap) {
// // //     return GestureDetector(
// // //       onTap: onTap,
// // //       child: Container(
// // //         padding: const EdgeInsets.all(10),
// // //         decoration: const BoxDecoration(
// // //           color: Colors.white,
// // //           shape: BoxShape.circle,
// // //         ),
// // //         child: Icon(icon),
// // //       ),
// // //     );
// // //   }

// // //   Widget _locationTile({
// // //     required IconData icon,
// // //     required Color color,
// // //     required String title,
// // //   }) {
// // //     return Row(
// // //       children: [
// // //         Icon(icon, color: color, size: 18),
// // //         const SizedBox(width: 10),
// // //         Expanded(child: Text(title)),
// // //       ],
// // //     );
// // //   }

// // //   Widget _dragHandle() {
// // //     return Center(
// // //       child: Container(
// // //         height: 5,
// // //         width: 50,
// // //         decoration: BoxDecoration(
// // //           color: Colors.grey[300],
// // //           borderRadius: BorderRadius.circular(10),
// // //         ),
// // //       ),
// // //     );
// // //   }

// // //   Widget _driverCard() {
// // //     return Row(
// // //       children: [
// // //         CircleAvatar(
// // //           radius: 28,
// // //           backgroundColor: Colors.grey[300],
// // //           child: const Icon(Icons.person, size: 30),
// // //         ),
// // //         const SizedBox(width: 12),

// // //         Expanded(
// // //           child: Column(
// // //             crossAxisAlignment: CrossAxisAlignment.start,
// // //             children: [
// // //               Text(
// // //                 widget.rider ?? "Driver",
// // //                 style: const TextStyle(
// // //                   fontSize: 18,
// // //                   fontWeight: FontWeight.bold,
// // //                 ),
// // //               ),
// // //               const SizedBox(height: 4),
// // //               Row(
// // //                 children: const [
// // //                   Icon(Icons.star, color: Colors.amber, size: 16),
// // //                   SizedBox(width: 4),
// // //                   Text("4.8"),
// // //                   SizedBox(width: 10),
// // //                   Text("Toyota Prius • UBA 123A"),
// // //                 ],
// // //               ),
// // //             ],
// // //           ),
// // //         ),
// // //       ],
// // //     );
// // //   }

// // //   Widget _infoChip(IconData icon, String text) {
// // //     return Container(
// // //       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
// // //       decoration: BoxDecoration(
// // //         color: const Color(0xFFF1F1F1),
// // //         borderRadius: BorderRadius.circular(12),
// // //       ),
// // //       child: Row(
// // //         children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(text)],
// // //       ),
// // //     );
// // //   }

// // //   Widget _actionButton(IconData icon, String label) {
// // //     return Container(
// // //       height: 50,
// // //       decoration: BoxDecoration(
// // //         color: Colors.black,
// // //         borderRadius: BorderRadius.circular(12),
// // //       ),
// // //       child: Row(
// // //         mainAxisAlignment: MainAxisAlignment.center,
// // //         children: [
// // //           Icon(icon, color: Colors.white),
// // //           const SizedBox(width: 8),
// // //           Text(label, style: const TextStyle(color: Colors.white)),
// // //         ],
// // //       ),
// // //     );
// // //   }
// // // }

// // // // // import 'dart:async';
// // // // // import 'dart:convert';
// // // // // import 'package:aminidriver/Container/utils/keys.dart';
// // // // // import 'package:aminidriver/Onboarding/live_tracking_screen.dart';
// // // // // import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_screen.dart';
// // // // // import 'package:aminidriver/main.dart';
// // // // // import 'package:firebase_auth/firebase_auth.dart';
// // // // // import 'package:firebase_database/firebase_database.dart';
// // // // // import 'package:flutter/material.dart';
// // // // // import 'package:flutter_polyline_points/flutter_polyline_points.dart';
// // // // // import 'package:geolocator/geolocator.dart';
// // // // // import 'package:google_maps_flutter/google_maps_flutter.dart';
// // // // // import 'package:http/http.dart' as http;

// // // // // class TripDetailScreen extends StatefulWidget {
// // // // //   final String rideId;
// // // // //   final String? rider;
// // // // //   final String? riderId;
// // // // //   final String? pickupName;
// // // // //   final String? destinationName;
// // // // //   final String? mobile;
// // // // //   final double pickupLat;
// // // // //   final double pickupLng;
// // // // //   final double destLat;
// // // // //   final double destLng;

// // // // //   const TripDetailScreen({
// // // // //     required this.rideId,
// // // // //     this.pickupName,
// // // // //     this.destinationName,
// // // // //     this.mobile,
// // // // //     required this.pickupLat,
// // // // //     required this.pickupLng,
// // // // //     required this.destLat,
// // // // //     required this.destLng,
// // // // //     this.rider,
// // // // //     this.riderId,
// // // // //     Key? key,
// // // // //   }) : super(key: key);

// // // // //   @override
// // // // //   State<TripDetailScreen> createState() => _TripDetailScreenState();
// // // // // }

// // // // // class _TripDetailScreenState extends State<TripDetailScreen> {
// // // // //   GoogleMapController? _mapController;
// // // // //   Set<Polyline> _polylines = {};
// // // // //   Set<Marker> _markers = {};
// // // // //   double? _distance;
// // // // //   StreamSubscription<Position>? _positionStream;
// // // // //   StreamSubscription<DatabaseEvent>? _rideStatusSub;

// // // // //   @override
// // // // //   void initState() {
// // // // //     super.initState();
// // // // //     _listenToRideStatus();
// // // // //     _loadRoute();
// // // // //   }

// // // // //   @override
// // // // //   void dispose() {
// // // // //     _positionStream?.cancel();
// // // // //     _rideStatusSub?.cancel();
// // // // //     super.dispose();
// // // // //   }

// // // // //   void _listenToRideStatus() {
// // // // //     final db = FirebaseDatabase.instanceFor(app: passengerApp);
// // // // //     final rideRef = db.ref("rides/${widget.rideId}");

// // // // //     _rideStatusSub = rideRef.child("status").onValue.listen((event) {
// // // // //       final status = event.snapshot.value?.toString();
// // // // //       if (status == "cancelled" && mounted) {
// // // // //         Navigator.pushAndRemoveUntil(
// // // // //           context,
// // // // //           MaterialPageRoute(builder: (_) => const HomeScreen()),
// // // // //           (route) => false,
// // // // //         );
// // // // //       }
// // // // //     });
// // // // //   }

// // // // //   Future<void> _startTrackingDriver(String rideId) async {
// // // // //     await _positionStream?.cancel();

// // // // //     final db = FirebaseDatabase.instanceFor(app: passengerApp);
// // // // //     final rideRef = db.ref("rides");

// // // // //     const locationSettings = LocationSettings(
// // // // //       accuracy: LocationAccuracy.high,
// // // // //       distanceFilter: 5,
// // // // //     );

// // // // //     _positionStream = Geolocator.getPositionStream(
// // // // //       locationSettings: locationSettings,
// // // // //     ).listen((position) async {
// // // // //       try {
// // // // //         await rideRef.update({
// // // // //           "driverlocation": {
// // // // //             "lat": position.latitude,
// // // // //             "lng": position.longitude,
// // // // //           },
// // // // //         });
// // // // //       } catch (e) {
// // // // //         debugPrint("Error updating driver location: $e");
// // // // //       }
// // // // //     });
// // // // //   }

// // // // //   Future<void> _startRide() async {
// // // // //     final user = FirebaseAuth.instance.currentUser;
// // // // //     final url = Uri.parse('$baseUrl/rides/${widget.rideId}/start');

// // // // //     try {
// // // // //       final response = await http.post(
// // // // //         url,
// // // // //         headers: {'Content-Type': 'application/json'},
// // // // //         body: jsonEncode({"startTime": DateTime.now().toIso8601String()}),
// // // // //       );

// // // // //       if (response.statusCode == 200) {
// // // // //         final db = FirebaseDatabase.instanceFor(app: passengerApp);
// // // // //         final rideRef = db.ref("rides/${widget.rideId}");
// // // // //         await rideRef.update({
// // // // //           "status": "in_progress",
// // // // //           "driverId": user?.uid,
// // // // //           "riderId": widget.riderId,
// // // // //           "pickup": {
// // // // //             "lat": widget.pickupLat,
// // // // //             "lng": widget.pickupLng,
// // // // //             "name": widget.pickupName,
// // // // //           },
// // // // //           "destination": {
// // // // //             "lat": widget.destLat,
// // // // //             "lng": widget.destLng,
// // // // //             "name": widget.destinationName,
// // // // //           },
// // // // //           "startTime": DateTime.now().toIso8601String(),
// // // // //         });

// // // // //         _startTrackingDriver(widget.rideId);

// // // // //         ScaffoldMessenger.of(context).showSnackBar(
// // // // //           const SnackBar(content: Text("Ride started successfully")),
// // // // //         );

// // // // //         Navigator.pushReplacement(
// // // // //           context,
// // // // //           MaterialPageRoute(
// // // // //             builder:
// // // // //                 (_) => LiveTrackingScreen(
// // // // //                   rideId: widget.rideId,
// // // // //                   pickup: LatLng(widget.pickupLat, widget.pickupLng),
// // // // //                   destination: LatLng(widget.destLat, widget.destLng),
// // // // //                 ),
// // // // //           ),
// // // // //         );
// // // // //       } else {
// // // // //         throw Exception("Failed to start ride");
// // // // //       }
// // // // //     } catch (e) {
// // // // //       ScaffoldMessenger.of(
// // // // //         context,
// // // // //       ).showSnackBar(SnackBar(content: Text("Error starting ride: $e")));
// // // // //     }
// // // // //   }

// // // // //   Future<void> _loadRoute() async {
// // // // //     final start = LatLng(widget.pickupLat, widget.pickupLng);
// // // // //     final end = LatLng(widget.destLat, widget.destLng);

// // // // //     final apiKey = mapKey;
// // // // //     final url =
// // // // //         "https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&mode=driving&key=$apiKey";

// // // // //     try {
// // // // //       final res = await http.get(Uri.parse(url));
// // // // //       if (res.statusCode == 200) {
// // // // //         final data = jsonDecode(res.body);
// // // // //         if ((data["routes"] as List).isEmpty) return;

// // // // //         final points = data["routes"][0]["overview_polyline"]["points"];
// // // // //         final distance =
// // // // //             data["routes"][0]["legs"][0]["distance"]["value"] / 1000;
// // // // //         final polylinePoints = PolylinePoints().decodePolyline(points);

// // // // //         setState(() {
// // // // //           _distance = distance;
// // // // //           _polylines.add(
// // // // //             Polyline(
// // // // //               polylineId: const PolylineId("route"),
// // // // //               color: Colors.blue,
// // // // //               width: 5,
// // // // //               points:
// // // // //                   polylinePoints
// // // // //                       .map((p) => LatLng(p.latitude, p.longitude))
// // // // //                       .toList(),
// // // // //             ),
// // // // //           );

// // // // //           _markers.add(
// // // // //             Marker(
// // // // //               markerId: const MarkerId("pickup"),
// // // // //               position: start,
// // // // //               icon: BitmapDescriptor.defaultMarkerWithHue(
// // // // //                 BitmapDescriptor.hueRed,
// // // // //               ),
// // // // //               infoWindow: InfoWindow(title: widget.pickupName),
// // // // //             ),
// // // // //           );
// // // // //           _markers.add(
// // // // //             Marker(
// // // // //               markerId: const MarkerId("destination"),
// // // // //               position: end,
// // // // //               icon: BitmapDescriptor.defaultMarkerWithHue(
// // // // //                 BitmapDescriptor.hueGreen,
// // // // //               ),
// // // // //               infoWindow: InfoWindow(title: widget.destinationName),
// // // // //             ),
// // // // //           );
// // // // //         });

// // // // //         _mapController?.animateCamera(
// // // // //           CameraUpdate.newLatLngBounds(
// // // // //             LatLngBounds(southwest: start, northeast: end),
// // // // //             80,
// // // // //           ),
// // // // //         );
// // // // //       }
// // // // //     } catch (e) {
// // // // //       debugPrint("Error loading route: $e");
// // // // //     }
// // // // //   }

// // // // //   @override
// // // // //   Widget build(BuildContext context) {
// // // // //     final pickup = LatLng(widget.pickupLat, widget.pickupLng);

// // // // //     return WillPopScope(
// // // // //       onWillPop: () async {
// // // // //         // Always go to HomeScreen when phone back is pressed
// // // // //         Navigator.pushAndRemoveUntil(
// // // // //           context,
// // // // //           MaterialPageRoute(builder: (_) => const HomeScreen()),
// // // // //           (route) => false,
// // // // //         );
// // // // //         return false;
// // // // //       },
// // // // //       child: Scaffold(
// // // // //         appBar: AppBar(
// // // // //           automaticallyImplyLeading: false, // ✅ removes back arrow
// // // // //           title: const Text(
// // // // //             "Trip Details",
// // // // //             style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
// // // // //           ),
// // // // //           centerTitle: true,
// // // // //           elevation: 0,
// // // // //           backgroundColor: Colors.white,
// // // // //         ),
// // // // //         body: Column(
// // // // //           children: [
// // // // //             Expanded(
// // // // //               flex: 3,
// // // // //               child: GoogleMap(
// // // // //                 initialCameraPosition: CameraPosition(target: pickup, zoom: 14),
// // // // //                 onMapCreated: (controller) => _mapController = controller,
// // // // //                 markers: _markers,
// // // // //                 polylines: _polylines,
// // // // //                 myLocationEnabled: true,
// // // // //                 myLocationButtonEnabled: true,
// // // // //               ),
// // // // //             ),
// // // // //             Expanded(
// // // // //               flex: 2,
// // // // //               child: Container(
// // // // //                 width: double.infinity,
// // // // //                 decoration: const BoxDecoration(
// // // // //                   color: Colors.white,
// // // // //                   borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
// // // // //                   boxShadow: [
// // // // //                     BoxShadow(
// // // // //                       color: Colors.black12,
// // // // //                       blurRadius: 10,
// // // // //                       offset: Offset(0, -4),
// // // // //                     ),
// // // // //                   ],
// // // // //                 ),
// // // // //                 child: SafeArea(
// // // // //                   child: Padding(
// // // // //                     padding: const EdgeInsets.all(20.0),
// // // // //                     child: SingleChildScrollView(
// // // // //                       child: Column(
// // // // //                         crossAxisAlignment: CrossAxisAlignment.start,
// // // // //                         children: [
// // // // //                           Text(
// // // // //                             "Ride ID: ${widget.rideId}",
// // // // //                             style: const TextStyle(
// // // // //                               fontSize: 18,
// // // // //                               fontWeight: FontWeight.bold,
// // // // //                               color: Colors.black54,
// // // // //                             ),
// // // // //                           ),
// // // // //                           const SizedBox(height: 8),
// // // // //                           Text(
// // // // //                             "Rider: ${widget.rider}",
// // // // //                             style: const TextStyle(
// // // // //                               fontSize: 22,
// // // // //                               fontWeight: FontWeight.w600,
// // // // //                               color: Colors.black87,
// // // // //                             ),
// // // // //                           ),
// // // // //                           const SizedBox(height: 16),
// // // // //                           Row(
// // // // //                             crossAxisAlignment: CrossAxisAlignment.start,
// // // // //                             children: [
// // // // //                               const Icon(
// // // // //                                 Icons.location_on,
// // // // //                                 color: Colors.red,
// // // // //                                 size: 28,
// // // // //                               ),
// // // // //                               const SizedBox(width: 8),
// // // // //                               Expanded(
// // // // //                                 child: Text(
// // // // //                                   "Pickup: ${widget.pickupName}",
// // // // //                                   style: const TextStyle(fontSize: 18),
// // // // //                                 ),
// // // // //                               ),
// // // // //                             ],
// // // // //                           ),
// // // // //                           const SizedBox(height: 10),
// // // // //                           Row(
// // // // //                             crossAxisAlignment: CrossAxisAlignment.start,
// // // // //                             children: [
// // // // //                               const Icon(
// // // // //                                 Icons.flag,
// // // // //                                 color: Colors.green,
// // // // //                                 size: 28,
// // // // //                               ),
// // // // //                               const SizedBox(width: 8),
// // // // //                               Expanded(
// // // // //                                 child: Text(
// // // // //                                   "Destination: ${widget.destinationName}",
// // // // //                                   style: const TextStyle(fontSize: 18),
// // // // //                                 ),
// // // // //                               ),
// // // // //                             ],
// // // // //                           ),
// // // // //                           const SizedBox(height: 16),
// // // // //                           if (_distance != null)
// // // // //                             Text(
// // // // //                               "Distance: ${_distance!.toStringAsFixed(2)} km",
// // // // //                               style: const TextStyle(
// // // // //                                 fontSize: 20,
// // // // //                                 fontWeight: FontWeight.w500,
// // // // //                                 color: Colors.blueAccent,
// // // // //                               ),
// // // // //                             ),
// // // // //                           const SizedBox(height: 20),
// // // // //                           SizedBox(
// // // // //                             width: double.infinity,
// // // // //                             child: ElevatedButton(
// // // // //                               onPressed: _startRide,
// // // // //                               style: ElevatedButton.styleFrom(
// // // // //                                 backgroundColor: Colors.blueAccent,
// // // // //                                 padding: const EdgeInsets.symmetric(
// // // // //                                   vertical: 16,
// // // // //                                 ),
// // // // //                                 shape: RoundedRectangleBorder(
// // // // //                                   borderRadius: BorderRadius.circular(12),
// // // // //                                 ),
// // // // //                               ),
// // // // //                               child: const Text(
// // // // //                                 "Start Ride",
// // // // //                                 style: TextStyle(
// // // // //                                   fontSize: 20,
// // // // //                                   fontWeight: FontWeight.bold,
// // // // //                                   color: Colors.white,
// // // // //                                 ),
// // // // //                               ),
// // // // //                             ),
// // // // //                           ),
// // // // //                         ],
// // // // //                       ),
// // // // //                     ),
// // // // //                   ),
// // // // //                 ),
// // // // //               ),
// // // // //             ),
// // // // //           ],
// // // // //         ),
// // // // //       ),
// // // // //     );
// // // // //   }
// // // // // }
// // // // import 'dart:async';
// // // // import 'dart:convert';
// // // // import 'dart:math';
// // // // import 'package:aminidriver/Container/utils/api_constant.dart';
// // // // import 'package:aminidriver/Container/utils/keys.dart';
// // // // import 'package:aminidriver/Onboarding/live_tracking_screen.dart';
// // // // import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_screen.dart';
// // // // import 'package:aminidriver/main.dart';
// // // // import 'package:firebase_auth/firebase_auth.dart';
// // // // import 'package:firebase_core/firebase_core.dart';
// // // // import 'package:firebase_database/firebase_database.dart';
// // // // import 'package:flutter/material.dart';
// // // // //import 'package:flutter_map/flutter_map.dart';
// // // // import 'package:flutter_polyline_points/flutter_polyline_points.dart';
// // // // import 'package:geolocator/geolocator.dart';
// // // // import 'package:google_maps_flutter/google_maps_flutter.dart';
// // // // import 'package:http/http.dart' as http;
// // // // //import 'package:aminidriver/firebase_passenger_options.dart' as passengerOptions;

// // // // class TripDetailScreen extends StatefulWidget {
// // // //   final String rideId;
// // // //   // final String rideRequestId;
// // // //   final String? rider;
// // // //   final String? riderId;
// // // //   final String? pickupName;
// // // //   final String? destinationName;
// // // //   final String? mobile;
// // // //   final double pickupLat;
// // // //   final double pickupLng;
// // // //   final double destLat;
// // // //   final double destLng;

// // // //   const TripDetailScreen({
// // // //     required this.rideId,
// // // //     //required this.rideRequestId,
// // // //     this.pickupName,
// // // //     this.destinationName,
// // // //     this.mobile,
// // // //     required this.pickupLat,
// // // //     required this.pickupLng,
// // // //     required this.destLat,
// // // //     required this.destLng,
// // // //     this.rider,
// // // //     this.riderId,
// // // //     Key? key,
// // // //   }) : super(key: key);

// // // //   @override
// // // //   State<TripDetailScreen> createState() => _TripDetailScreenState();
// // // // }

// // // // class _TripDetailScreenState extends State<TripDetailScreen> {
// // // //   // final MapController _mapController = MapController();
// // // //   // List<LatLng> _routePoints = [];
// // // //   GoogleMapController? _mapController;
// // // //   Set<Polyline> _polylines = {};
// // // //   Set<Marker> _markers = {};
// // // //   double? _distance;
// // // //   //late FirebaseApp passengerApp;
// // // //   StreamSubscription<Position>? _positionStream;
// // // //   StreamSubscription<DatabaseEvent>? _rideStatusSub;

// // // //   @override
// // // //   void initState() {
// // // //     super.initState();
// // // //     _listenToRideStatus();
// // // //     _loadRoute();
// // // //   }

// // // //   // @override
// // // //   // void dispose() {
// // // //   //   _positionStream?.cancel(); // cancel subscription when screen disposed
// // // //   //   super.dispose();
// // // //   // }
// // // //   @override
// // // //   void dispose() {
// // // //     _positionStream?.cancel();
// // // //     _rideStatusSub?.cancel(); // ✅ stop listening
// // // //     super.dispose();
// // // //   }

// // // //   void _listenToRideStatus() {
// // // //     final db = FirebaseDatabase.instanceFor(app: passengerApp);
// // // //     final rideRef = db.ref("rides/${widget.rideId}");

// // // //     _rideStatusSub = rideRef.child("status").onValue.listen((event) {
// // // //       final status = event.snapshot.value?.toString();
// // // //       debugPrint("Ride status update: $status");

// // // //       if (status == "cancelled") {
// // // //         if (!mounted) return;

// // // //         // Navigate to home
// // // //         Navigator.pushAndRemoveUntil(
// // // //           context,
// // // //           MaterialPageRoute(builder: (_) => const HomeScreen()),
// // // //           (route) => false,
// // // //         );
// // // //       }
// // // //     });
// // // //   }

// // // //   Future<void> _startTrackingDriver(String rideId) async {
// // // //     // Cancel previous subscription if any
// // // //     await _positionStream?.cancel();

// // // //     // Reference to the ride in Firebase
// // // //     //final rideRef = FirebaseDatabase.instance.ref("rides/$rideId");
// // // //     final db = FirebaseDatabase.instanceFor(app: passengerApp);
// // // //     final rideRef = db.ref("rides");

// // // //     // Settings for location updates
// // // //     const locationSettings = LocationSettings(
// // // //       accuracy: LocationAccuracy.high,
// // // //       distanceFilter: 5, // update every 5 meters
// // // //     );

// // // //     // Start listening to position updates
// // // //     _positionStream = Geolocator.getPositionStream(
// // // //       locationSettings: locationSettings,
// // // //     ).listen((position) async {
// // // //       try {
// // // //         await rideRef.update({
// // // //           "driverlocation": {
// // // //             "lat": position.latitude,
// // // //             "lng": position.longitude,
// // // //           },
// // // //         });
// // // //       } catch (e) {
// // // //         debugPrint("Error updating driver location: $e");
// // // //       }
// // // //     });
// // // //   }

// // // //   Future<void> _startRide() async {
// // // //     final user = FirebaseAuth.instance.currentUser;
// // // //     final idToken = await user?.getIdToken();

// // // //     final url = Uri.parse('$baseUrl/rides/${widget.rideId}/start');

// // // //     try {
// // // //       // 1. Call backend API
// // // //       final response = await http.post(
// // // //         url,
// // // //         headers: {
// // // //           'Content-Type': 'application/json',
// // // //           // 'Authorization': 'Bearer $idToken', // add back if you secure API
// // // //         },
// // // //         body: jsonEncode({"startTime": DateTime.now().toIso8601String()}),
// // // //       );

// // // //       if (response.statusCode == 200) {
// // // //         // 2. Update Firebase Realtime DB

// // // //         final db = FirebaseDatabase.instanceFor(app: passengerApp);
// // // //         final rideRef = db.ref("rides/${widget.rideId}");
// // // //         await rideRef.update({
// // // //           "status": "in_progress",
// // // //           "driverId": user?.uid,
// // // //           "riderId": widget.riderId,
// // // //           "pickup": {
// // // //             "lat": widget.pickupLat,
// // // //             "lng": widget.pickupLng,
// // // //             "name": widget.pickupName,
// // // //           },
// // // //           "destination": {
// // // //             "lat": widget.destLat,
// // // //             "lng": widget.destLng,
// // // //             "name": widget.destinationName,
// // // //           },

// // // //           "startTime": DateTime.now().toIso8601String(),
// // // //         });
// // // //         // Start real-time location tracking
// // // //         _startTrackingDriver(widget.rideId);

// // // //         // 3. Notify driver
// // // //         ScaffoldMessenger.of(context).showSnackBar(
// // // //           const SnackBar(content: Text("Ride started successfully")),
// // // //         );

// // // //         // 4. Navigate driver to live tracking
// // // //         Navigator.pushReplacement(
// // // //           context,
// // // //           MaterialPageRoute(
// // // //             builder:
// // // //                 (_) => LiveTrackingScreen(
// // // //                   rideId: widget.rideId,
// // // //                   pickup: LatLng(widget.pickupLat, widget.pickupLng),
// // // //                   destination: LatLng(widget.destLat, widget.destLng),
// // // //                 ),
// // // //           ),
// // // //         );
// // // //       } else {
// // // //         throw Exception("Failed to start ride");
// // // //       }
// // // //     } catch (e) {
// // // //       debugPrint("Start ride error: $e");
// // // //       ScaffoldMessenger.of(
// // // //         context,
// // // //       ).showSnackBar(SnackBar(content: Text("Error starting ride: $e")));
// // // //     }
// // // //   }

// // // //   Future<void> _loadRoute() async {
// // // //     final start = LatLng(widget.pickupLat, widget.pickupLng);
// // // //     final end = LatLng(widget.destLat, widget.destLng);

// // // //     final apiKey = mapKey;
// // // //     final url =
// // // //         "https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${end.latitude},${end.longitude}&mode=driving&key=$apiKey";

// // // //     try {
// // // //       final res = await http.get(Uri.parse(url));
// // // //       if (res.statusCode == 200) {
// // // //         final data = jsonDecode(res.body);

// // // //         if ((data["routes"] as List).isEmpty) return;

// // // //         final points = data["routes"][0]["overview_polyline"]["points"];
// // // //         final distance =
// // // //             data["routes"][0]["legs"][0]["distance"]["value"] / 1000;

// // // //         final polylinePoints = PolylinePoints().decodePolyline(points);

// // // //         setState(() {
// // // //           _distance = distance;
// // // //           _polylines.add(
// // // //             Polyline(
// // // //               polylineId: const PolylineId("route"),
// // // //               color: Colors.blue,
// // // //               width: 5,
// // // //               points:
// // // //                   polylinePoints
// // // //                       .map((p) => LatLng(p.latitude, p.longitude))
// // // //                       .toList(),
// // // //             ),
// // // //           );

// // // //           // _markers.add(
// // // //           //   Marker(
// // // //           //     markerId: const MarkerId("pickup"),
// // // //           //     position: start,
// // // //           //     icon: BitmapDescriptor.defaultMarkerWithHue(
// // // //           //       BitmapDescriptor.hueRed,
// // // //           //     ),
// // // //           //     infoWindow: InfoWindow(title: widget.pickupName),
// // // //           //   ),
// // // //           // );
// // // //           if (widget.pickupLat != null && widget.pickupLng != null) {
// // // //             _markers.add(
// // // //               Marker(
// // // //                 markerId: const MarkerId("pickup"),
// // // //                 position: LatLng(widget.pickupLat, widget.pickupLng),
// // // //                 icon: BitmapDescriptor.defaultMarkerWithHue(
// // // //                   BitmapDescriptor.hueRed,
// // // //                 ),
// // // //                 infoWindow: InfoWindow(title: widget.pickupName),
// // // //               ),
// // // //             );
// // // //           }

// // // //           _markers.add(
// // // //             Marker(
// // // //               markerId: const MarkerId("destination"),
// // // //               position: end,
// // // //               icon: BitmapDescriptor.defaultMarkerWithHue(
// // // //                 BitmapDescriptor.hueGreen,
// // // //               ),
// // // //               infoWindow: InfoWindow(title: widget.destinationName),
// // // //             ),
// // // //           );
// // // //         });

// // // //         _mapController?.animateCamera(
// // // //           CameraUpdate.newLatLngBounds(
// // // //             LatLngBounds(southwest: start, northeast: end),
// // // //             80,
// // // //           ),
// // // //         );
// // // //       }
// // // //     } catch (e) {
// // // //       debugPrint("Error loading route: $e");
// // // //     }
// // // //   }

// // // //   @override
// // // //   Widget build(BuildContext context) {
// // // //     final pickup = LatLng(widget.pickupLat, widget.pickupLng);

// // // //     return Scaffold(
// // // //       appBar: AppBar(
// // // //         automaticallyImplyLeading: false,
// // // //         title: const Text(
// // // //           "Trip Details",
// // // //           style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
// // // //         ),
// // // //         centerTitle: true,
// // // //         elevation: 0,
// // // //         backgroundColor: Colors.white,
// // // //       ),
// // // //       body: Column(
// // // //         children: [
// // // //           // MAP
// // // //           Expanded(
// // // //             flex: 3,
// // // //             child: GoogleMap(
// // // //               initialCameraPosition: CameraPosition(target: pickup, zoom: 14),
// // // //               onMapCreated: (controller) => _mapController = controller,
// // // //               markers: _markers,
// // // //               polylines: _polylines,
// // // //               myLocationEnabled: true,
// // // //               myLocationButtonEnabled: true,
// // // //             ),
// // // //           ),
// // // //           Expanded(
// // // //             flex: 2,
// // // //             child: Container(
// // // //               width: double.infinity,
// // // //               decoration: const BoxDecoration(
// // // //                 color: Colors.white,
// // // //                 borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
// // // //                 boxShadow: [
// // // //                   BoxShadow(
// // // //                     color: Colors.black12,
// // // //                     blurRadius: 10,
// // // //                     offset: Offset(0, -4),
// // // //                   ),
// // // //                 ],
// // // //               ),
// // // //               child: SafeArea(
// // // //                 child: Padding(
// // // //                   padding: const EdgeInsets.all(20.0),
// // // //                   child: SingleChildScrollView(
// // // //                     // ✅ Prevent overflow
// // // //                     child: Column(
// // // //                       crossAxisAlignment: CrossAxisAlignment.start,
// // // //                       children: [
// // // //                         // Rider + ID
// // // //                         Text(
// // // //                           "Ride ID: ${widget.rideId}",
// // // //                           style: const TextStyle(
// // // //                             fontSize: 18,
// // // //                             fontWeight: FontWeight.bold,
// // // //                             color: Colors.black54,
// // // //                           ),
// // // //                         ),
// // // //                         const SizedBox(height: 8),
// // // //                         Text(
// // // //                           "Rider: ${widget.rider}",
// // // //                           style: const TextStyle(
// // // //                             fontSize: 22,
// // // //                             fontWeight: FontWeight.w600,
// // // //                             color: Colors.black87,
// // // //                           ),
// // // //                         ),
// // // //                         const SizedBox(height: 16),

// // // //                         // Pickup + Destination
// // // //                         Row(
// // // //                           crossAxisAlignment: CrossAxisAlignment.start,
// // // //                           children: [
// // // //                             const Icon(
// // // //                               Icons.location_on,
// // // //                               color: Colors.red,
// // // //                               size: 28,
// // // //                             ),
// // // //                             const SizedBox(width: 8),
// // // //                             Expanded(
// // // //                               child: Text(
// // // //                                 "Pickup: ${widget.pickupName}",
// // // //                                 style: const TextStyle(fontSize: 18),
// // // //                               ),
// // // //                             ),
// // // //                           ],
// // // //                         ),
// // // //                         const SizedBox(height: 10),
// // // //                         Row(
// // // //                           crossAxisAlignment: CrossAxisAlignment.start,
// // // //                           children: [
// // // //                             const Icon(
// // // //                               Icons.flag,
// // // //                               color: Colors.green,
// // // //                               size: 28,
// // // //                             ),
// // // //                             const SizedBox(width: 8),
// // // //                             Expanded(
// // // //                               child: Text(
// // // //                                 "Destination: ${widget.destinationName}",
// // // //                                 style: const TextStyle(fontSize: 18),
// // // //                               ),
// // // //                             ),
// // // //                           ],
// // // //                         ),
// // // //                         const SizedBox(height: 16),

// // // //                         // Distance
// // // //                         if (_distance != null)
// // // //                           Text(
// // // //                             "Distance: ${_distance!.toStringAsFixed(2)} km",
// // // //                             style: const TextStyle(
// // // //                               fontSize: 20,
// // // //                               fontWeight: FontWeight.w500,
// // // //                               color: Colors.blueAccent,
// // // //                             ),
// // // //                           ),

// // // //                         const SizedBox(height: 20),

// // // //                         // Start Ride Button
// // // //                         SizedBox(
// // // //                           width: double.infinity,
// // // //                           child: ElevatedButton(
// // // //                             onPressed: _startRide,
// // // //                             style: ElevatedButton.styleFrom(
// // // //                               backgroundColor: Colors.blueAccent,
// // // //                               padding: const EdgeInsets.symmetric(vertical: 16),
// // // //                               shape: RoundedRectangleBorder(
// // // //                                 borderRadius: BorderRadius.circular(12),
// // // //                               ),
// // // //                             ),
// // // //                             child: const Text(
// // // //                               "Start Ride",
// // // //                               style: TextStyle(
// // // //                                 fontSize: 20,
// // // //                                 fontWeight: FontWeight.bold,
// // // //                                 color: Colors.white,
// // // //                               ),
// // // //                             ),
// // // //                           ),
// // // //                         ),
// // // //                       ],
// // // //                     ),
// // // //                   ),
// // // //                 ),
// // // //               ),
// // // //             ),
// // // //           ),
// // // //         ],
// // // //       ),
// // // //     );
// // // //   }
// // // // }
// // // // //   @override
// // // // //   Widget build(BuildContext context) {
// // // // //     final pickup = LatLng(widget.pickupLat, widget.pickupLng);

// // // // //     return WillPopScope(
// // // // //       onWillPop: () async {
// // // // //         // Always go to HomeScreen when phone back is pressed
// // // // //         Navigator.pushAndRemoveUntil(
// // // // //           context,
// // // // //           MaterialPageRoute(builder: (_) => const HomeScreen()),
// // // // //           (route) => false,
// // // // //         );
// // // // //         return false; // prevent default back
// // // // //       },
// // // // //       child: Scaffold(
// // // // //         appBar: AppBar(
// // // // //           title: const Text(
// // // // //             "Trip Details",
// // // // //             style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
// // // // //           ),
// // // // //           centerTitle: true,
// // // // //           elevation: 0,
// // // // //           backgroundColor: Colors.white,
// // // // //         ),
// // // // //         body: Column(
// // // // //           children: [
// // // // //             // MAP
// // // // //             Expanded(
// // // // //               flex: 3,
// // // // //               child: GoogleMap(
// // // // //                 initialCameraPosition: CameraPosition(target: pickup, zoom: 14),
// // // // //                 onMapCreated: (controller) => _mapController = controller,
// // // // //                 markers: _markers,
// // // // //                 polylines: _polylines,
// // // // //                 myLocationEnabled: true,
// // // // //                 myLocationButtonEnabled: true,
// // // // //               ),
// // // // //             ),
// // // // //             Expanded(
// // // // //               flex: 2,
// // // // //               child: Container(
// // // // //                 width: double.infinity,
// // // // //                 decoration: const BoxDecoration(
// // // // //                   color: Colors.white,
// // // // //                   borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
// // // // //                   boxShadow: [
// // // // //                     BoxShadow(
// // // // //                       color: Colors.black12,
// // // // //                       blurRadius: 10,
// // // // //                       offset: Offset(0, -4),
// // // // //                     ),
// // // // //                   ],
// // // // //                 ),
// // // // //                 child: SafeArea(
// // // // //                   child: Padding(
// // // // //                     padding: const EdgeInsets.all(20.0),
// // // // //                     child: SingleChildScrollView(
// // // // //                       // ✅ Prevent overflow
// // // // //                       child: Column(
// // // // //                         crossAxisAlignment: CrossAxisAlignment.start,
// // // // //                         children: [
// // // // //                           // Rider + ID
// // // // //                           Text(
// // // // //                             "Ride ID: ${widget.rideId}",
// // // // //                             style: const TextStyle(
// // // // //                               fontSize: 18,
// // // // //                               fontWeight: FontWeight.bold,
// // // // //                               color: Colors.black54,
// // // // //                             ),
// // // // //                           ),
// // // // //                           const SizedBox(height: 8),
// // // // //                           Text(
// // // // //                             "Rider: ${widget.rider}",
// // // // //                             style: const TextStyle(
// // // // //                               fontSize: 22,
// // // // //                               fontWeight: FontWeight.w600,
// // // // //                               color: Colors.black87,
// // // // //                             ),
// // // // //                           ),
// // // // //                           const SizedBox(height: 16),

// // // // //                           // Pickup + Destination
// // // // //                           Row(
// // // // //                             crossAxisAlignment: CrossAxisAlignment.start,
// // // // //                             children: [
// // // // //                               const Icon(
// // // // //                                 Icons.location_on,
// // // // //                                 color: Colors.red,
// // // // //                                 size: 28,
// // // // //                               ),
// // // // //                               const SizedBox(width: 8),
// // // // //                               Expanded(
// // // // //                                 child: Text(
// // // // //                                   "Pickup: ${widget.pickupName}",
// // // // //                                   style: const TextStyle(fontSize: 18),
// // // // //                                 ),
// // // // //                               ),
// // // // //                             ],
// // // // //                           ),
// // // // //                           const SizedBox(height: 10),
// // // // //                           Row(
// // // // //                             crossAxisAlignment: CrossAxisAlignment.start,
// // // // //                             children: [
// // // // //                               const Icon(
// // // // //                                 Icons.flag,
// // // // //                                 color: Colors.green,
// // // // //                                 size: 28,
// // // // //                               ),
// // // // //                               const SizedBox(width: 8),
// // // // //                               Expanded(
// // // // //                                 child: Text(
// // // // //                                   "Destination: ${widget.destinationName}",
// // // // //                                   style: const TextStyle(fontSize: 18),
// // // // //                                 ),
// // // // //                               ),
// // // // //                             ],
// // // // //                           ),
// // // // //                           const SizedBox(height: 16),

// // // // //                           // Distance
// // // // //                           if (_distance != null)
// // // // //                             Text(
// // // // //                               "Distance: ${_distance!.toStringAsFixed(2)} km",
// // // // //                               style: const TextStyle(
// // // // //                                 fontSize: 20,
// // // // //                                 fontWeight: FontWeight.w500,
// // // // //                                 color: Colors.blueAccent,
// // // // //                               ),
// // // // //                             ),

// // // // //                           const SizedBox(height: 20),

// // // // //                           // Start Ride Button
// // // // //                           SizedBox(
// // // // //                             width: double.infinity,
// // // // //                             child: ElevatedButton(
// // // // //                               onPressed: _startRide,
// // // // //                               style: ElevatedButton.styleFrom(
// // // // //                                 backgroundColor: Colors.blueAccent,
// // // // //                                 padding: const EdgeInsets.symmetric(
// // // // //                                   vertical: 16,
// // // // //                                 ),
// // // // //                                 shape: RoundedRectangleBorder(
// // // // //                                   borderRadius: BorderRadius.circular(12),
// // // // //                                 ),
// // // // //                               ),
// // // // //                               child: const Text(
// // // // //                                 "Start Ride",
// // // // //                                 style: TextStyle(
// // // // //                                   fontSize: 20,
// // // // //                                   fontWeight: FontWeight.bold,
// // // // //                                   color: Colors.white,
// // // // //                                 ),
// // // // //                               ),
// // // // //                             ),
// // // // //                           ),
// // // // //                         ],
// // // // //                       ),
// // // // //                     ),
// // // // //                   ),
// // // // //                 ),
// // // // //               ),
// // // // //             ),
// // // // //           ],
// // // // //         ),
// // // // //       ),
// // // // //     );
// // // // //   }
// // // // // }

// // // // // //   @override
// // // // // //   Widget build(BuildContext context) {
// // // // // //     final pickup = LatLng(widget.pickupLat, widget.pickupLng);

// // // // // //     return Scaffold(
// // // // // //       appBar: AppBar(title: const Text("Trip Details"), centerTitle: true),
// // // // // //       body: Column(
// // // // // //         children: [
// // // // // //           Expanded(
// // // // // //             flex: 2,
// // // // // //             child: GoogleMap(
// // // // // //               initialCameraPosition: CameraPosition(target: pickup, zoom: 14),
// // // // // //               onMapCreated: (controller) => _mapController = controller,
// // // // // //               markers: _markers,
// // // // // //               polylines: _polylines,
// // // // // //               myLocationEnabled: true,
// // // // // //               myLocationButtonEnabled: true,
// // // // // //             ),
// // // // // //           ),
// // // // // //           Expanded(
// // // // // //             flex: 1,
// // // // // //             child: Padding(
// // // // // //               padding: const EdgeInsets.all(16.0),
// // // // // //               child: Column(
// // // // // //                 crossAxisAlignment: CrossAxisAlignment.start,
// // // // // //                 children: [
// // // // // //                   Text(
// // // // // //                     "Ride ID: ${widget.rideId}",
// // // // // //                     style: const TextStyle(fontWeight: FontWeight.bold),
// // // // // //                   ),
// // // // // //                   Text("Rider: ${widget.rider}"),
// // // // // //                   Text("Pickup: ${widget.pickupName}"),
// // // // // //                   Text("Destination: ${widget.destinationName}"),
// // // // // //                   if (_distance != null)
// // // // // //                     Text("Distance: ${_distance!.toStringAsFixed(2)} km"),
// // // // // //                   const SizedBox(height: 10),
// // // // // //                   ElevatedButton(
// // // // // //                     onPressed: _startRide,
// // // // // //                     child: const Text("Start Ride"),
// // // // // //                   ),
// // // // // //                 ],
// // // // // //               ),
// // // // // //             ),
// // // // // //           ),
// // // // // //         ],
// // // // // //       ),
// // // // // //     );
// // // // // //   }
// // // // // // }

// // // // // //   Future<void> _loadRoute() async {
// // // // // //     final start = LatLng(widget.pickupLat, widget.pickupLng);
// // // // // //     final end = LatLng(widget.destLat, widget.destLng);

// // // // // //     final url =
// // // // // //         'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';

// // // // // //     try {
// // // // // //       final res = await http.get(Uri.parse(url));
// // // // // //       if (res.statusCode == 200) {
// // // // // //         final data = jsonDecode(res.body);
// // // // // //         final coords = data['routes'][0]['geometry']['coordinates'] as List;
// // // // // //         final distance = data['routes'][0]['distance'] / 1000;

// // // // // //         setState(() {
// // // // // //           _routePoints = coords.map((c) => LatLng(c[1], c[0])).toList();
// // // // // //           _distance = distance;
// // // // // //         });

// // // // // //         _fitMapBounds(start, end);
// // // // // //       } else {
// // // // // //         throw Exception('Failed to load route');
// // // // // //       }
// // // // // //     } catch (e) {
// // // // // //       debugPrint('Error loading route: $e');
// // // // // //     }
// // // // // //   }

// // // // // //   void _fitMapBounds(LatLng start, LatLng end) {
// // // // // //     final bounds = LatLngBounds(
// // // // // //       LatLng(
// // // // // //         min(start.latitude, end.latitude),
// // // // // //         min(start.longitude, end.longitude),
// // // // // //       ),
// // // // // //       LatLng(
// // // // // //         max(start.latitude, end.latitude),
// // // // // //         max(start.longitude, end.longitude),
// // // // // //       ),
// // // // // //     );

// // // // // //     _mapController.fitBounds(
// // // // // //       bounds,
// // // // // //       options: const FitBoundsOptions(padding: EdgeInsets.all(50)),
// // // // // //     );
// // // // // //   }

// // // // // //   @override
// // // // // //   Widget build(BuildContext context) {
// // // // // //     final pickupPoint = LatLng(widget.pickupLat, widget.pickupLng);
// // // // // //     final destinationPoint = LatLng(widget.destLat, widget.destLng);
// // // // // //     final bool isDark = Theme.of(context).brightness == Brightness.dark;
// // // // // //     final Color textColor = isDark ? Colors.white : Colors.black;
// // // // // //     return Scaffold(
// // // // // //       backgroundColor: Colors.white,
// // // // // //       appBar: AppBar(
// // // // // //         title: const Text("Trip Details"),
// // // // // //         centerTitle: true,
// // // // // //         backgroundColor: Colors.white,
// // // // // //         elevation: 0,
// // // // // //         foregroundColor: Colors.black,
// // // // // //       ),
// // // // // //       body: Column(
// // // // // //         children: [
// // // // // //           Expanded(
// // // // // //             flex: 2,
// // // // // //             child: FlutterMap(
// // // // // //               mapController: _mapController,
// // // // // //               options: MapOptions(center: pickupPoint, zoom: 14.0),
// // // // // //               children: [
// // // // // //                 TileLayer(
// // // // // //                   urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
// // // // // //                   userAgentPackageName: 'com.example.aminidriver',
// // // // // //                 ),
// // // // // //                 if (_routePoints.isNotEmpty)
// // // // // //                   PolylineLayer(
// // // // // //                     polylines: [
// // // // // //                       Polyline(
// // // // // //                         points: _routePoints,
// // // // // //                         strokeWidth: 4.0,
// // // // // //                         color: Colors.blue,
// // // // // //                       ),
// // // // // //                     ],
// // // // // //                   ),
// // // // // //                 MarkerLayer(
// // // // // //                   markers: [
// // // // // //                     Marker(
// // // // // //                       point: pickupPoint,
// // // // // //                       width: 40,
// // // // // //                       height: 40,
// // // // // //                       builder:
// // // // // //                           (context) => Icon(
// // // // // //                             Icons.location_pin,
// // // // // //                             color: Colors.red,
// // // // // //                             size: 40,
// // // // // //                           ),
// // // // // //                     ),
// // // // // //                     Marker(
// // // // // //                       point: destinationPoint,
// // // // // //                       width: 40,
// // // // // //                       height: 40,
// // // // // //                       builder:
// // // // // //                           (context) =>
// // // // // //                               Icon(Icons.flag, color: Colors.green, size: 40),
// // // // // //                     ),
// // // // // //                   ],
// // // // // //                 ),
// // // // // //               ],
// // // // // //             ),
// // // // // //           ),
// // // // // //           Expanded(
// // // // // //             flex: 1,
// // // // // //             child: Padding(
// // // // // //               padding: const EdgeInsets.all(16.0),
// // // // // //               child: Column(
// // // // // //                 crossAxisAlignment: CrossAxisAlignment.start,
// // // // // //                 children: [
// // // // // //                   Text(
// // // // // //                     "Ride ID: ${widget.rideId}",
// // // // // //                     style: const TextStyle(fontWeight: FontWeight.bold),
// // // // // //                   ),

// // // // // //                   const SizedBox(height: 8),
// // // // // //                   Text("Rider: ${widget.rider}"),
// // // // // //                   Text("Pickup: ${widget.pickupName}"),
// // // // // //                   Text("Destination: ${widget.destinationName}"),
// // // // // //                   if (_distance != null)
// // // // // //                     Text("Distance: ${_distance!.toStringAsFixed(2)} km"),

// // // // // //                   SizedBox(
// // // // // //                     width: double.infinity,
// // // // // //                     child: ElevatedButton(
// // // // // //                       style: ElevatedButton.styleFrom(
// // // // // //                         backgroundColor: Colors.grey[700],
// // // // // //                         foregroundColor: Colors.white,
// // // // // //                         padding: const EdgeInsets.symmetric(vertical: 16),
// // // // // //                       ),
// // // // // //                       onPressed: () {
// // // // // //                         // Launch turn-by-turn nav or start logic
// // // // // //                       },
// // // // // //                       child: const Text("Navigate"),
// // // // // //                     ),
// // // // // //                   ),
// // // // // //                   const SizedBox(height: 8),
// // // // // //                   SizedBox(
// // // // // //                     width: double.infinity,
// // // // // //                     child: ElevatedButton(
// // // // // //                       style: ElevatedButton.styleFrom(
// // // // // //                         backgroundColor: Colors.grey[700],
// // // // // //                         foregroundColor: Colors.white,
// // // // // //                         padding: const EdgeInsets.symmetric(vertical: 16),
// // // // // //                       ),
// // // // // //                       onPressed: _startRide,
// // // // // //                       child: const Text("Start Ride"),
// // // // // //                     ),
// // // // // //                   ),
// // // // // //                 ],
// // // // // //               ),
// // // // // //             ),
// // // // // //           ),
// // // // // //         ],
// // // // // //       ),
// // // // // //     );
// // // // // //   }
// // // // // // }
