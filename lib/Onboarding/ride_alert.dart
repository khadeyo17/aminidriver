import 'dart:async';
import 'dart:convert';
import 'package:aminidriver/Container/utils/keys.dart';
import 'package:aminidriver/Container/utils/pending_ride_storage.dart';
import 'package:aminidriver/Onboarding/trip_detail_screen.dart';
import 'package:aminidriver/View/Screens/Nav_Screens/navigation_screen.dart';
import 'package:aminidriver/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RideAlertScreen extends StatefulWidget {
  final String rideId;
  final String rideRequestId;
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
    required this.rideRequestId,
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

class _RideAlertScreenState extends State<RideAlertScreen>
    with SingleTickerProviderStateMixin {
  int _remaining = 30;

  Timer? _timer;
  Timer? _vibrationTimer;

  final AudioPlayer _audioPlayer = AudioPlayer();

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _startCountdown();
    _startVibration();
    _startRingtone();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _vibrationTimer?.cancel();
    _audioPlayer.stop();
    _pulseController.dispose();
    super.dispose();
  }

  // ⏳ COUNTDOWN
  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining > 0) {
        setState(() => _remaining--);
      } else {
        timer.cancel();
        _rejectRide(auto: true);
      }
    });
  }

  // 📳 CONTROLLED VIBRATION
  void _startVibration() {
    _vibrationTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      HapticFeedback.vibrate();
    });
  }

  void _stopAlerts() {
    _timer?.cancel();
    _vibrationTimer?.cancel();
    _audioPlayer.stop();
    notificationsPlugin.cancel(999);
  }

  // 🔊 REAL RINGTONE (use asset)
  Future<void> _startRingtone() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(
      AssetSource('ringtones/ringtone.mp3'), // ✅ use asset
      volume: 1.0,
    );
  }

  // ✅ ACCEPT
  Future<void> _acceptRide() async {
    _stopAlerts();

    final user = FirebaseAuth.instance.currentUser;
    final position = await Geolocator.getCurrentPosition();

    await http.post(
      Uri.parse('$baseUrl/rides/driver/accept-ride'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'rideId': int.parse(widget.rideId),
        'firebaseIdToken': user?.uid,
        'latitude': position.latitude,
        'longitude': position.longitude,
      }),
    );

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
              mobile: '',
              riderId: '',
            ),
      ),
    );
  }

  // ❌ REJECT
  Future<void> _rejectRide({bool auto = false}) async {
    _stopAlerts();

    await http.post(
      Uri.parse('$baseUrl/rides/reject-ride'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'rideId': widget.rideId}),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const NavigationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Color(0xFF1A1A1A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: 20),

              /// 🔥 PULSING AVATAR
              ScaleTransition(
                scale: Tween(begin: 1.0, end: 1.2).animate(_pulseController),
                child: const CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, size: 40),
                ),
              ),

              /// 🚖 RIDER INFO
              Column(
                children: [
                  Text(
                    widget.rider,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Incoming Ride",
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),

              /// ⏳ COUNTDOWN CIRCLE
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      value: _remaining / 30,
                      strokeWidth: 6,
                      color: Colors.green,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                  Text(
                    "$_remaining",
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ],
              ),

              /// 📍 LOCATIONS CARD
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _location(widget.pickupName, Colors.green),
                    const SizedBox(height: 10),
                    _location(widget.destinationName, Colors.red),
                  ],
                ),
              ),

              /// ☎️ ACTION BUTTONS
              Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _callButton(
                      icon: Icons.close,
                      color: Colors.red,
                      onTap: _rejectRide,
                    ),
                    _callButton(
                      icon: Icons.check,
                      color: Colors.green,
                      onTap: _acceptRide,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _location(String text, Color color) {
    return Row(
      children: [
        Icon(Icons.circle, color: color, size: 12),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _callButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: 38,
        backgroundColor: color,
        child: Icon(icon, color: Colors.white, size: 32),
      ),
    );
  }
}

// class _RideAlertScreenState extends State<RideAlertScreen> {
//   int _remaining = 30;
//   Timer? _timer;
//   final AudioPlayer _audioPlayer = AudioPlayer();
//   @override
//   void initState() {
//     super.initState();
//     _startCountdown();
//     _startVibration();
//     _startRingtone();
//   }

//   // 🔔 REAL CALL VIBRATION
//   void _startVibration() {
//     // HapticFeedback to simulate short vibrations repeatedly
//     Timer.periodic(const Duration(milliseconds: 2000), (timer) {
//       HapticFeedback.vibrate();
//     });
//   }
//   // void _stopAlerts() {
//   //   Vibration.cancel();
//   //   FlutterLocalNotificationsPlugin().cancelAll();
//   // }

//   void _stopAlerts() {
//     //Vibration.cancel();
//     _audioPlayer.stop();
//     notificationsPlugin.cancel(999);
//   }

//   void _startRingtone() async {
//     const ringtoneUrl =
//         'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';

//     await _audioPlayer.play(UrlSource(ringtoneUrl), volume: 1.0);
//     _audioPlayer.setReleaseMode(ReleaseMode.loop);
//     // await _audioPlayer.setReleaseMode(ReleaseMode.loop); // loop sound
//     // await _audioPlayer.play(
//     //   AssetSource('sounds/ringtone.mp3'),
//     // ); // place ringtone.mp3 in assets/sounds/
//   }

//   void _stopRingtone() async {
//     await _audioPlayer.stop();
//   }

//   void _startCountdown() {
//     _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       if (_remaining > 0) {
//         setState(() => _remaining--);
//       } else {
//         timer.cancel();
//         _rejectRide(auto: true);
//       }
//     });
//   }

//   Future<void> _acceptRide() async {
//     _timer?.cancel();
//     _stopAlerts();
//     _stopRingtone();

//     final user = FirebaseAuth.instance.currentUser;
//     final position = await Geolocator.getCurrentPosition();

