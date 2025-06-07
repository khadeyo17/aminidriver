import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:aminidriver/Container/utils/firebase_messaging.dart';
import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_logics.dart';
import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_providers.dart';
import '../../../../Container/utils/set_blackmap.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';

final geo = GeoFlutterFire();

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  GoogleMapController? controller;
  CameraPosition _initialPosition = const CameraPosition(
    target: LatLng(0.0, 0.0),
    zoom: 14,
  );

  @override
  void initState() {
    super.initState();
    MessagingService().init(context);
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.sizeOf(context);
    final isOnline = ref.watch(homeScreenIsDriverActiveProvider);
    final firestoreRepo = ref.watch(
      globalFirestoreRepoProvider,
    ); // Properly watch the Firestore provider

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            GoogleMap(
              mapType: MapType.normal,
              myLocationButtonEnabled: true,
              myLocationEnabled: true,
              zoomControlsEnabled: false,
              initialCameraPosition: _initialPosition,
              polylines: ref.watch(homeScreenMainPolylinesProvider),
              markers: ref.watch(homeScreenMainMarkersProvider),
              circles: ref.watch(homeScreenMainCirclesProvider),
              onMapCreated: (map) async {
                _mapController.complete(map);
                controller = map;
                SetBlackMap().setBlackMapTheme(map);

                // Get current location and details
                HomeLogics().getDriverLoc(context, ref, map);
                await firestoreRepo.getDriverDetails(
                  context,
                ); // Proper async function call
              },
            ),

            // If driver is offline, overlay black shade
            if (!isOnline)
              Container(
                width: size.width,
                height: size.height,
                color: Colors.black,
              ),

            // Status and Toggle Button
            Positioned(
              top: isOnline ? 30 : size.height * 0.4,
              left: 20,
              right: 20,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.yellow[700] : Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOnline ? Icons.check_circle : Icons.cancel,
                          color: Colors.white,
                        ),
                        SizedBox(width: 10),
                        Text(
                          isOnline ? 'You are Online' : 'You are Offline',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () async {
                      if (!isOnline) {
                        await HomeLogics().getDriverOnline(
                          context,
                          ref,
                          controller!,
                        );
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
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:aminidriver/Container/Repositories/firestore_repo.dart';
// import 'package:aminidriver/Container/utils/firebase_messaging.dart';
// import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_logics.dart';
// import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_providers.dart';
// import '../../../../Container/utils/set_blackmap.dart';
// import 'package:geoflutterfire2/geoflutterfire2.dart';

// final geo = GeoFlutterFire();

// class HomeScreen extends ConsumerStatefulWidget {
//   const HomeScreen({super.key});

//   @override
//   ConsumerState<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends ConsumerState<HomeScreen> {
//   CameraPosition initpos = const CameraPosition(
//     target: LatLng(0.0, 0.0),
//     zoom: 14,
//   );

//   final Completer<GoogleMapController> completer = Completer();
//   GoogleMapController? controller;
//   Geolocator geoLocator = Geolocator();

//   @override
//   void initState() {
//     super.initState();
//     MessagingService().init(context);
//   }

//   @override
//   Widget build(BuildContext context) {
//     Size size = MediaQuery.sizeOf(context);

//     return Scaffold(
//       body: SafeArea(
//         child: SizedBox(
//           width: size.width,
//           height: size.height,
//           child: Stack(
//             children: [
//               GoogleMap(
//                 mapType: MapType.normal,
//                 myLocationButtonEnabled: true,
//                 trafficEnabled: true,
//                 compassEnabled: true,
//                 buildingsEnabled: true,
//                 myLocationEnabled: true,
//                 zoomControlsEnabled: false,
//                 zoomGesturesEnabled: true,
//                 initialCameraPosition: initpos,
//                 polylines: ref.watch(homeScreenMainPolylinesProvider),
//                 markers: ref.watch(homeScreenMainMarkersProvider),
//                 circles: ref.watch(homeScreenMainCirclesProvider),
//                 onMapCreated: (map) {
//                   completer.complete(map);
//                   controller = map;
//                   SetBlackMap().setBlackMapTheme(map);
//                   HomeLogics().getDriverLoc(context, ref, controller!);
//                   ref
//                       .watch(globalFirestoreRepoProvider)
//                       .getDriverDetails(context);
//                 },
//               ),
//               ref.watch(homeScreenIsDriverActiveProvider)
//                   ? Container()
//                   : Container(
//                     height: size.height,
//                     width: size.width,
//                     color: Colors.black54,
//                   ),
//               Positioned(
//                 top:
//                     !ref.watch(homeScreenIsDriverActiveProvider)
//                         ? size.height * 0.45
//                         : 45,
//                 left: 0,
//                 right: 0,
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   crossAxisAlignment: CrossAxisAlignment.center,
//                   children: [
//                     InkWell(
//                       onTap: () {
//                         if (!ref.watch(homeScreenIsDriverActiveProvider)) {
//                           HomeLogics().getDriverOnline(
//                             context,
//                             ref,
//                             controller!,
//                           );
//                         } else {
//                           HomeLogics().getDriverOffline(context, ref);
//                         }
//                       },
//                       child: Container(
//                         alignment: Alignment.center,
//                         height: 45,
//                         width: 200,
//                         decoration: BoxDecoration(
//                           borderRadius: BorderRadius.circular(14),
//                           color: Colors.blue,
//                         ),
//                         child:
//                             !ref.watch(homeScreenIsDriverActiveProvider)
//                                 ? const Text("You are Offline")
//                                 : const Icon(
//                                   Icons.phonelink_ring_outlined,
//                                   color: Colors.white,
//                                   size: 20,
//                                 ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
