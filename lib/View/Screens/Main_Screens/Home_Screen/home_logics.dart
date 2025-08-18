import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aminidriver/Container/Repositories/address_parser_repo.dart';
import 'package:aminidriver/Container/utils/api_constant.dart';
import 'package:aminidriver/Container/utils/error_notification.dart';
import 'package:aminidriver/Container/utils/keys.dart';
import 'package:aminidriver/Onboarding/driver_location_live.dart';
import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_providers.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

final geo = GeoFlutterFire();
StreamSubscription<Position>? positionStream;

class HomeLogics {
  /// Animate Google Map to driver's current location
  Future<void> getDriverLoc(
    BuildContext context,
    WidgetRef ref,
    GoogleMapController controller,
  ) async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));

      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 14.0),
      );

      if (context.mounted) {
        await ref
            .watch(globalAddressParserProvider)
            .humanReadableAddress(pos, context, ref);
      }
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(context, "Unable to fetch location: $e");
      }
    }
  }

  Future<void> fetchAndUpdateDriverStatus(WidgetRef ref) async {
    final user = FirebaseAuth.instance.currentUser;
    final firebaseUid = user?.uid;

    if (firebaseUid == null) {
      print("❌ Firebase UID is null.");
      return;
    }

    final url = Uri.parse('$baseUrl/rides/driver-status/$firebaseUid');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isOnline = data['isOnline'] as bool?;
        if (isOnline != null) {
          ref.read(homeScreenIsDriverActiveProvider.notifier).state = isOnline;
        }
      } else {
        print("❌ Backend error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("❌ Exception: $e");
    }
  }

  Future<void> updateDriverAvailability(
    String firebaseUid,
    bool isOnline,
  ) async {
    final url = Uri.parse('$baseUrl/rides/updatedriver-status/$firebaseUid');

    try {
      final response = await Dio().put(
        url.toString(),
        data: isOnline,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        DriverLocationService().startSendingLocation();
        print("✅ Driver availability updated: ${response.data}");
      } else {
        print("❌ Failed to update availability: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Error updating availability: $e");
    }
  }

  Future<void> getDriverOnline(
    BuildContext context,
    WidgetRef ref,
    GoogleMapController mapController,
  ) async {
    try {
      final location = ref.read(homeScreenDriversLocationProvider);
      final firebaseUid = ref.read(driverFirebaseUidProvider);

      if (location == null || firebaseUid == null) {
        ErrorNotification().showError(context, "Location or UID unavailable.");
        return;
      }

      final myLocation = geo.point(
        latitude: location.locationLatitude!,
        longitude: location.locationLongitude!,
      );

      // Update availability on backend
      await updateDriverAvailability(firebaseUid, true);

      await ref
          .read(globalFirestoreRepoProvider)
          .setDriverLocationStatus(context, myLocation);

      positionStream = Geolocator.getPositionStream().listen((event) async {
        final liveLocation = geo.point(
          latitude: event.latitude,
          longitude: event.longitude,
        );
        DriverLocationService().startSendingLocation();
        await ref
            .read(globalFirestoreRepoProvider)
            .setDriverLocationStatus(context, liveLocation);
      });

      // Animate Google Map to driver's location
      await mapController.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(location.locationLatitude!, location.locationLongitude!),
          14.0,
        ),
      );

      await ref
          .read(globalFirestoreRepoProvider)
          .setDriverStatus(context, "Idle");
      ref.read(homeScreenIsDriverActiveProvider.notifier).update((_) => true);
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(context, "Failed to go online: $e");
      }
    }
  }

  Future<void> getDriverOffline(BuildContext context, WidgetRef ref) async {
    try {
      final firebaseUid = ref.read(driverFirebaseUidProvider);
      if (firebaseUid == null) {
        ErrorNotification().showError(context, "Driver UID is missing");
        return;
      }

      DriverLocationService().startSendingLocation();

      // Update backend
      await updateDriverAvailability(firebaseUid, false);

      ref.read(homeScreenIsDriverActiveProvider.notifier).update((_) => false);

      await ref
          .read(globalFirestoreRepoProvider)
          .setDriverStatus(context, "offline");
      await ref
          .read(globalFirestoreRepoProvider)
          .setDriverLocationStatus(context, null);

      positionStream?.cancel();

      await Future.delayed(const Duration(seconds: 2));

      if (context.mounted) {
        ErrorNotification().showSuccess(context, "You are now Offline");
      }

      SystemChannels.platform.invokeMethod("SystemNavigator.pop");
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(context, "Failed to go offline: $e");
      }
    }
  }

  /// Send FCM notification to user on trip request response
  Future<void> sendNotificationToUser(
    BuildContext context,
    String driverRes,
  ) async {
    try {
      await Dio().post(
        "https://fcm.googleapis.com/fcm/send",
        options: Options(
          headers: {
            HttpHeaders.contentTypeHeader: "application/json",
            HttpHeaders.authorizationHeader: "Bearer YOUR_FCM_SERVER_KEY",
          },
        ),
        data: {
          "data": {"screen": "home"},
          "notification": {
            "title": "Driver's Response",
            "status": driverRes,
            "body":
                driverRes == "accepted"
                    ? "The Driver will arrive soon."
                    : "Sorry, the Driver is not available.",
          },
          "to": "USER_FCM_TOKEN",
        },
      );
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(context, "Notification failed: $e");
      }
    }
  }
}



// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';

// import 'package:aminidriver/Container/Repositories/address_parser_repo.dart';
// import 'package:aminidriver/Container/utils/api_constant.dart';
// import 'package:aminidriver/Container/utils/error_notification.dart';
// import 'package:aminidriver/Container/utils/keys.dart';
// import 'package:aminidriver/Onboarding/driver_location_live.dart';
// import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_providers.dart';
// import 'package:dio/dio.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:geoflutterfire2/geoflutterfire2.dart';
// import 'package:http/http.dart' as http;
// import 'package:latlong2/latlong.dart';

// final geo = GeoFlutterFire();
// StreamSubscription<Position>? positionStream;

// class HomeLogics {
//   /// Get driver's current location and animate map to it
//   ///

//   Future<void> getDriverLoc(
//     BuildContext context,
//     WidgetRef ref,
//     MapController controller,
//   ) async {
//     try {
//       Position pos = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       ).timeout(const Duration(seconds: 10));

//       controller.move(LatLng(pos.latitude, pos.longitude), 14.0);

//       if (context.mounted) {
//         await ref
//             .watch(globalAddressParserProvider)
//             .humanReadableAddress(pos, context, ref);
//       }
//     } catch (e) {
//       if (context.mounted) {
//         ErrorNotification().showError(context, "Unable to fetch location: $e");
//       }
//     }
//   }

//   // Future<bool?> getDriverStatus() async {
//   //   final user = FirebaseAuth.instance.currentUser;
//   //   final firebaseUid = user?.uid;

//   //   if (firebaseUid == null) {
//   //     print("Firebase UID is null. User might not be logged in.");
//   //     return null;
//   //   }

//   //   final url = Uri.parse('$baseUrl/rides/driver-status/$firebaseUid');

//   //   try {
//   //     final response = await http.get(url);

//   //     if (response.statusCode == 200) {
//   //       final data = jsonDecode(response.body);
//   //       return data['isOnline'] as bool?;
//   //     } else {
//   //       print("Error: ${response.statusCode} - ${response.body}");
//   //       return null;
//   //     }
//   //   } catch (e) {
//   //     print("Exception while getting driver status: $e");
//   //     return null;
//   //   }
//   // }

//   Future<void> fetchAndUpdateDriverStatus(WidgetRef ref) async {
//     final user = FirebaseAuth.instance.currentUser;
//     final firebaseUid = user?.uid;

//     if (firebaseUid == null) {
//       print("❌ Firebase UID is null.");
//       return;
//     }