//     await http.post(
//       Uri.parse('$baseUrl/rides/driver/accept-ride'),
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode({
//         'rideId': int.parse(widget.rideId),
//         'firebaseIdToken': user?.uid,
//         'latitude': position.latitude,
//         'longitude': position.longitude,
//       }),
//     );

//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(
//         builder:
//             (_) => TripDetailScreen(
//               rideId: widget.rideId,
//               rider: widget.rider,
//               pickupName: widget.pickupName,
//               destinationName: widget.destinationName,
//               pickupLat: widget.pickupLat,
//               pickupLng: widget.pickupLng,
//               destLat: widget.destLat,
//               destLng: widget.destLng,
//               mobile: '',
//               riderId: '',
//             ),
//       ),
//     );
//   }

//   Future<void> _rejectRide({bool auto = false}) async {
//     _timer?.cancel();
//     _stopAlerts();

//     await http.post(
//       Uri.parse('$baseUrl/rides/reject-ride'),
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode({'rideId': widget.rideId}),
//     );

//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(builder: (_) => const NavigationScreen()),
//     );
//   }

//   @override
//   void dispose() {
//     _timer?.cancel();
//     _stopAlerts();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: SafeArea(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             const SizedBox(height: 40),

//             // 🚖 CALL HEADER
//             Column(
//               children: [
//                 const Icon(Icons.phone_in_talk, color: Colors.green, size: 80),
//                 const SizedBox(height: 20),
//                 Text(
//                   widget.rider,
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontSize: 32,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 10),
//                 Text(
//                   "Incoming Ride Call",
//                   style: TextStyle(color: Colors.grey.shade400, fontSize: 18),
//                 ),
//                 const SizedBox(height: 20),
//                 Text(
//                   "$_remaining sec",
//                   style: const TextStyle(color: Colors.red, fontSize: 22),
//                 ),
//               ],
//             ),

//             // 📍 INFO
//             Column(
//               children: [
//                 Text(
//                   widget.pickupName,
//                   style: const TextStyle(color: Colors.white, fontSize: 20),
//                 ),
//                 const Icon(Icons.arrow_downward, color: Colors.grey),
//                 Text(
//                   widget.destinationName,
//                   style: const TextStyle(color: Colors.white, fontSize: 20),
//                 ),
//               ],
//             ),

//             // ☎️ CALL BUTTONS
//             Padding(
//               padding: const EdgeInsets.only(bottom: 40),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                 children: [
//                   _callButton(
//                     icon: Icons.call_end,
//                     color: Colors.red,
//                     label: "Decline",
//                     onTap: _rejectRide,
//                   ),
//                   _callButton(
//                     icon: Icons.call,
//                     color: Colors.green,
//                     label: "Accept",
//                     onTap: _acceptRide,
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _callButton({
//     required IconData icon,
//     required Color color,
//     required String label,
//     required VoidCallback onTap,
//   }) {
//     return Column(
//       children: [
//         GestureDetector(
//           onTap: onTap,
//           child: CircleAvatar(
//             radius: 38,
//             backgroundColor: color,
//             child: Icon(icon, color: Colors.white, size: 32),
//           ),
//         ),
//         const SizedBox(height: 10),
//         Text(label, style: const TextStyle(color: Colors.white)),
//       ],
//     );
//   }
// }





// class RideAlertScreen extends StatefulWidget {
//   final String rideId;
//   final String rideRequestId;
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
//     required this.rideRequestId,
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
//   final AudioPlayer _audioPlayer = AudioPlayer();
//   GoogleMapController? _mapController;
//   late CameraPosition _initialCamera;

//   @override
//   void initState() {
//     super.initState();
//     _initialCamera = CameraPosition(
//       target: LatLng(widget.pickupLat, widget.pickupLng),
//       zoom: 13,
//     );
//     _startCountdown();
//     _playRingtone();
//     _checkPendingRide();
//   }

//   Future<void> _checkPendingRide() async {
//     final pendingRide = await getPendingRide();
//     if (pendingRide == null) {
//       if (!mounted) return;
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (_) => const NavigationScreen()),
//       );
//     }
//   }

//   void _playRingtone() async {
//     const ringtoneUrl =
//         'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';

//     await _audioPlayer.play(UrlSource(ringtoneUrl), volume: 1.0);
//     _audioPlayer.setReleaseMode(ReleaseMode.loop);
//   }

//   void _stopRingtone() {
//     _audioPlayer.stop();
//   }

//   void _startCountdown() {
//     _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       if (_remaining > 0) {
//         setState(() => _remaining--);
//       } else {
//         timer.cancel();
//         _rejectRide(context, auto: true);
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (_) => const NavigationScreen()),
//         );
//       }
//     });
//   }

  

//   Future<void> _acceptRide(BuildContext context) async {
//     _timer?.cancel();
//     _stopRingtone();

//     final user = FirebaseAuth.instance.currentUser;
//     final position = await _getCurrentPosition();

//     final response = await http.post(
//       Uri.parse('$baseUrl/rides/driver/accept-ride'),
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode({
//         'rideId': int.parse(widget.rideId),
//         'firebaseIdToken': user?.uid,
//         'latitude': position.latitude,
//         'longitude': position.longitude,
//       }),
//     );

//     if (response.statusCode == 200) {
//       final data = jsonDecode(response.body);
//       //DriverLocationService().startSendingLocation();

//       final passengerDb = FirebaseDatabase.instanceFor(app: passengerApp);
//       final dbRef = passengerDb.ref("rideRequests/${data['rideRequestId']}");

//       final snapshot = await dbRef.get();

//       // final rideRef = FirebaseDatabase.instance.ref(
//       //   "rideRequests/${data['rideRequestId']}", //rideRequestId
//       // );
//       await dbRef.update({
//         "status": "assigned",
//         "driverId": user?.uid,
//         "rideId": data['rideId'].toString(),
//         "riderName": data['riderName'].toString(),
//         "passmobile": data['mobile'].toString(),
//         "pickup": {
//           "lat": widget.pickupLat,
//           "lng": widget.pickupLng,
//           "name": widget.pickupName,
//         },
//         "destination": {
//           "lat": widget.destLat,
//           "lng": widget.destLng,
//           "name": widget.destinationName,
//         },

//         "startTime": DateTime.now().toIso8601String(),
//       });

//       // final realRideRef = FirebaseDatabase.instance.ref(
//       //   "rides/${data['rideId']}",
//       // );

//       final realRideRef = passengerDb.ref("rides/${data['rideId']}");
//       // final snapshot = await realRideRefg.get();
//       await realRideRef.update({
//         "status": "assigned",
//         "driverId": user?.uid,
//         "riderId": data['riderId'],
//         "riderName": data['riderName'].toString(),
//         "passmobile": data['mobile'].toString(),
//         // passenger id
//         "pickup": {
//           "lat": widget.pickupLat,
//           "lng": widget.pickupLng,
//           "name": widget.pickupName,
//         },
//         "destination": {
//           "lat": widget.destLat,
//           "lng": widget.destLng,
//           "name": widget.destinationName,
//         },
//         "driverlocation": {"lat": position.latitude, "lng": position.longitude},
//         "startTime": DateTime.now().toIso8601String(),
//       });

//       Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder:
//               (_) => TripDetailScreen(
//                 rideId: data['rideId'].toString(), // rideId//widget.rideId,
//                 rider: data['riderName'].toString(), //widget.rider,
//                 mobile: data['mobile'].toString(),
//                 riderId: data['riderId'],
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
//     _stopRingtone();

//     final user = FirebaseAuth.instance.currentUser;
//     final response = await http.post(
//       Uri.parse('$baseUrl/rides/reject-ride'),
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode({'rideId': widget.rideId, 'firebaseToken': user?.uid}),
//     );

//     if (!mounted) return;
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (_) => const NavigationScreen()),
//       //(route) => false,
//     );

//     if (response.statusCode != 200) {
//       final data = jsonDecode(response.body);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(data['message'] ?? 'Failed to reject ride')),
//       );
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Ride rejected successfully")),
//       );
//     }

//     if (auto) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text("⏳ Ride request expired")));
//     }
//   }

//   Future<Position> _getCurrentPosition() async {
//     Position? lastPosition = await Geolocator.getLastKnownPosition();
//     if (lastPosition != null) return lastPosition;

//     return await Geolocator.getCurrentPosition(
//       desiredAccuracy: LocationAccuracy.high,
//     );
//   }

//   @override
//   void dispose() {
//     _timer?.cancel();
//     _stopRingtone();
//     _mapController?.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     Set<Marker> markers = {};
//     if (widget.pickupName.isNotEmpty) {
//       markers.add(
//         Marker(
//           markerId: const MarkerId('pickup'),
//           position: LatLng(widget.pickupLat, widget.pickupLng),
//           infoWindow: InfoWindow(title: 'Pickup: ${widget.pickupName}'),
//           icon: BitmapDescriptor.defaultMarkerWithHue(
//             BitmapDescriptor.hueGreen,
//           ),
//         ),
//       );
//     }
//     if (widget.destinationName.isNotEmpty) {
//       markers.add(
//         Marker(
//           markerId: const MarkerId('destination'),
//           position: LatLng(widget.destLat, widget.destLng),
//           infoWindow: InfoWindow(
//             title: 'Destination: ${widget.destinationName}',
//           ),
//           icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
//         ),
//       );
//     }

//     return Scaffold(
//       backgroundColor: Colors.grey.shade200,
//       body: Center(
//         child: Card(
//           margin: const EdgeInsets.symmetric(horizontal: 20),
//           elevation: 12,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(25),
//           ),
//           child: Padding(
//             padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 const Icon(
//                   Icons.directions_car_filled,
//                   size: 80,
//                   color: Colors.green,
//                 ),
//                 const SizedBox(height: 20),
//                 Text(
//                   "New Ride Request",
//                   style: TextStyle(
//                     fontSize: 28,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.green.shade700,
//                   ),
//                 ),
//                 const SizedBox(height: 15),

//                 if (widget.pickupName.isNotEmpty)
//                   _buildInfoRow(
//                     Icons.location_pin,
//                     "Pickup",
//                     widget.pickupName,
//                   ),

//                 if (widget.destinationName.isNotEmpty)
//                   _buildInfoRow(
//                     Icons.flag,
//                     "Destination",
//                     widget.destinationName,
//                   ),

//                 const SizedBox(height: 20),

//                 // Google Maps mini preview
//                 SizedBox(
//                   height: 180,
//                   child: ClipRRect(
//                     borderRadius: BorderRadius.circular(15),
//                     child: GoogleMap(
//                       initialCameraPosition: _initialCamera,
//                       markers: markers,
//                       myLocationButtonEnabled: false,
//                       zoomControlsEnabled: false,
//                       onMapCreated: (controller) {
//                         _mapController = controller;
//                       },
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 20),
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                     vertical: 15,
//                     horizontal: 25,
//                   ),
//                   decoration: BoxDecoration(
//                     color: Colors.red.shade100,
//                     borderRadius: BorderRadius.circular(30),
//                   ),
//                   child: Text(
//                     "⏳ $_remaining seconds left",
//                     style: const TextStyle(
//                       fontSize: 24,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.red,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 20),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: ElevatedButton(
//                         onPressed: () => _rejectRide(context),
//                         style: ElevatedButton.styleFrom(
//                           padding: const EdgeInsets.symmetric(vertical: 18),
//                           backgroundColor: Colors.red.shade400,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(20),
//                           ),
//                         ),
//                         child: const Text(
//                           "Reject",
//                           style: TextStyle(fontSize: 20),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 20),
//                     Expanded(
//                       child: ElevatedButton(
//                         onPressed: () => _acceptRide(context),
//                         style: ElevatedButton.styleFrom(
//                           padding: const EdgeInsets.symmetric(vertical: 18),
//                           backgroundColor: Colors.green.shade600,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(20),
//                           ),
//                         ),
//                         child: const Text(
//                           "Accept",
//                           style: TextStyle(fontSize: 20),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildInfoRow(IconData icon, String title, String value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 5),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Icon(icon, color: Colors.green.shade700, size: 28),
//           const SizedBox(width: 10),
//           Text(
//             "$title: ",
//             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
//           ),
//           Expanded(
//             child: Text(
//               value,
//               style: const TextStyle(fontSize: 20),
//               softWrap: true,
//               overflow: TextOverflow.visible, // ✅ full text, no cut
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }




// import 'dart:async';
// import 'dart:convert';
// //import 'dart:js_interop';
// import 'package:aminidriver/Container/utils/keys.dart';
// import 'package:aminidriver/Container/utils/pending_ride_storage.dart';
// import 'package:aminidriver/Onboarding/trip_detail_screen.dart';
// import 'package:aminidriver/View/Screens/Nav_Screens/navigation_screen.dart';
// import 'package:aminidriver/main.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:http/http.dart' as http;
// import 'package:audioplayers/audioplayers.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';

// class RideAlertScreen extends StatefulWidget {
//   final String rideId;
//   final String rideRequestId;
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
//     required this.rideRequestId,
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
//   final AudioPlayer _audioPlayer = AudioPlayer();
//   GoogleMapController? _mapController;
//   late CameraPosition _initialCamera;

//   @override
//   void initState() {
//     super.initState();
//     _initialCamera = CameraPosition(
//       target: LatLng(widget.pickupLat, widget.pickupLng),
//       zoom: 13,
//     );
//     _startCountdown();
//     _playRingtone();

//     _checkPendingRide();
//   }

//   Future<void> _checkPendingRide() async {
//     final pendingRide = await getPendingRide();
//     if (pendingRide == null) {
//       if (!mounted) return;
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (_) => NavigationScreen()),
//       );
//     }
//   }

