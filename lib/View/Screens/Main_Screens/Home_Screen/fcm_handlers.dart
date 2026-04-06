import 'package:aminidriver/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:uuid/uuid.dart';

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // ✅ Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  debugPrint("🔥 BACKGROUND TRIGGERED: ${message.data}");

  // ✅ Save debug log (optional)
  try {
    final ref = FirebaseDatabase.instance.ref("rides/backgroundLogs");
    await ref.push().set({
      "rideId": message.data['rideId'] ?? "noId",
      "timestamp": DateTime.now().toIso8601String(),
      "pickup": message.data['pickupName'] ?? "",
      "destination": message.data['destinationName'] ?? "",
    });
  } catch (e) {
    debugPrint("❌ Failed to log background ride: $e");
  }

  // ✅ SHOW CALLKIT (MAIN FIX)
  if (message.data['type'] == 'ride_request') {
    try {
      final uuid = const Uuid().v4(); // 🔥 REAL CALL ID

      await FlutterCallkitIncoming.showCallkitIncoming(
        CallKitParams(
          id: uuid, // ✅ MUST be unique
          nameCaller: message.data['rider'] ?? "Passenger",
          appName: "Amini Driver",
          handle:
              "${message.data['pickupName']} → ${message.data['destinationName']}",
          type: 0,
          duration: 30000,

          // 🔥 VERY IMPORTANT (PASS DATA HERE)
          extra: {
            "rideId": message.data['rideId'],
            "rideRequestId": message.data['rideRequestId'],
            "rider": message.data['rider'],
            "pickupName": message.data['pickupName'],
            "destinationName": message.data['destinationName'],
            "pickupLat": message.data['pickupLat'],
            "pickupLng": message.data['pickupLng'],
            "destLat": message.data['destLat'],
            "destLng": message.data['destLng'],
            "callId": uuid, // 🔥 CRITICAL
          },

          android: const AndroidParams(
            isCustomNotification: true,
            isShowLogo: false,
            ringtonePath: "ringtones/ringtone", // no .mp3
            backgroundColor: "#000000",
            actionColor: "#4CAF50",
          ),
        ),
      );

      debugPrint("✅ CallKit shown with UUID: $uuid");
    } catch (e) {
      debugPrint("❌ Callkit error: $e");
    }
  }
}

// import 'package:aminidriver/firebase_options.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_database/firebase_database.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
// import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
// import 'package:flutter_callkit_incoming/entities/android_params.dart';

// Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   // Initialize Firebase for the background isolate
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

//   debugPrint("🔥 BACKGROUND TRIGGERED: ${message.data}");

//   // ⚡ Write log to Firebase DB
//   try {
//     final ref = FirebaseDatabase.instance.ref("rides/backgroundLogs");
//     await ref.push().set({
//       "rideId": message.data['rideId'] ?? "noId",
//       "timestamp": DateTime.now().toIso8601String(),
//       "pickup": message.data['pickupName'] ?? "",
//       "destination": message.data['destinationName'] ?? "",
//     });
//     debugPrint("✅ Background log written");
//   } catch (e) {
//     debugPrint("❌ Failed to log background ride: $e");
//   }

//   // ⚡ Show CallKit incoming
//   if (message.data['type'] == 'ride_request') {
//     try {
//       await FlutterCallkitIncoming.showCallkitIncoming(
//         CallKitParams(
//           id: message.data['rideId'] ?? DateTime.now().toString(),
//           nameCaller: message.data['rider'] ?? "Passenger",
//           appName: "Amini Driver",
//           handle:
//               "${message.data['pickupName']} → ${message.data['destinationName']}",
//           type: 0,
//           duration: 30000,
//           android: const AndroidParams(
//             isCustomNotification: true,
//             isShowLogo: false,
//             ringtonePath: "ringtone",
//             backgroundColor: "#000000",
//             actionColor: "#4CAF50",
//           ),
//         ),
//       );
//     } catch (e) {
//       debugPrint("❌ Callkit error: $e");
//     }
//   }
// }