//     final url = Uri.parse('$baseUrl/rides/driver-status/$firebaseUid');

//     try {
//       final response = await http.get(url);
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         final isOnline = data['isOnline'] as bool?;
//         if (isOnline != null) {
//           ref.read(homeScreenIsDriverActiveProvider.notifier).state = isOnline;
//         }
//       } else {
//         print("❌ Backend error: ${response.statusCode} - ${response.body}");
//       }
//     } catch (e) {
//       print("❌ Exception: $e");
//     }
//   }

//   Future<void> updateDriverAvailability(
//     String firebaseUid,
//     bool isOnline,
//   ) async {
//     final url = Uri.parse('$baseUrl/rides/updatedriver-status/$firebaseUid');

//     try {
//       final response = await Dio().put(
//         url.toString(),
//         data: isOnline,
//         options: Options(headers: {'Content-Type': 'application/json'}),
//       );

//       if (response.statusCode == 200) {
//         DriverLocationService().startSendingLocation();
//         print("✅ Driver availability updated: ${response.data}");
//       } else {
//         print("❌ Failed to update availability: ${response.statusCode}");
//       }
//     } catch (e) {
//       print("❌ Error updating availability: $e");
//     }
//   }

//   // Future<void> getDriverOnline(
//   //   BuildContext context,
//   //   WidgetRef ref,
//   //   MapController controller,
//   // ) 
//   Future<void> getDriverOnline(BuildContext context, WidgetRef ref, GoogleMapController mapController)

  
//   async {
//     try {
//       final location = ref.read(homeScreenDriversLocationProvider);
//       final firebaseUid = ref.read(
//         driverFirebaseUidProvider,
//       ); // <-- You need to provide this via Riverpod or elsewhere

//       if (location == null || firebaseUid == null) {
//         ErrorNotification().showError(context, "Location or UID unavailable.");
//         return;
//       }

//       final myLocation = geo.point(
//         latitude: location.locationLatitude!,
//         longitude: location.locationLongitude!,
//       );

//       // Update availability on backend
//       await updateDriverAvailability(firebaseUid, true);

//       await ref
//           .read(globalFirestoreRepoProvider)
//           .setDriverLocationStatus(context, myLocation);

//       positionStream = Geolocator.getPositionStream().listen((event) async {
//         final liveLocation = geo.point(
//           latitude: event.latitude,
//           longitude: event.longitude,
//         );
//         DriverLocationService().startSendingLocation();
//         await ref
//             .read(globalFirestoreRepoProvider)
//             .setDriverLocationStatus(context, liveLocation);
//       });

//       controller.move(
//         LatLng(location.locationLatitude!, location.locationLongitude!),
//         14.0,
//       );

//       await ref
//           .read(globalFirestoreRepoProvider)
//           .setDriverStatus(context, "Idle");

//       ref.read(homeScreenIsDriverActiveProvider.notifier).update((_) => true);
//     } catch (e) {
//       if (context.mounted) {
//         ErrorNotification().showError(context, "Failed to go online: $e");
//       }
//     }
//   }

//   Future<void> getDriverOffline(BuildContext context, WidgetRef ref) async {
//     try {
//       final firebaseUid = ref.read(
//         driverFirebaseUidProvider,
//       ); // <-- Also provide this
//       if (firebaseUid == null) {
//         ErrorNotification().showError(context, "Driver UID is missing");
//         return;
//       }
//       DriverLocationService().startSendingLocation();
//       // Update backend
//       await updateDriverAvailability(firebaseUid, false);

//       ref.read(homeScreenIsDriverActiveProvider.notifier).update((_) => false);

//       await ref
//           .read(globalFirestoreRepoProvider)
//           .setDriverStatus(context, "offline");
//       await ref
//           .read(globalFirestoreRepoProvider)
//           .setDriverLocationStatus(context, null);

//       positionStream?.cancel();

//       await Future.delayed(const Duration(seconds: 2));