//   // void _playRingtone() async {
//   //   await _audioPlayer.play(AssetSource('assets/ringtone.mp3'), volume: 1.0);
//   //   _audioPlayer.setReleaseMode(ReleaseMode.loop);
//   // }
//   void _playRingtone() async {
//     const ringtoneUrl =
//         'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';

//     await _audioPlayer.play(UrlSource(ringtoneUrl), volume: 1.0);
//     _audioPlayer.setReleaseMode(ReleaseMode.loop);
//   }

//   void _stopRingtone() {
//     _audioPlayer.stop();
//   }

//   void _startCountdown() {
//     _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       if (_remaining > 0) {
//         setState(() => _remaining--);
//       } else {
//         timer.cancel();
//         _rejectRide(context, auto: true);
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (_) => NavigationScreen()),
//         );
//       }
//     });
//   }

//   Future<void> _acceptRide(BuildContext context) async {
//     _timer?.cancel();
//     _stopRingtone();

//     final user = FirebaseAuth.instance.currentUser;
//     final position = await _getCurrentPosition();

//     final response = await http.post(
//       Uri.parse('$baseUrl/rides/driver/accept-ride'),
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode({
//         'rideId': int.parse(widget.rideId),
//         'firebaseIdToken': user?.uid,
//         'latitude': position.latitude,
//         'longitude': position.longitude,
//       }),
//     );

//     if (response.statusCode == 200) {
//       final data = jsonDecode(response.body);
//       //DriverLocationService().startSendingLocation();

//       final passengerDb = FirebaseDatabase.instanceFor(app: passengerApp);
//       final dbRef = passengerDb.ref("rideRequests/${data['rideRequestId']}");

//       final snapshot = await dbRef.get();

//       // final rideRef = FirebaseDatabase.instance.ref(
//       //   "rideRequests/${data['rideRequestId']}", //rideRequestId
//       // );
//       await dbRef.update({
//         "status": "assigned",
//         "driverId": user?.uid,
//         "rideId": data['rideId'].toString(),
//         "riderName": data['riderName'].toString(),
//         "passmobile": data['mobile'].toString(),
//         "pickup": {
//           "lat": widget.pickupLat,
//           "lng": widget.pickupLng,
//           "name": widget.pickupName,
//         },
//         "destination": {
//           "lat": widget.destLat,
//           "lng": widget.destLng,
//           "name": widget.destinationName,
//         },

//         "startTime": DateTime.now().toIso8601String(),
//       });

//       // final realRideRef = FirebaseDatabase.instance.ref(
//       //   "rides/${data['rideId']}",
//       // );

//       final realRideRef = passengerDb.ref("rides/${data['rideId']}");
//       // final snapshot = await realRideRefg.get();
//       await realRideRef.update({
//         "status": "assigned",
//         "driverId": user?.uid,
//         "riderId": data['riderId'],
//         "riderName": data['riderName'].toString(),
//         "passmobile": data['mobile'].toString(),
//         // passenger id
//         "pickup": {
//           "lat": widget.pickupLat,
//           "lng": widget.pickupLng,
//           "name": widget.pickupName,
//         },
//         "destination": {
//           "lat": widget.destLat,
//           "lng": widget.destLng,
//           "name": widget.destinationName,
//         },
//         "driverlocation": {"lat": position.latitude, "lng": position.longitude},
//         "startTime": DateTime.now().toIso8601String(),
//       });

//       // Navigator.push(
//       //   context,
//       //   MaterialPageRoute(
//       //     builder:
//       //         (_) => TripDetailScreen(
//       //           rideId: data['rideId'].toString(), // rideId//widget.rideId,
//       //           rider: data['riderName'].toString(), //widget.rider,
//       //           mobile: data['mobile'].toString(),
//       //           riderId: data['riderId'],
//       //           pickupName: widget.pickupName,
//       //           destinationName: widget.destinationName,
//       //           pickupLat: widget.pickupLat,
//       //           pickupLng: widget.pickupLng,
//       //           destLat: widget.destLat,
//       //           destLng: widget.destLng,
//       //         ),
//       //   ),
//       // );

//       Navigator.pushAndRemoveUntil(
//         context,
//         MaterialPageRoute(
//           builder:
//               (_) => TripDetailScreen(
//                 rideId: data['rideId'].toString(),
//                 rider: data['riderName'].toString(),
//                 mobile: data['mobile'].toString(),
//                 riderId: data['riderId'],
//                 pickupName: widget.pickupName,
//                 destinationName: widget.destinationName,
//                 pickupLat: widget.pickupLat,
//                 pickupLng: widget.pickupLng,
//                 destLat: widget.destLat,
//                 destLng: widget.destLng,
//               ),
//         ),
//         (route) => false, // remove everything before
//       );
//     } else {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text("Failed to accept ride")));
//     }
//   }

//   Future<void> _rejectRidec(BuildContext context, {bool auto = false}) async {
//     _timer?.cancel();
//     _stopRingtone();

//     final user = FirebaseAuth.instance.currentUser;
//     final response = await http.post(
//       Uri.parse('$baseUrl/rides/reject-ride'),
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode({'rideId': widget.rideId, 'firebaseToken': user?.uid}),
//     );

//     // Always go back home after reject
//     if (!mounted) return;

//     Navigator.pushAndRemoveUntil(
//       context,
//       MaterialPageRoute(builder: (_) => NavigationScreen()),
//       (route) => false,
//     );

//     if (response.statusCode != 200) {
//       final data = jsonDecode(response.body);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(data['message'] ?? 'Failed to reject ride')),
//       );
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Ride rejected successfully")),
//       );
//     }

//     if (auto) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text("⏳ Ride request expired")));
//     }
//   }

//   Future<void> _rejectRide(BuildContext context, {bool auto = false}) async {
//     _timer?.cancel();
//     _stopRingtone();

//     final user = FirebaseAuth.instance.currentUser;
//     final response = await http.post(
//       Uri.parse('$baseUrl/rides/reject-ride'),
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode({'rideId': widget.rideId, 'firebaseToken': user?.uid}),
//     );

//     if (response.statusCode != 200) {
//       final rideRef = FirebaseDatabase.instance.ref(
//         "rideRequests/${widget.rideRequestId}",
//       );
//       await rideRef.update({
//         "status": "rejected",
//         "driverId": user?.uid,
//         "rideId": widget.rideRequestId,
//         "riderId": widget.rider,
//         "pickup": {
//           "lat": widget.pickupLat,
//           "lng": widget.pickupLng,
//           "name": widget.pickupName,
//         },
//         "destination": {
//           "lat": widget.destLat,
//           "lng": widget.destLng,
//           "name": widget.destinationName,
//         },
//         "startTime": DateTime.now().toIso8601String(),
//       });
//       final data = jsonDecode(response.body);

//       //await _audioPlayer.stop();

//       if (!mounted) return;
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (_) => NavigationScreen()),
//       );
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(data['message'] ?? 'Failed to reject ride')),
//       );
//     } else {
//       if (!mounted) return;
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (_) => NavigationScreen()),
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

