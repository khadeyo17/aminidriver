import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_logics.dart';
import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_providers.dart';
import 'package:aminidriver/Container/utils/firebase_messaging.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  //late GoogleMapController _mapController;
  final Completer<GoogleMapController> _mapControllerCompleter = Completer();

  LatLng _initialPosition = const LatLng(0.0, 0.0);
  final messagingService = MessagingService();

  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  void _addOrUpdateDriverMarker(LatLng position) {
    _markers.removeWhere((m) => m.markerId.value == 'driver');
    _markers.add(
      Marker(
        markerId: const MarkerId('driver'),
        position: position,
        infoWindow: const InfoWindow(title: "You"),
      ),
    );
  }

  Future<void> _initialize() async {
    await messagingService.checkInitialMessage(context, ref);

    if (!mounted) return;
    await HomeLogics().fetchAndUpdateDriverStatus(ref);

    if (!mounted) return;
    await messagingService.init(context, ref);

    if (!mounted) return;
    await _setInitialLocation();

    _listenToDriverLocation();
  }

  Future<void> _setInitialLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      final initialLatLng = LatLng(pos.latitude, pos.longitude);

      setState(() {
        _initialPosition = initialLatLng;
        _addOrUpdateDriverMarker(initialLatLng);
      });

      final firestoreRepo = ref.read(globalFirestoreRepoProvider);
      await firestoreRepo.getDriverDetails(context);
    } catch (e) {
      print("Location error: $e");
    }
  }

  void _listenToDriverLocation() {
    final driverLocationRef = FirebaseDatabase.instance.ref(
      "drivers/driverId/location",
    );

    driverLocationRef.onValue.listen((event) async {
      final data = event.snapshot.value as Map?;
      if (data != null && mounted) {
        final lat = (data['latitude'] as num).toDouble();
        final lng = (data['longitude'] as num).toDouble();
        final newPosition = LatLng(lat, lng);

        setState(() {
          _initialPosition = newPosition;
          _addOrUpdateDriverMarker(newPosition);
        });

        await _animateCamera(newPosition); // Safe now
      }
    });
  }

  Future<void> _animateCamera(LatLng position) async {
    final controller = await _mapControllerCompleter.future;
    controller.animateCamera(CameraUpdate.newLatLng(position));
  }
  // void _addOrUpdateDriverMarker(LatLng position) {
  //   _markers.removeWhere((m) => m.markerId.value == 'driver');
  //   _markers.add(
  //     Marker(
  //       markerId: const MarkerId('driver'),
  //       position: position,
  //       infoWindow: const InfoWindow(title: "You"),
  //     ),
  //   );
  // }

  // void _onMapCreated(GoogleMapController controller) {
  //   _mapController = controller;

  //   ref.listen<List<Marker>>(homeScreenMainMarkersProviderOSM, (
  //     previous,
  //     next,
  //   ) {
  //     _updateMarkers(next.toSet());
  //   });

  //   ref.listen<List<Circle>>(homeScreenMainCirclesProviderOSM, (
  //     previous,
  //     next,
  //   ) {
  //     _updateCircles(next.toSet());
  //   });

  //   ref.listen<List<Polyline>>(homeScreenMainPolylinesProviderOSM, (
  //     previous,
  //     next,
  //   ) {
  //     _updatePolylines(next.toSet());
  //   });
  // }

  // void _updateMarkers(Set<Marker> newMarkers) {
  //   _markers
  //     ..clear()
  //     ..addAll(newMarkers)
  //     ..add(
  //       Marker(
  //         markerId: const MarkerId('driver'),
  //         position: _initialPosition,
  //         infoWindow: const InfoWindow(title: "You"),
  //       ),
  //     );

  //   // Refresh map markers
  //   _mapController.updateMarkers(_markers);
  // }

  // void _updateCircles(Set<Circle> newCircles) {
  //   _circles
  //     ..clear()
  //     ..addAll(newCircles);

  //   _mapController.updateCircles(_circles);
  // }

  // void _updatePolylines(Set<Polyline> newPolylines) {
  //   _polylines
  //     ..clear()
  //     ..addAll(newPolylines);

  //   _mapController.updatePolylines(_polylines);
  // }

  void _onMapCreated(GoogleMapController controller) {
    _mapControllerCompleter.complete(controller);

    final markers = ref.read(homeScreenMainMarkersProviderOSM);
    final circles = ref.read(homeScreenMainCirclesProviderOSM);
    final polylines = ref.read(homeScreenMainPolylinesProviderOSM);

    setState(() {
      _markers.addAll(
        markers.map(
          (e) => Marker(
            markerId: MarkerId(e.key.toString()),
            position: LatLng(e.point.latitude, e.point.longitude),
          ),
        ),
      );

      _circles.addAll(
        circles.map(
          (e) => Circle(
            circleId: CircleId(e.key.toString()),
            center: LatLng(e.point.latitude, e.point.longitude),
            radius: e.radius,
            fillColor: e.color,
            strokeColor: e.borderColor,
            strokeWidth: e.borderStrokeWidth.toInt(),
          ),
        ),
      );

      _polylines.addAll(
        polylines.asMap().entries.map((entry) {
          final e = entry.value;
          return Polyline(
            polylineId: PolylineId('polyline_${entry.key}'),
            points:
                e.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
            color: e.color,
            width: e.strokeWidth.toInt(),
          );
        }),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isOnline = ref.watch(homeScreenIsDriverActiveProvider);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _initialPosition,
                zoom: 14,
              ),
              onMapCreated: _onMapCreated,
              markers: _markers,
              circles: _circles,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
            ),
            if (!isOnline)
              Container(
                width: size.width,
                height: size.height,
                color: Colors.black.withOpacity(0.6),
              ),
            Positioned(
              top: isOnline ? 30 : size.height * 0.4,
              left: 20,
              right: 20,
              child: Column(
                children: [
                  _buildStatusBadge(isOnline),
                  const SizedBox(height: 20),
                  _buildToggleButton(isOnline),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isOnline) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: isOnline ? Colors.yellow[700] : Colors.blue,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOnline ? Icons.check_circle : Icons.cancel,
            color: Colors.white,
          ),
          const SizedBox(width: 10),
          Text(
            isOnline ? 'You are Online' : 'You are Offline',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(bool isOnline) {
    return GestureDetector(
      // onTap: () async {
      //   if (!isOnline) {
      //     await HomeLogics().getDriverOnline(context, ref, _mapController);
      //   } else {
      //     await HomeLogics().getDriverOffline(context, ref);
      //   }
      // },
      onTap: () async {
        final controller =
            await _mapControllerCompleter.future; // wait for map controller
        if (!isOnline) {
          await HomeLogics().getDriverOnline(context, ref, controller);
        } else {
          await HomeLogics().getDriverOffline(context, ref);
        }
      },
      child: Container(
        alignment: Alignment.center,
        width: 180,
        height: 45,
        decoration: BoxDecoration(
          color: isOnline ? Colors.blue : Colors.yellow,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          isOnline ? 'Go Offline' : 'Go Online',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
// import 'dart:async';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_logics.dart';
// import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_providers.dart';
// import 'package:aminidriver/Container/utils/firebase_messaging.dart';

// class HomeScreen extends ConsumerStatefulWidget {
//   const HomeScreen({super.key});

//   @override
//   ConsumerState<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends ConsumerState<HomeScreen> {
//   late GoogleMapController _mapController;
//   LatLng _initialPosition = LatLng(0.0, 0.0);
//   final messagingService = MessagingService();

//   final Set<Marker> _markers = {};
//   final Set<Circle> _circles = {};
//   final Set<Polyline> _polylines = {};

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _initialize();
//     });
//   }

//   Future<void> _initialize() async {
//     await messagingService.checkInitialMessage(context, ref);

//     if (!mounted) return;
//     await HomeLogics().fetchAndUpdateDriverStatus(ref);

//     if (!mounted) return;
//     await messagingService.init(context, ref);

//     if (!mounted) return;
//     await _setInitialLocation();

//     _listenToDriverLocation();
//   }

//   void _listenToDriverLocation() {
//     // Reference to driver's location in Realtime DB
//     final driverLocationRef = FirebaseDatabase.instance.ref(
//       "drivers/driverId/location",
//     );

//     driverLocationRef.onValue.listen((event) {
//       final data = event.snapshot.value as Map?;
//       if (data != null && mounted) {
//         final lat = (data['latitude'] as num).toDouble();
//         final lng = (data['longitude'] as num).toDouble();
//         final newPosition = LatLng(lat, lng);

//         setState(() {
//           _initialPosition = newPosition;
//           _markers.clear();
//           _markers.add(
//             Marker(
//               markerId: const MarkerId('driver'),
//               position: newPosition,
//               infoWindow: const InfoWindow(title: "You"),
//             ),
//           );
//         });

//         // Center map on driver's location
//         _mapController.animateCamera(CameraUpdate.newLatLng(newPosition));
//       }
//     });
//   }

//   Future<void> _setInitialLocation() async {
//     try {
//       // 1️⃣ Get current device location
//       final pos = await Geolocator.getCurrentPosition();
//       setState(() {
//         _initialPosition = LatLng(pos.latitude, pos.longitude);

//         // Optional: place initial marker for driver
//         _markers.clear();
//         _markers.add(
//           Marker(
//             markerId: const MarkerId('driver'),
//             position: _initialPosition,
//             infoWindow: const InfoWindow(title: "You"),
//           ),
//         );
//       });

//       // 2️⃣ Fetch driver details from Firestore (your existing logic)
//       final firestoreRepo = ref.read(globalFirestoreRepoProvider);
//       await firestoreRepo.getDriverDetails(context);

//       // 3️⃣ Start listening to live location updates from Realtime DB
//       _listenToDriverLocation(); // <-- Add this
//     } catch (e) {
//       print("Location error: $e");
//     }
//   }

//   void _onMapCreated(GoogleMapController controller) {
//     _mapController = controller;

//     // Listen to providers and update markers/circles/polylines
//     final markers = ref.read(homeScreenMainMarkersProviderOSM);
//     final circles = ref.read(homeScreenMainCirclesProviderOSM);
//     final polylines = ref.read(homeScreenMainPolylinesProviderOSM);

//     setState(() {
//       _markers.addAll(
//         markers
//             .map(
//               (e) => Marker(
//                 markerId: MarkerId(e.key.toString()),
//                 position: LatLng(e.point.latitude, e.point.longitude),
//               ),
//             )
//             .toList(),
//       );
//       _circles.addAll(
//         circles
//             .map(
//               (e) => Circle(
//                 circleId: CircleId(e.key.toString()),
//                 center: LatLng(
//                   e.point.latitude,
//                   e.point.longitude,
//                 ), // use .point
//                 radius: e.radius,
//                 fillColor: e.color,
//                 strokeColor: e.borderColor,
//                 strokeWidth: e.borderStrokeWidth.toInt(),
//               ),
//             )
//             .toList(),
//       );

//       // _circles.addAll(
//       //   circles
//       //       .map(
//       //         (e) => Circle(
//       //           circleId: CircleId(e.key.toString()),
//       //           center: LatLng(e.center.latitude, e.center.longitude),
//       //           radius: e.radius,
//       //           fillColor: e.color,
//       //           strokeColor: e.borderColor,
//       //           strokeWidth: e.borderStrokeWidth.toInt(),
//       //         ),
//       //       )
//       //       .toList(),
//       // );

//       _polylines.addAll(
//         polylines.asMap().entries.map((entry) {
//           final index = entry.key;
//           final e = entry.value;
//           return Polyline(
//             polylineId: PolylineId('polyline_$index'),
//             points:
//                 e.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
//             color: e.color,
//             width: e.strokeWidth.toInt(),
//           );
//         }).toList(),
//       );
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     Size size = MediaQuery.sizeOf(context);
//     final isOnline = ref.watch(homeScreenIsDriverActiveProvider);

//     return Scaffold(
//       body: SafeArea(
//         child: Stack(
//           children: [
//             GoogleMap(
//               initialCameraPosition: CameraPosition(
//                 target: _initialPosition,
//                 zoom: 14,
//               ),
//               onMapCreated: _onMapCreated,
//               markers: _markers,
//               circles: _circles,
//               polylines: _polylines,
//               myLocationEnabled: true,
//               myLocationButtonEnabled: true,
//               zoomControlsEnabled: false,
//             ),

//             if (!isOnline)
//               Container(
//                 width: size.width,
//                 height: size.height,
//                 color: Colors.black.withOpacity(0.6),
//               ),

//             Positioned(
//               top: isOnline ? 30 : size.height * 0.4,
//               left: 20,
//               right: 20,
//               child: Column(
//                 children: [
//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                       vertical: 12,
//                       horizontal: 16,
//                     ),
//                     decoration: BoxDecoration(
//                       color: isOnline ? Colors.yellow[700] : Colors.blue,
//                       borderRadius: BorderRadius.circular(12),
//                       boxShadow: const [
//                         BoxShadow(
//                           color: Colors.black26,
//                           blurRadius: 6,
//                           offset: Offset(0, 4),
//                         ),
//                       ],
//                     ),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Icon(
//                           isOnline ? Icons.check_circle : Icons.cancel,
//                           color: Colors.white,
//                         ),
//                         const SizedBox(width: 10),
//                         Text(
//                           isOnline ? 'You are Online' : 'You are Offline',
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontSize: 16,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 20),
//                   GestureDetector(
//                     onTap: () async {
//                       if (!isOnline) {
//                         await HomeLogics().getDriverOnline(
//                           context,
//                           ref,
//                           _mapController,
//                         );
//                       } else {
//                         await HomeLogics().getDriverOffline(context, ref);
//                       }
//                     },
//                     child: Container(
//                       alignment: Alignment.center,
//                       width: 180,
//                       height: 45,
//                       decoration: BoxDecoration(
//                         color: isOnline ? Colors.blue : Colors.yellow,
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       child: Text(
//                         isOnline ? 'Go Offline' : 'Go Online',
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }



// // import 'dart:async';
// // import 'package:aminidriver/main.dart';
// // import 'package:firebase_database/firebase_database.dart';
// // import 'package:firebase_messaging/firebase_messaging.dart';
// // import 'package:flutter/material.dart';
// // import 'package:flutter_riverpod/flutter_riverpod.dart';
// // import 'package:flutter_map/flutter_map.dart';
// // import 'package:latlong2/latlong.dart';
// // import 'package:geolocator/geolocator.dart';
// // import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_logics.dart';
// // import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_providers.dart';
// // import 'package:aminidriver/Container/utils/firebase_messaging.dart';

// // class HomeScreen extends ConsumerStatefulWidget {
// //   const HomeScreen({super.key});

// //   @override
// //   ConsumerState<HomeScreen> createState() => _HomeScreenState();
// // }

// // class _HomeScreenState extends ConsumerState<HomeScreen> {
// //   final MapController _mapController = MapController();
// //   LatLng _initialPosition = LatLng(0.0, 0.0);
// //   //StreamSubscription<DatabaseEvent>? _rideSubscription;
// //   //bool _navigatedToLiveScreen = false; // guard against multiple pushes
// //   final messagingService = MessagingService();
// //   @override
// //   void initState() {
// //     super.initState();

// //     WidgetsBinding.instance.addPostFrameCallback((_) {
// //       _initialize();
// //     });
// //   }

// //   Future<void> _initialize() async {
// //     // Safe to call context/mounted here
// //     await messagingService.checkInitialMessage(context, ref);

// //     if (!mounted) return;
// //     await HomeLogics().fetchAndUpdateDriverStatus(ref);

// //     if (!mounted) return;
// //     await messagingService.init(context, ref);

// //     if (!mounted) return;
// //     await _setInitialLocation();

// //     //_listenForRideStatus();
// //   }


// //   Future<void> _setInitialLocation() async {
// //     try {
// //       final pos = await Geolocator.getCurrentPosition();
// //       setState(() {
// //         _initialPosition = LatLng(pos.latitude, pos.longitude);
// //       });

// //       final firestoreRepo = ref.read(globalFirestoreRepoProvider);
// //       await firestoreRepo.getDriverDetails(context);
// //     } catch (e) {
// //       print("Location error: $e");
// //     }
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     Size size = MediaQuery.sizeOf(context);
// //     final isOnline = ref.watch(homeScreenIsDriverActiveProvider);

// //     return Scaffold(
// //       body: SafeArea(
// //         child: Stack(
// //           children: [
// //             FlutterMap(
// //               mapController: _mapController,
// //               options: MapOptions(
// //                 center: _initialPosition,
// //                 zoom: 14,
// //                 onTap: (tapPosition, point) {},
// //               ),
// //               children: [
// //                 TileLayer(
// //                   urlTemplate:
// //                       'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
// //                   subdomains: ['a', 'b', 'c'],
// //                   userAgentPackageName: 'com.example.aminidriver',
// //                 ),
// //                 CircleLayer(
// //                   circles: ref.watch(homeScreenMainCirclesProviderOSM),
// //                 ),
// //                 PolylineLayer(
// //                   polylines: ref.watch(homeScreenMainPolylinesProviderOSM),
// //                 ),
// //                 MarkerLayer(
// //                   markers: ref.watch(homeScreenMainMarkersProviderOSM),
// //                 ),
// //               ],
// //             ),

// //             if (!isOnline)
// //               Container(
// //                 width: size.width,
// //                 height: size.height,
// //                 color: Colors.black.withOpacity(0.6),
// //               ),

// //             Positioned(
// //               top: isOnline ? 30 : size.height * 0.4,
// //               left: 20,
// //               right: 20,
// //               child: Column(
// //                 children: [
// //                   Container(
// //                     padding: const EdgeInsets.symmetric(
// //                       vertical: 12,
// //                       horizontal: 16,
// //                     ),
// //                     decoration: BoxDecoration(
// //                       color: isOnline ? Colors.yellow[700] : Colors.blue,
// //                       borderRadius: BorderRadius.circular(12),
// //                       boxShadow: [
// //                         BoxShadow(
// //                           color: Colors.black26,
// //                           blurRadius: 6,
// //                           offset: Offset(0, 4),
// //                         ),
// //                       ],
// //                     ),
// //                     child: Row(
// //                       mainAxisSize: MainAxisSize.min,
// //                       children: [
// //                         Icon(
// //                           isOnline ? Icons.check_circle : Icons.cancel,
// //                           color: Colors.white,
// //                         ),
// //                         SizedBox(width: 10),
// //                         Text(
// //                           isOnline ? 'You are Online' : 'You are Offline',
// //                           style: TextStyle(
// //                             color: Colors.white,
// //                             fontSize: 16,
// //                             fontWeight: FontWeight.bold,
// //                           ),
// //                         ),
// //                       ],
// //                     ),
// //                   ),
// //                   const SizedBox(height: 20),
// //                   GestureDetector(
// //                     onTap: () async {
// //                       if (!isOnline) {
// //                         await HomeLogics().getDriverOnline(
// //                           context,
// //                           ref,
// //                           _mapController,
// //                         );
// //                       } else {
// //                         await HomeLogics().getDriverOffline(context, ref);
// //                       }
// //                     },

// //                     child: Container(
// //                       alignment: Alignment.center,
// //                       width: 180,
// //                       height: 45,
// //                       decoration: BoxDecoration(
// //                         color: isOnline ? Colors.blue : Colors.yellow,
// //                         borderRadius: BorderRadius.circular(10),
// //                       ),
// //                       child: Text(
// //                         isOnline ? 'Go Offline' : 'Go Online',
// //                         style: TextStyle(
// //                           color: Colors.white,
// //                           fontWeight: FontWeight.bold,
// //                         ),
// //                       ),
// //                     ),
// //                   ),
// //                 ],
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// // }


// //   // @override
// //   // void initState() {
// //   //   super.initState();
// //   //   Future.microtask(() async {
// //   //     //await HomeLogics().fetchAndUpdateDriverStatus(ref);
// //   //     //await messagingService.init(context, ref);
// //   //     await messagingService.checkInitialMessage(context, ref);

// //   //     WidgetsBinding.instance.addPostFrameCallback((_) async {
// //   //       await HomeLogics().fetchAndUpdateDriverStatus(ref);
// //   //       if (mounted) {
// //   //         await messagingService.init(context, ref);
// //   //       }
// //   //     });
// //   //     // if (mounted) {
// //   //     //   await messagingService.checkInitialMessage(context, ref);
// //   //     // }
// //   //     await _setInitialLocation();
// //   //   });
// //   // }

// //   // @override
// //   // void didChangeDependencies() {
// //   //   super.didChangeDependencies();

// //   //   if (initialRideMessage != null) {
// //   //     final message = initialRideMessage!;
// //   //     initialRideMessage = null;

// //   //     WidgetsBinding.instance.addPostFrameCallback((_) {
// //   //       // Navigate to HomeScreen if not already there
// //   //       if (ModalRoute.of(context)?.settings.name != '/home') {
// //   //         Navigator.pushReplacementNamed(context, '/home');
// //   //       }

// //   //       // Delay again to allow screen to mount before handling message
// //   //       Future.delayed(Duration(milliseconds: 300), () {
// //   //         messagingService.handleMessage(context, ref, message);
// //   //       });
// //   //     });
// //   //   }
// //   // }

// //   // @override
// //   // void initState() {
// //   //   super.initState();
// //   //   Future.microtask(() async {
// //   //     // final messagingService = MessagingService();
// //   //     // messagingService.init(context, ref);

// //   //     await _setInitialLocation();
// //   //     await HomeLogics().fetchAndUpdateDriverStatus(ref);
// //   //     final messagingService = MessagingService();
// //   //     if (mounted) {
// //   //       //await messagingService.init(context, ref);
// //   //       await messagingService.checkInitialMessage(context, ref);
// //   //     }
// //   //   });
// //   // }
// //   //   @override
// //   // void didChangeDependencies() {
// //   //   super.didChangeDependencies();

// //   //   if (initialRideMessage != null) {
// //   //     final message = initialRideMessage!;
// //   //     initialRideMessage = null;

// //   //     WidgetsBinding.instance.addPostFrameCallback((_) {
// //   //       // Navigate to HomeScreen if not already there
// //   //       if (ModalRoute.of(context)?.settings.name != '/home') {
// //   //         Navigator.pushReplacementNamed(context, '/home');
// //   //       }

// //   //       // Delay again slightly to allow home screen to mount
// //   //       Future.delayed(Duration(milliseconds: 300), () {
// //   //         messagingService.handleMessage(context, ref, message);
// //   //       });
// //   //     });
// //   //   }
// //   // }


// //   // void _listenForRideStatus() {
// //   //     // You’ll need the current driver’s rideId from provider or API
// //   //     final rideId = "some_ride_id"; // replace with actual value
// //   //     final driverId = "some_driver_id"; // replace with actual value

// //   //     final rideRef = FirebaseDatabase.instance.ref("rides/$rideId");

// //   //     _rideSubscription = rideRef.onValue.listen((event) {
// //   //       final data = event.snapshot.value as Map?;
// //   //       if (data == null) return;

// //   //       final status = data["status"];
// //   //       if (status == "in_progress" && !_navigatedToLiveScreen) {
// //   //         _navigatedToLiveScreen = true;

// //   //         Navigator.push(
// //   //           context,
// //   //           MaterialPageRoute(
// //   //             builder: (_) => RideInProgressLiveScreen(
// //   //               rideId: rideId,
// //   //               driverId: driverId,
// //   //               pickup: LatLng(data["pickup"]["lat"], data["pickup"]["lng"]),
// //   //               destination: LatLng(data["destination"]["lat"], data["destination"]["lng"]),
// //   //               baseFare: 100, // or pass from DB
// //   //               perKmFare: 50,
// //   //             ),
// //   //           ),
// //   //         );
// //   //       }
// //   //     });
// //   //   }


// // // import 'dart:async';
// // // import 'package:flutter/material.dart';
// // // import 'package:flutter_riverpod/flutter_riverpod.dart';
// // // import 'package:google_maps_flutter/google_maps_flutter.dart';
// // // import 'package:aminidriver/Container/utils/firebase_messaging.dart';
// // // import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_logics.dart';
// // // import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_providers.dart';
// // // import '../../../../Container/utils/set_blackmap.dart';
// // // import 'package:geoflutterfire2/geoflutterfire2.dart';

// // // final geo = GeoFlutterFire();

// // // class HomeScreen extends ConsumerStatefulWidget {
// // //   const HomeScreen({super.key});

// // //   @override
// // //   ConsumerState<HomeScreen> createState() => _HomeScreenState();
// // // }

// // // class _HomeScreenState extends ConsumerState<HomeScreen> {
// // //   final Completer<GoogleMapController> _mapController = Completer();
// // //   GoogleMapController? controller;
// // //   CameraPosition _initialPosition = const CameraPosition(
// // //     target: LatLng(0.0, 0.0),
// // //     zoom: 14,
// // //   );

// // //   @override
// // //   void initState() {
// // //     super.initState();
// // //     MessagingService().init(context);
// // //   }

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     Size size = MediaQuery.sizeOf(context);
// // //     final isOnline = ref.watch(homeScreenIsDriverActiveProvider);
// // //     final firestoreRepo = ref.watch(
// // //       globalFirestoreRepoProvider,
// // //     ); // Properly watch the Firestore provider

// // //     return Scaffold(
// // //       body: SafeArea(
// // //         child: Stack(
// // //           children: [
// // //             GoogleMap(
// // //               mapType: MapType.normal,
// // //               myLocationButtonEnabled: true,
// // //               myLocationEnabled: true,
// // //               zoomControlsEnabled: false,
// // //               initialCameraPosition: _initialPosition,
// // //               polylines: ref.watch(homeScreenMainPolylinesProvider),
// // //               markers: ref.watch(homeScreenMainMarkersProvider),
// // //               circles: ref.watch(homeScreenMainCirclesProvider),
// // //               onMapCreated: (map) async {
// // //                 _mapController.complete(map);
// // //                 controller = map;
// // //                 SetBlackMap().setBlackMapTheme(map);

// // //                 // Get current location and details
// // //                 HomeLogics().getDriverLoc(context, ref, map);
// // //                 await firestoreRepo.getDriverDetails(
// // //                   context,
// // //                 ); // Proper async function call
// // //               },
// // //             ),

// // //             // If driver is offline, overlay black shade
// // //             if (!isOnline)
// // //               Container(
// // //                 width: size.width,
// // //                 height: size.height,
// // //                 color: Colors.black,
// // //               ),

// // //             // Status and Toggle Button
// // //             Positioned(
// // //               top: isOnline ? 30 : size.height * 0.4,
// // //               left: 20,
// // //               right: 20,
// // //               child: Column(
// // //                 children: [
// // //                   Container(
// // //                     padding: const EdgeInsets.symmetric(
// // //                       vertical: 12,
// // //                       horizontal: 16,
// // //                     ),
// // //                     decoration: BoxDecoration(
// // //                       color: isOnline ? Colors.yellow[700] : Colors.blue,
// // //                       borderRadius: BorderRadius.circular(12),
// // //                       boxShadow: [
// // //                         BoxShadow(
// // //                           color: Colors.black26,
// // //                           blurRadius: 6,
// // //                           offset: Offset(0, 4),
// // //                         ),
// // //                       ],
// // //                     ),
// // //                     child: Row(
// // //                       mainAxisSize: MainAxisSize.min,
// // //                       children: [
// // //                         Icon(
// // //                           isOnline ? Icons.check_circle : Icons.cancel,
// // //                           color: Colors.white,
// // //                         ),
// // //                         SizedBox(width: 10),
// // //                         Text(
// // //                           isOnline ? 'You are Online' : 'You are Offline',
// // //                           style: TextStyle(
// // //                             color: Colors.white,
// // //                             fontSize: 16,
// // //                             fontWeight: FontWeight.bold,
// // //                           ),
// // //                         ),
// // //                       ],
// // //                     ),
// // //                   ),
// // //                   const SizedBox(height: 20),
// // //                   GestureDetector(
// // //                     onTap: () async {
// // //                       if (!isOnline) {
// // //                         await HomeLogics().getDriverOnline(
// // //                           context,
// // //                           ref,
// // //                           controller!,
// // //                         );
// // //                       } else {
// // //                         await HomeLogics().getDriverOffline(context, ref);
// // //                       }
// // //                     },
// // //                     child: Container(
// // //                       alignment: Alignment.center,
// // //                       width: 180,
// // //                       height: 45,
// // //                       decoration: BoxDecoration(
// // //                         color: isOnline ? Colors.blue : Colors.yellow,
// // //                         borderRadius: BorderRadius.circular(10),
// // //                       ),
// // //                       child: Text(
// // //                         isOnline ? 'Go Offline' : 'Go Online',
// // //                         style: TextStyle(
// // //                           color: Colors.white,
// // //                           fontWeight: FontWeight.bold,
// // //                         ),
// // //                       ),
// // //                     ),
// // //                   ),
// // //                 ],
// // //               ),
// // //             ),
// // //           ],
// // //         ),
// // //       ),
// // //     );
// // //   }
// // // }

// // // import 'dart:async';
// // // import 'package:flutter/material.dart';
// // // import 'package:flutter_riverpod/flutter_riverpod.dart';
// // // import 'package:geolocator/geolocator.dart';
// // // import 'package:google_maps_flutter/google_maps_flutter.dart';
// // // import 'package:aminidriver/Container/Repositories/firestore_repo.dart';
// // // import 'package:aminidriver/Container/utils/firebase_messaging.dart';
// // // import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_logics.dart';
// // // import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_providers.dart';
// // // import '../../../../Container/utils/set_blackmap.dart';
// // // import 'package:geoflutterfire2/geoflutterfire2.dart';

// // // final geo = GeoFlutterFire();

// // // class HomeScreen extends ConsumerStatefulWidget {
// // //   const HomeScreen({super.key});

// // //   @override
// // //   ConsumerState<HomeScreen> createState() => _HomeScreenState();
// // // }

// // // class _HomeScreenState extends ConsumerState<HomeScreen> {
// // //   CameraPosition initpos = const CameraPosition(
// // //     target: LatLng(0.0, 0.0),
// // //     zoom: 14,
// // //   );

// // //   final Completer<GoogleMapController> completer = Completer();
// // //   GoogleMapController? controller;
// // //   Geolocator geoLocator = Geolocator();

// // //   @override
// // //   void initState() {
// // //     super.initState();
// // //     MessagingService().init(context);
// // //   }

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     Size size = MediaQuery.sizeOf(context);

// // //     return Scaffold(
// // //       body: SafeArea(
// // //         child: SizedBox(
// // //           width: size.width,
// // //           height: size.height,
// // //           child: Stack(
// // //             children: [
// // //               GoogleMap(
// // //                 mapType: MapType.normal,
// // //                 myLocationButtonEnabled: true,
// // //                 trafficEnabled: true,
// // //                 compassEnabled: true,
// // //                 buildingsEnabled: true,
// // //                 myLocationEnabled: true,
// // //                 zoomControlsEnabled: false,
// // //                 zoomGesturesEnabled: true,
// // //                 initialCameraPosition: initpos,
// // //                 polylines: ref.watch(homeScreenMainPolylinesProvider),
// // //                 markers: ref.watch(homeScreenMainMarkersProvider),
// // //                 circles: ref.watch(homeScreenMainCirclesProvider),
// // //                 onMapCreated: (map) {
// // //                   completer.complete(map);
// // //                   controller = map;
// // //                   SetBlackMap().setBlackMapTheme(map);
// // //                   HomeLogics().getDriverLoc(context, ref, controller!);
// // //                   ref
// // //                       .watch(globalFirestoreRepoProvider)
// // //                       .getDriverDetails(context);
// // //                 },
// // //               ),
// // //               ref.watch(homeScreenIsDriverActiveProvider)
// // //                   ? Container()
// // //                   : Container(
// // //                     height: size.height,
// // //                     width: size.width,
// // //                     color: Colors.black54,
// // //                   ),
// // //               Positioned(
// // //                 top:
// // //                     !ref.watch(homeScreenIsDriverActiveProvider)
// // //                         ? size.height * 0.45
// // //                         : 45,
// // //                 left: 0,
// // //                 right: 0,
// // //                 child: Row(
// // //                   mainAxisAlignment: MainAxisAlignment.center,
// // //                   crossAxisAlignment: CrossAxisAlignment.center,
// // //                   children: [
// // //                     InkWell(
// // //                       onTap: () {
// // //                         if (!ref.watch(homeScreenIsDriverActiveProvider)) {
// // //                           HomeLogics().getDriverOnline(
// // //                             context,
// // //                             ref,
// // //                             controller!,
// // //                           );
// // //                         } else {
// // //                           HomeLogics().getDriverOffline(context, ref);
// // //                         }
// // //                       },
// // //                       child: Container(
// // //                         alignment: Alignment.center,
// // //                         height: 45,
// // //                         width: 200,
// // //                         decoration: BoxDecoration(
// // //                           borderRadius: BorderRadius.circular(14),
// // //                           color: Colors.blue,
// // //                         ),
// // //                         child:
// // //                             !ref.watch(homeScreenIsDriverActiveProvider)
// // //                                 ? const Text("You are Offline")
// // //                                 : const Icon(
// // //                                   Icons.phonelink_ring_outlined,
// // //                                   color: Colors.white,
// // //                                   size: 20,
// // //                                 ),
// // //                       ),
// // //                     ),
// // //                   ],
// // //                 ),
// // //               ),
// // //             ],
// // //           ),
// // //         ),
// // //       ),
// // //     );
// // //   }
// // // }