//       if (context.mounted) {
//         ErrorNotification().showSuccess(context, "You are now Offline");
//       }

//       SystemChannels.platform.invokeMethod("SystemNavigator.pop");
//     } catch (e) {
//       if (context.mounted) {
//         ErrorNotification().showError(context, "Failed to go offline: $e");
//       }
//     }
//   }
//   /// Send FCM notification to user on trip request response
//   Future<void> sendNotificationToUser(
//     BuildContext context,
//     String driverRes,
//   ) async {
//     try {
//       await Dio().post(
//         "https://fcm.googleapis.com/fcm/send",
//         options: Options(
//           headers: {
//             HttpHeaders.contentTypeHeader: "application/json",
//             HttpHeaders.authorizationHeader: "Bearer YOUR_FCM_SERVER_KEY",
//           },
//         ),
//         data: {
//           "data": {"screen": "home"},
//           "notification": {
//             "title": "Driver's Response",
//             "status": driverRes,
//             "body":
//                 "The Driver has $driverRes your request. "
//                 "${driverRes == "accepted" ? "They will arrive soon." : "Sorry, the Driver is not available."}",
//           },
//           "to": "USER_FCM_TOKEN",
//         },
//       );
//     } catch (e) {
//       if (context.mounted) {
//         ErrorNotification().showError(context, "Notification failed: $e");
//       }
//     }
//   }
// }

// // import 'dart:async';
// // import 'dart:io';

// // import 'package:aminidriver/Container/Repositories/address_parser_repo.dart';
// // import 'package:aminidriver/Container/utils/error_notification.dart';
// // import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_providers.dart';
// // import 'package:dio/dio.dart';
// // import 'package:flutter/material.dart';
// // import 'package:flutter/services.dart';
// // import 'package:flutter_riverpod/flutter_riverpod.dart';
// // import 'package:flutter_map/flutter_map.dart';
// // import 'package:geolocator/geolocator.dart';
// // import 'package:geoflutterfire2/geoflutterfire2.dart';
// // import 'package:latlong2/latlong.dart';

// // final geo = GeoFlutterFire();
// // StreamSubscription<Position>? positionStream;

// // class HomeLogics {
// //   /// Get driver's current location and animate map to it
// //   Future<void> getDriverLoc(
// //     BuildContext context,
// //     WidgetRef ref,
// //     MapController controller,
// //   ) async {
// //     try {
// //       Position pos = await Geolocator.getCurrentPosition(
// //         desiredAccuracy: LocationAccuracy.high,
// //       ).timeout(const Duration(seconds: 10));

// //       controller.move(LatLng(pos.latitude, pos.longitude), 14.0);

// //       if (context.mounted) {
// //         await ref
// //             .watch(globalAddressParserProvider)
// //             .humanReadableAddress(pos, context, ref);
// //       }
// //     } catch (e) {
// //       if (context.mounted) {
// //         ErrorNotification().showError(context, "Unable to fetch location: $e");
// //       }
// //     }
// //   }

// //   /// Bring driver online and update backend
// //   Future<void> getDriverOnline(
// //     BuildContext context,
// //     WidgetRef ref,
// //     MapController controller,
// //   ) async {
// //     try {
// //       final location = ref.read(homeScreenDriversLocationProvider);
// //       if (location == null) {
// //         ErrorNotification().showError(context, "Location data unavailable.");
// //         return;
// //       }

// //       final myLocation = geo.point(
// //         latitude: location.locationLatitude!,
// //         longitude: location.locationLongitude!,
// //       );

// //       await ref
// //           .read(globalFirestoreRepoProvider)
// //           .setDriverLocationStatus(context, myLocation);

// //       positionStream = Geolocator.getPositionStream().listen((event) async {
// //         final liveLocation = geo.point(
// //           latitude: event.latitude,
// //           longitude: event.longitude,
// //         );
// //         await ref
// //             .read(globalFirestoreRepoProvider)
// //             .setDriverLocationStatus(context, liveLocation);
// //       });