//   // Future<Position> _getCurrentPosition() async {
//   //   bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//   //   if (!serviceEnabled) throw Exception('Location services are disabled.');

//   //   LocationPermission permission = await Geolocator.checkPermission();
//   //   if (permission == LocationPermission.denied) {
//   //     permission = await Geolocator.requestPermission();
//   //     if (permission == LocationPermission.denied) {
//   //       throw Exception('Location permissions are denied');
//   //     }
//   //   }

//   //   if (permission == LocationPermission.deniedForever) {
//   //     throw Exception('Location permissions are permanently denied.');
//   //   }

//   //   return await Geolocator.getCurrentPosition(
//   //     desiredAccuracy: LocationAccuracy.high,
//   //   );
//   // }
//   Future<Position> _getCurrentPosition() async {
//     Position? lastPosition = await Geolocator.getLastKnownPosition();
//     if (lastPosition != null) return lastPosition;

//     // fallback to current position
//     return await Geolocator.getCurrentPosition(
//       desiredAccuracy: LocationAccuracy.high,
//     );
//   }

//   @override
//   void dispose() {
//     _timer?.cancel();
//     _stopRingtone();
//     _mapController?.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     Set<Marker> markers = {
//       Marker(
//         markerId: const MarkerId('pickup'),
//         position: LatLng(widget.pickupLat, widget.pickupLng),
//         infoWindow: InfoWindow(title: 'Pickup: ${widget.pickupName}'),
//         icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
//       ),
//       Marker(
//         markerId: const MarkerId('destination'),
//         position: LatLng(widget.destLat, widget.destLng),
//         infoWindow: InfoWindow(title: 'Destination: ${widget.destinationName}'),
//         icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
//       ),
//     };

//     return Scaffold(
//       backgroundColor: Colors.grey.shade200,
//       body: Center(
//         child: Card(
//           margin: const EdgeInsets.symmetric(horizontal: 20),
//           elevation: 12,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(25),
//           ),
//           child: Padding(
//             padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 const Icon(
//                   Icons.directions_car_filled,
//                   size: 80,
//                   color: Colors.green,
//                 ),
//                 const SizedBox(height: 20),
//                 Text(
//                   "New Ride Request",
//                   style: TextStyle(
//                     fontSize: 28,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.green.shade700,
//                   ),
//                 ),
//                 const SizedBox(height: 15),
//                 _buildInfoRow(Icons.location_pin, "Pickup", widget.pickupName),
//                 const SizedBox(height: 10),
//                 _buildInfoRow(
//                   Icons.flag,
//                   "Destination",
//                   widget.destinationName,
//                 ),
//                 const SizedBox(height: 20),
//                 // Google Maps mini preview
//                 SizedBox(
//                   height: 180,
//                   child: ClipRRect(
//                     borderRadius: BorderRadius.circular(15),
//                     child: GoogleMap(
//                       initialCameraPosition: _initialCamera,
//                       markers: markers,
//                       myLocationButtonEnabled: false,
//                       zoomControlsEnabled: false,
//                       onMapCreated: (controller) {
//                         _mapController = controller;
//                       },
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 20),
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                     vertical: 15,
//                     horizontal: 25,
//                   ),
//                   decoration: BoxDecoration(
//                     color: Colors.red.shade100,
//                     borderRadius: BorderRadius.circular(30),
//                   ),
//                   child: Text(
//                     "⏳ $_remaining seconds left",
//                     style: const TextStyle(
//                       fontSize: 24,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.red,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 20),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: ElevatedButton(
//                         onPressed: () => _rejectRide(context),
//                         style: ElevatedButton.styleFrom(
//                           padding: const EdgeInsets.symmetric(vertical: 18),
//                           backgroundColor: Colors.red.shade400,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(20),
//                           ),
//                         ),
//                         child: const Text(
//                           "Reject",
//                           style: TextStyle(fontSize: 20),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 20),
//                     Expanded(
//                       child: ElevatedButton(
//                         onPressed: () => _acceptRide(context),
//                         style: ElevatedButton.styleFrom(
//                           padding: const EdgeInsets.symmetric(vertical: 18),
//                           backgroundColor: Colors.green.shade600,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(20),
//                           ),
//                         ),
//                         child: const Text(
//                           "Accept",
//                           style: TextStyle(fontSize: 20),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildInfoRow(IconData icon, String title, String value) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         Icon(icon, color: Colors.green.shade700, size: 28),
//         const SizedBox(width: 10),
//         Text(
//           "$title: ",
//           style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
//         ),
//         Expanded(
//           child: Text(
//             value,
//             style: const TextStyle(fontSize: 22),
//             overflow: TextOverflow.ellipsis,
//           ),
//         ),
//       ],
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
// // // import 'dart:async';
// // // import 'dart:convert';
// // // import 'package:aminidriver/Container/utils/api_constant.dart';
// // // import 'package:aminidriver/Container/utils/keys.dart';
// // // import 'package:aminidriver/Onboarding/driver_location_live.dart';
// // // import 'package:aminidriver/Onboarding/trip_detail_screen.dart';
// // // import 'package:firebase_auth/firebase_auth.dart';
// // // import 'package:flutter/material.dart';
// // // import 'package:geolocator/geolocator.dart';
// // // import 'package:http/http.dart' as http;

// // // class RideAlertScreen extends StatefulWidget {
// // //   final String rideId;
// // //   final String rider;
// // //   final String pickupName;
// // //   final String destinationName;
// // //   final double pickupLat;
// // //   final double pickupLng;
// // //   final double destLat;
// // //   final double destLng;

// // //   const RideAlertScreen({
// // //     super.key,
// // //     required this.rideId,
// // //     required this.pickupName,
// // //     required this.destinationName,
// // //     required this.pickupLat,
// // //     required this.pickupLng,
// // //     required this.destLat,
// // //     required this.destLng,
// // //     required this.rider,
// // //   });

// // //   @override
// // //   State<RideAlertScreen> createState() => _RideAlertScreenState();
// // // }

// // // class _RideAlertScreenState extends State<RideAlertScreen> {
// // //   int _remaining = 30;
// // //   Timer? _timer;

// // //   @override
// // //   void initState() {
// // //     super.initState();
// // //     _startCountdown();
// // //   }

// // //   void _startCountdown() {
// // //     _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
// // //       if (_remaining > 0) {
// // //         setState(() => _remaining--);
// // //       } else {
// // //         timer.cancel();
// // //         _rejectRide(context, auto: true); // auto reject after timeout
// // //       }
// // //     });
// // //   }

// // //   Future<void> _acceptRide(BuildContext context) async {
// // //     _timer?.cancel();
// // //     final user = FirebaseAuth.instance.currentUser;
// // //     final idToken = await user?.getIdToken();

// // //     final position = await _getCurrentPosition();
// // //     final driversLatitude = position.latitude;
// // //     final driversLongitude = position.longitude;

// // //     final response = await http.post(
// // //       Uri.parse('$baseUrl/rides/driver/accept-ride'),
// // //       headers: {'Content-Type': 'application/json'},
// // //       body: jsonEncode({
// // //         'rideId': int.parse(widget.rideId),
// // //         'firebaseIdToken': user?.uid,
// // //         'latitude': driversLatitude,
// // //         'longitude': driversLongitude,
// // //       }),
// // //     );

// // //     if (response.statusCode == 200) {
// // //       DriverLocationService().startSendingLocation();
// // //       Navigator.pushReplacement(
// // //         context,
// // //         MaterialPageRoute(
// // //           builder:
// // //               (_) => TripDetailScreen(
// // //                 rideId: widget.rideId,
// // //                 rider: widget.rider,
// // //                 pickupName: widget.pickupName,
// // //                 destinationName: widget.destinationName,
// // //                 pickupLat: widget.pickupLat,
// // //                 pickupLng: widget.pickupLng,
// // //                 destLat: widget.destLat,
// // //                 destLng: widget.destLng,
// // //               ),
// // //         ),
// // //       );
// // //     } else {
// // //       ScaffoldMessenger.of(
// // //         context,
// // //       ).showSnackBar(const SnackBar(content: Text("Failed to accept ride")));
// // //     }
// // //   }

// // //   Future<void> _rejectRide(BuildContext context, {bool auto = false}) async {
// // //     _timer?.cancel();
// // //     final user = FirebaseAuth.instance.currentUser;
// // //     final url = Uri.parse('$baseUrl/rides/reject-ride');

// // //     final response = await http.post(
// // //       url,
// // //       headers: {'Content-Type': 'application/json'},
// // //       body: jsonEncode({'rideId': widget.rideId, 'firebaseToken': user?.uid}),
// // //     );

// // //     if (response.statusCode != 200) {
// // //       final data = jsonDecode(response.body);
// // //       ScaffoldMessenger.of(context).showSnackBar(
// // //         SnackBar(content: Text(data['message'] ?? 'Failed to reject ride')),
// // //       );
// // //     }

// // //     if (mounted) {
// // //       Navigator.pop(context);
// // //       if (auto) {
// // //         ScaffoldMessenger.of(
// // //           context,
// // //         ).showSnackBar(const SnackBar(content: Text("⏳ Ride request expired")));
// // //       }
// // //     }
// // //   }

// // //   Future<Position> _getCurrentPosition() async {
// // //     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
// // //     if (!serviceEnabled) throw Exception('Location services are disabled.');

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