// //       controller.move(
// //         LatLng(location.locationLatitude!, location.locationLongitude!),
// //         14.0,
// //       );

// //       await ref
// //           .read(globalFirestoreRepoProvider)
// //           .setDriverStatus(context, "Idle");

// //       ref.read(homeScreenIsDriverActiveProvider.notifier).update((_) => true);
// //     } catch (e) {
// //       if (context.mounted) {
// //         ErrorNotification().showError(context, "Failed to go online: $e");
// //       }
// //     }
// //   }

// //   /// Take driver offline and update backend
// //   Future<void> getDriverOffline(BuildContext context, WidgetRef ref) async {
// //     try {
// //       ref.read(homeScreenIsDriverActiveProvider.notifier).update((_) => false);

// //       await ref
// //           .read(globalFirestoreRepoProvider)
// //           .setDriverStatus(context, "offline");
// //       await ref
// //           .read(globalFirestoreRepoProvider)
// //           .setDriverLocationStatus(context, null);

// //       positionStream?.cancel();

// //       await Future.delayed(const Duration(seconds: 2));

// //       if (context.mounted) {
// //         ErrorNotification().showSuccess(context, "You are now Offline");
// //       }

// //       SystemChannels.platform.invokeMethod("SystemNavigator.pop");
// //     } catch (e) {
// //       if (context.mounted) {
// //         ErrorNotification().showError(context, "Failed to go offline: $e");
// //       }
// //     }
// //   }

// //   /// Send FCM notification to user on trip request response
// //   Future<void> sendNotificationToUser(
// //     BuildContext context,
// //     String driverRes,
// //   ) async {
// //     try {
// //       await Dio().post(
// //         "https://fcm.googleapis.com/fcm/send",
// //         options: Options(
// //           headers: {
// //             HttpHeaders.contentTypeHeader: "application/json",
// //             HttpHeaders.authorizationHeader: "Bearer YOUR_FCM_SERVER_KEY",
// //           },
// //         ),
// //         data: {
// //           "data": {"screen": "home"},
// //           "notification": {
// //             "title": "Driver's Response",
// //             "status": driverRes,
// //             "body":
// //                 "The Driver has $driverRes your request. "
// //                 "${driverRes == "accepted" ? "They will arrive soon." : "Sorry, the Driver is not available."}",
// //           },
// //           "to": "USER_FCM_TOKEN",
// //         },
// //       );
// //     } catch (e) {
// //       if (context.mounted) {
// //         ErrorNotification().showError(context, "Notification failed: $e");
// //       }
// //     }
// //   }
// // }

// // import 'dart:io';

// // import 'package:aminidriver/Container/Repositories/address_parser_repo.dart';
// // import 'package:dio/dio.dart';
// // import 'package:flutter/material.dart';
// // import 'package:flutter/services.dart';
// // import 'package:flutter_riverpod/flutter_riverpod.dart';
// // import 'package:google_maps_flutter/google_maps_flutter.dart';
// // import 'package:geolocator/geolocator.dart';
// // import 'package:geoflutterfire2/geoflutterfire2.dart';
// // import 'package:aminidriver/Container/utils/error_notification.dart';
// // import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_providers.dart';

// // final geo = GeoFlutterFire();

// // class HomeLogics {
// //   /// Get driver's current location and animate map to it
// //   Future<void> getDriverLoc(
// //     BuildContext context,
// //     WidgetRef ref,
// //     GoogleMapController controller,
// //   ) async {
// //     try {
// //       Position pos = await Geolocator.getCurrentPosition(
// //         desiredAccuracy: LocationAccuracy.high,
// //       );

// //       controller.animateCamera(
// //         CameraUpdate.newCameraPosition(
// //           CameraPosition(target: LatLng(pos.latitude, pos.longitude), zoom: 14),
// //         ),
// //       );