// // //   @override
// // //   void dispose() {
// // //     _timer?.cancel();
// // //     super.dispose();
// // //   }

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     return Scaffold(
// // //       appBar: AppBar(
// // //         title: const Text("New Ride Request"),
// // //         backgroundColor: Colors.green,
// // //       ),
// // //       body: Padding(
// // //         padding: const EdgeInsets.all(16.0),
// // //         child: Column(
// // //           mainAxisAlignment: MainAxisAlignment.center,
// // //           crossAxisAlignment: CrossAxisAlignment.start,
// // //           children: [
// // //             Text(
// // //               "Pickup: ${widget.pickupName}",
// // //               style: const TextStyle(fontSize: 18),
// // //             ),
// // //             const SizedBox(height: 10),
// // //             Text(
// // //               "Destination: ${widget.destinationName}",
// // //               style: const TextStyle(fontSize: 18),
// // //             ),
// // //             const SizedBox(height: 20),
// // //             Center(
// // //               child: Text(
// // //                 "⏳ $_remaining seconds left",
// // //                 style: const TextStyle(
// // //                   fontSize: 20,
// // //                   fontWeight: FontWeight.bold,
// // //                   color: Colors.red,
// // //                 ),
// // //               ),
// // //             ),
// // //             const Spacer(),
// // //             Row(
// // //               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
// // //               children: [
// // //                 ElevatedButton(
// // //                   style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
// // //                   onPressed: () => _rejectRide(context),
// // //                   child: const Text("Reject"),
// // //                 ),
// // //                 ElevatedButton(
// // //                   style: ElevatedButton.styleFrom(
// // //                     backgroundColor: Colors.green,
// // //                   ),
// // //                   onPressed: () => _acceptRide(context),
// // //                   child: const Text("Accept"),
// // //                 ),
// // //               ],
// // //             ),
// // //           ],
// // //         ),
// // //       ),
// // //     );
// // //   }
// // // }

// // // // import 'dart:convert';

// // // // import 'package:aminidriver/Container/utils/api_constant.dart';
// // // // import 'package:aminidriver/Onboarding/driver_location_live.dart';
// // // // import 'package:aminidriver/Onboarding/trip_detail_screen.dart';
// // // // import 'package:firebase_auth/firebase_auth.dart';
// // // // import 'package:flutter/material.dart';
// // // // import 'package:geolocator/geolocator.dart';
// // // // import 'package:http/http.dart' as http;

// // // // class RideAlertPopup extends StatelessWidget {
// // // //   final String rideId;
// // // //   final String rider;
// // // //   final String pickupName;
// // // //   final String destinationName;
// // // //   final double pickupLat;
// // // //   final double pickupLng;
// // // //   final double destLat;
// // // //   final double destLng;
// // // //   final VoidCallback onAccept;
// // // //   final VoidCallback onReject;

// // // //   const RideAlertPopup({
// // // //     super.key,
// // // //     required this.rideId,
// // // //     required this.pickupName,
// // // //     required this.destinationName,
// // // //     required this.pickupLat,
// // // //     required this.pickupLng,
// // // //     required this.destLat,
// // // //     required this.destLng,
// // // //     required this.onAccept,
// // // //     required this.onReject,
// // // //     required this.rider,
// // // //   });
// // // //   Future<void> _acceptRide(BuildContext context) async {
// // // //     final user = FirebaseAuth.instance.currentUser;
// // // //     final idToken = await user?.getIdToken();

// // // //     final position = await _getCurrentPosition();
// // // //     final driversLatitude = position.latitude;
// // // //     final driversLongitude = position.longitude;

// // // //     final response = await http.post(
// // // //       Uri.parse('$baseUrl/rides/driver/accept-ride'),
// // // //       headers: {'Content-Type': 'application/json'},
// // // //       body: jsonEncode({
// // // //         'rideId': int.parse(rideId), // assuming rideId is a string
// // // //         'firebaseIdToken': idToken,
// // // //         'latitude': driversLatitude,
// // // //         'longitude': driversLongitude,

// // // //         // Replace with real method
// // // //       }),
// // // //     );

// // // //     if (response.statusCode == 200) {
// // // //       DriverLocationService().startSendingLocation();
// // // //       // Navigate to TripDetailScreen
// // // //       Navigator.pushReplacement(
// // // //         context,
// // // //         MaterialPageRoute(
// // // //           builder:
// // // //               (_) => TripDetailScreen(
// // // //                 rideId: rideId,
// // // //                 rider: rider,
// // // //                 pickupName: pickupName,
// // // //                 destinationName: destinationName,
// // // //                 pickupLat: pickupLat,
// // // //                 pickupLng: pickupLng,
// // // //                 destLat: destLat,
// // // //                 destLng: destLng,
// // // //               ),
// // // //         ),
// // // //       );
// // // //     } else {
// // // //       ScaffoldMessenger.of(
// // // //         context,
// // // //       ).showSnackBar(const SnackBar(content: Text("Failed to accept ride")));
// // // //     }
// // // //   }

// // // //   Future<Position> _getCurrentPosition() async {
// // // //     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
// // // //     if (!serviceEnabled) {
// // // //       throw Exception('Location services are disabled.');
// // // //     }

// // // //     LocationPermission permission = await Geolocator.checkPermission();
// // // //     if (permission == LocationPermission.denied) {
// // // //       permission = await Geolocator.requestPermission();
// // // //       if (permission == LocationPermission.denied) {
// // // //         throw Exception('Location permissions are denied');
// // // //       }
// // // //     }

// // // //     if (permission == LocationPermission.deniedForever) {
// // // //       throw Exception('Location permissions are permanently denied.');
// // // //     }

// // // //     return await Geolocator.getCurrentPosition(
// // // //       desiredAccuracy: LocationAccuracy.high,
// // // //     );
// // // //   }

// // // //   Future<void> rejectRide(BuildContext context) async {
// // // //     final user = FirebaseAuth.instance.currentUser;
// // // //     final idToken = await user?.getIdToken();

// // // //     final url = Uri.parse('$baseUrl/rides/reject-ride');

// // // //     final response = await http.post(
// // // //       url,
// // // //       headers: {'Content-Type': 'application/json'},
// // // //       body: jsonEncode({'rideId': rideId, 'firebaseToken': user?.uid}),
// // // //     );

// // // //     if (response.statusCode != 200) {
// // // //       final data = jsonDecode(response.body);
// // // //       throw Exception(data['message'] ?? 'Failed to reject ride');
// // // //     }
// // // //   }

// // // //   @override
// // // //   Widget build(BuildContext context) {
// // // //     return AlertDialog(
// // // //       title: const Text('New Ride Request'),
// // // //       content: Column(
// // // //         mainAxisSize: MainAxisSize.min,
// // // //         children: [
// // // //           Text('Pickup: $pickupName'),
// // // //           Text('Destination: $destinationName'),
// // // //         ],
// // // //       ),
// // // //       actions: [
// // // //         TextButton(
// // // //           onPressed: () => rejectRide(context),
// // // //           child: const Text('Reject'),
// // // //         ),
// // // //         ElevatedButton(
// // // //           onPressed: () => _acceptRide(context),
// // // //           child: const Text('Accept'),
// // // //         ),
// // // //       ],
// // // //     );
// // // //   }
// // // // }
// Future<void> _acceptRide(BuildContext context) async {
  //   _timer?.cancel();
  //   _stopRingtone();

  //   final user = FirebaseAuth.instance.currentUser;
  //   final position = await _getCurrentPosition();

  //   final response = await http.post(
  //     Uri.parse('$baseUrl/rides/driver/accept-ride'),
  //     headers: {'Content-Type': 'application/json'},
  //     body: jsonEncode({
  //       'rideId': int.parse(widget.rideId),
  //       'firebaseIdToken': user?.uid,
  //       'latitude': position.latitude,
  //       'longitude': position.longitude,
  //     }),
  //   );

  //   if (response.statusCode == 200) {
  //     final data = jsonDecode(response.body);

  //     final passengerDb = FirebaseDatabase.instanceFor(app: passengerApp);
  //     final dbRef = passengerDb.ref("rideRequests/${data['rideRequestId']}");

  //     await dbRef.update({
  //       "status": "assigned",
  //       "driverId": user?.uid,
  //       "rideId": data['rideId'].toString(),
  //       "riderName": data['riderName'].toString(),
  //       "passmobile": data['mobile'].toString(),
  //       "pickup": {
  //         "lat": widget.pickupLat,
  //         "lng": widget.pickupLng,
  //         "name": widget.pickupName,
  //       },
  //       "destination": {
  //         "lat": widget.destLat,
  //         "lng": widget.destLng,
  //         "name": widget.destinationName,
  //       },
  //       "startTime": DateTime.now().toIso8601String(),
  //     });

  //     final realRideRef = passengerDb.ref("rides/${data['rideId']}");
  //     await realRideRef.update({
  //       "status": "assigned",
  //       "driverId": user?.uid,
  //       "riderId": data['riderId'],
  //       "riderName": data['riderName'].toString(),
  //       "passmobile": data['mobile'].toString(),
  //       "pickup": {
  //         "lat": widget.pickupLat,
  //         "lng": widget.pickupLng,
  //         "name": widget.pickupName,
  //       },
  //       "destination": {
  //         "lat": widget.destLat,
  //         "lng": widget.destLng,
  //         "name": widget.destinationName,
  //       },
  //       "driverlocation": {"lat": position.latitude, "lng": position.longitude},
  //       "startTime": DateTime.now().toIso8601String(),
  //     });

  //     Navigator.pushAndRemoveUntil(
  //       context,
  //       MaterialPageRoute(
  //         builder:
  //             (_) => TripDetailScreen(
  //               rideId: data['rideId'].toString(),
  //               rider: data['riderName'].toString(),
  //               mobile: data['mobile'].toString(),
  //               riderId: data['riderId'],
  //               pickupName: widget.pickupName,
  //               destinationName: widget.destinationName,
  //               pickupLat: widget.pickupLat,
  //               pickupLng: widget.pickupLng,
  //               destLat: widget.destLat,
  //               destLng: widget.destLng,
  //             ),
  //       ),
  //       (route) => false,
  //     );
  //   } else {
  //     ScaffoldMessenger.of(
  //       context,
  //     ).showSnackBar(const SnackBar(content: Text("Failed to accept ride")));
  //   }
  // }
  // Future<void> _acceptRide(BuildContext context) async {
  //   _timer?.cancel();
  //   _stopRingtone();

  //   final user = FirebaseAuth.instance.currentUser;
  //   final position = await _getCurrentPosition();

  //   final response = await http.post(
  //     Uri.parse('$baseUrl/rides/driver/accept-ride'),
  //     headers: {'Content-Type': 'application/json'},
  //     body: jsonEncode({
  //       'rideId': int.parse(widget.rideId),
  //       'firebaseIdToken': user?.uid,
  //       'latitude': position.latitude,
  //       'longitude': position.longitude,
  //     }),
  //   );

  //   if (response.statusCode == 200) {
  //     final data = jsonDecode(response.body);

  //     final passengerDb = FirebaseDatabase.instanceFor(app: passengerApp);

  //     // ... update Firebase as you already do ...

  //     if (!mounted) return;

  //     // ✅ make sure RideAlertScreen is fully disposed
  //     WidgetsBinding.instance.addPostFrameCallback((_) {
  //       Navigator.pushAndRemoveUntil(
  //         context,
  //         MaterialPageRoute(
  //           builder:
  //               (_) => TripDetailScreen(
  //                 rideId: data['rideId'].toString(),
  //                 rider: data['riderName'].toString(),
  //                 mobile: data['mobile'].toString(),
  //                 riderId: data['riderId'],
  //                 pickupName: widget.pickupName,
  //                 destinationName: widget.destinationName,
  //                 pickupLat: widget.pickupLat,
  //                 pickupLng: widget.pickupLng,
  //                 destLat: widget.destLat,
  //                 destLng: widget.destLng,
  //               ),
  //         ),
  //         (route) => false,
  //       );
  //     });
  //   } else {
  //     if (!mounted) return;
  //     ScaffoldMessenger.of(
  //       context,
  //     ).showSnackBar(const SnackBar(content: Text("Failed to accept ride")));
  //   }
  // }      // Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(
      //     builder:
      //         (_) => TripDetailScreen(
      //           rideId: data['rideId'].toString(),
      //           rider: data['riderName'].toString(),
      //           mobile: data['mobile'].toString(),
      //           riderId: data['riderId'],
      //           pickupName: widget.pickupName,
      //           destinationName: widget.destinationName,
      //           pickupLat: widget.pickupLat,
      //           pickupLng: widget.pickupLng,
      //           destLat: widget.destLat,
      //           destLng: widget.destLng,
      //         ),
      //   ),
      // );

      // Navigator.pushAndRemoveUntil(
      //   context,
      //   MaterialPageRoute(
      //     builder:
      //         (_) => TripDetailScreen(
      //           rideId: data['rideId'].toString(),
      //           rider: data['riderName'].toString(),
      //           mobile: data['mobile'].toString(),
      //           riderId: data['riderId'],
      //           pickupName: widget.pickupName,
      //           destinationName: widget.destinationName,
      //           pickupLat: widget.pickupLat,
      //           pickupLng: widget.pickupLng,
      //           destLat: widget.destLat,
      //           destLng: widget.destLng,
      //         ),
      //   ),
      //   (route) => false, // remove everything before
      // );