// //       if (context.mounted) {
// //         await ref
// //             .watch(globalAddressParserProvider)
// //             .humanReadableAddress(pos, context, ref);
// //       }
// //     } catch (e) {
// //       if (context.mounted) {
// //         ErrorNotification().showError(context, "Unable to fetch location: $e");
// //       }
// //     }
// //   }

// //   /// Bring driver online and update backend
// //   Future<void> getDriverOnline(
// //     BuildContext context,
// //     WidgetRef ref,
// //     GoogleMapController controller,
// //   ) async {
// //     try {
// //       //final location = ref.watch(homeScreenDriversLocationProvider);
// //       final location = ref.read(homeScreenDriversLocationProvider);
// //       if (location == null) {
// //         ErrorNotification().showError(context, "Location data unavailable.");
// //         return;
// //       }

// //       final myLocation = geo.point(
// //         latitude: location.locationLatitude!,
// //         longitude: location.locationLongitude!,
// //       );

// //       await ref
// //           .read(globalFirestoreRepoProvider)
// //           .setDriverLocationStatus(context, myLocation);

// //       // Listen and update location in real-time
// //       Geolocator.getPositionStream().listen((event) async {
// //         final liveLocation = geo.point(
// //           latitude: event.latitude,
// //           longitude: event.longitude,
// //         );
// //         await ref
// //             .read(globalFirestoreRepoProvider)
// //             .setDriverLocationStatus(context, liveLocation);
// //       });

// //       final driverPos = LatLng(
// //         location.locationLatitude!,
// //         location.locationLongitude!,
// //       );
// //       controller.animateCamera(CameraUpdate.newLatLng(driverPos));

// //       await ref
// //           .read(globalFirestoreRepoProvider)
// //           .setDriverStatus(context, "Idle");

// //       ref.read(homeScreenIsDriverActiveProvider.notifier).update((_) => true);
// //     } catch (e) {
// //       if (context.mounted) {
// //         ErrorNotification().showError(context, "Failed to go online: $e");
// //       }
// //     }
// //   }

// //   /// Take driver offline and update backend
// //   Future<void> getDriverOffline(BuildContext context, WidgetRef ref) async {
// //     try {
// //       ref.read(homeScreenIsDriverActiveProvider.notifier).update((_) => false);

// //       await ref
// //           .read(globalFirestoreRepoProvider)
// //           .setDriverStatus(context, "offline");
// //       await ref
// //           .read(globalFirestoreRepoProvider)
// //           .setDriverLocationStatus(context, null);

// //       await Future.delayed(const Duration(seconds: 2));

// //       if (context.mounted) {
// //         ErrorNotification().showSuccess(context, "You are now Offline");
// //       }

// //       // Optional: close app when offline
// //       SystemChannels.platform.invokeMethod("SystemNavigator.pop");
// //     } catch (e) {
// //       if (context.mounted) {
// //         ErrorNotification().showError(context, "Failed to go offline: $e");
// //       }
// //     }
// //   }

// //   /// Send FCM notification to user on trip request response
// //   Future<void> sendNotificationToUser(
// //     BuildContext context,
// //     String driverRes,
// //   ) async {
// //     try {
// //       await Dio().post(
// //         "https://fcm.googleapis.com/fcm/send",
// //         options: Options(
// //           headers: {
// //             HttpHeaders.contentTypeHeader: "application/json",
// //             HttpHeaders.authorizationHeader: "Bearer YOUR_FCM_SERVER_KEY",
// //           },
// //         ),
// //         data: {
// //           "data": {"screen": "home"},
// //           "notification": {
// //             "title": "Driver's Response",
// //             "status": driverRes,
// //             "body":
// //                 "The Driver has $driverRes your request. "
// //                 "${driverRes == "accepted" ? "They will arrive soon." : "Sorry, the Driver is not available."}",
// //           },
// //           "to": "USER_FCM_TOKEN",
// //         },
// //       );
// //     } catch (e) {
// //       if (context.mounted) {
// //         ErrorNotification().showError(context, "Notification failed: $e");
// //       }
// //     }
// //   }
// // }
