import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:aminidriver/Container/utils/error_notification.dart';
import 'package:aminidriver/Container/utils/keys.dart';
import 'package:aminidriver/Container/utils/pending_ride_storage.dart';
import 'package:aminidriver/Onboarding/approval_service.dart';
import 'package:aminidriver/Onboarding/driveronboardingscreen.dart';
import 'package:aminidriver/Onboarding/ride_alert.dart';
import 'package:aminidriver/Onboarding/user_role.dart';
import 'package:aminidriver/View/Screens/Auth_Screens/Register_Screen/hub.dart';
import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:aminidriver/View/Routes/routes.dart';
import 'package:http/http.dart' as http;
import 'package:signalr_core/signalr_core.dart';

class SplashLogics {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ApprovalService _approvalService = ApprovalService();

  /// 🚀 ENTRY POINT
  void initializeUser(BuildContext context) async {
    try {
      final User? user = _auth.currentUser;

      // ❌ 1. NOT LOGGED IN → REGISTER
      if (user == null) {
        if (context.mounted) context.goNamed(Routes().register);
        return;
      }

      // 🌐 2. CHECK INTERNET
      final isConnected = await _checkNetwork();
      if (!isConnected) {
        if (context.mounted) {
          ErrorNotification().showError(
            context,
            "No internet connection. Please reconnect.",
          );
        }
        return;
      }

      // ✅ 3. CONTINUE
      await _runBackgroundSetup(context, user);
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(context, "Initialization error: $e");
      }
    }
  }

  /// 🔥 MAIN LOGIC
  Future<void> _runBackgroundSetup(BuildContext context, User user) async {
    try {
      // 1️⃣ Get Firebase UID
      final firebaseUid = user.uid;

      // 2️⃣ Get ID token and FCM token in parallel
      final idToken = await user.getIdToken();
      final fcmToken = await FirebaseMessaging.instance.getToken();

      // 3️⃣ Fetch user data from backend using token-only authorization
      final response = await http.get(
        Uri.parse("$baseUrl/auth/check-user"),
        headers: {
          HttpHeaders.contentTypeHeader: 'application/json',
          HttpHeaders.authorizationHeader:
              'Bearer $idToken', // ✅ Use token here
        },
      );

      // 4️⃣ If user not in backend → redirect to registration
      if (response.statusCode != 200) {
        if (context.mounted) context.goNamed(Routes().register);
        return;
      }

      // 5️⃣ Parse backend user data
      final Map<String, dynamic> userData = jsonDecode(response.body);

      // 🔥 Validate essential backend fields
      final bool hasBackendUser =
          userData.isNotEmpty &&
          userData['phone'] != null &&
          userData['phone'].toString().trim().isNotEmpty;

      if (!hasBackendUser) {
        if (context.mounted) context.goNamed(Routes().register);
        return;
      }

      // 6️⃣ Determine user role safely
      final int roleIndex = userData['role'] ?? 0;
      final UserRole role =
          (roleIndex >= 0 && roleIndex < UserRole.values.length)
              ? UserRole.values[roleIndex]
              : UserRole.passenger;

      final bool isApproved = userData['isApproved'] ?? false;

      // 7️⃣ Update FCM token in the background
      unawaited(_updateFcmToken(idToken.toString(), fcmToken));

      // 8️⃣ Restore pending ride if any
      final pendingRide = await getPendingRide();
      if (pendingRide != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => RideAlertScreen(
                  rideId: pendingRide['rideId'] ?? '',
                  rideRequestId: pendingRide['rideRequestId'] ?? '',
                  rider: pendingRide['rider'] ?? '',
                  pickupName: pendingRide['pickupName'] ?? '',
                  destinationName: pendingRide['destinationName'] ?? '',
                  pickupLat: _parseDouble(pendingRide['pickupLat']),
                  pickupLng: _parseDouble(pendingRide['pickupLng']),
                  destLat: _parseDouble(pendingRide['destLat']),
                  destLng: _parseDouble(pendingRide['destLng']),
                ),
          ),
        );
        return;
      }

      // 9️⃣ Routing logic based on approval & role
      if (isApproved) {
        if (context.mounted) context.goNamed(Routes().navigationScreen);
        return;
      }

      if (context.mounted) {
        switch (role) {
          case UserRole.driver:
          case UserRole.owner:
          case UserRole.driverOwner:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DriverOnboardingScreen(role: role),
              ),
            );

            break;

          case UserRole.passenger:
          default:
            context.goNamed(Routes().navigationScreen);
            break;
        }
      }
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(context, "Setup failed: $e");
      }
    }
  }

  /// 🌐 INTERNET CHECK
  Future<bool> _checkNetwork() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// 🔔 UPDATE FCM TOKEN
  Future<void> _updateFcmToken(String token, String? fcmToken) async {
    if (fcmToken == null) return;

    try {
      await http.post(
        Uri.parse('$baseUrl/auth/update-fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'fcmToken': fcmToken}),
      );
    } catch (e) {
      debugPrint("FCM update failed: $e");
    }
  }

  /// 🔢 SAFE DOUBLE PARSER
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// 📍 LOCATION PERMISSIONS
  void checkPermissions(BuildContext context) async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (context.mounted) {
          ErrorNotification().showError(
            context,
            "Location permission is required.",
          );
          await Future.delayed(const Duration(seconds: 2));
          SystemChannels.platform.invokeMethod(
            "SystemNavigator.exitApplication",
          );
        }
        return;
      }

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        initializeUser(context);
      }
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(context, "Permission error: $e");
      }
    }
  }
}
// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'package:aminidriver/Container/utils/error_notification.dart';
// import 'package:aminidriver/Container/utils/keys.dart';
// import 'package:aminidriver/Container/utils/pending_ride_storage.dart';
// import 'package:aminidriver/Onboarding/approval_service.dart';
// import 'package:aminidriver/Onboarding/driveronboardingscreen.dart';
// import 'package:aminidriver/Onboarding/ride_alert.dart';
// import 'package:aminidriver/Onboarding/user_role.dart';
// import 'package:aminidriver/View/Screens/Auth_Screens/Register_Screen/hub.dart';
// import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_screen.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:go_router/go_router.dart';
// import 'package:aminidriver/View/Routes/routes.dart';
// import 'package:http/http.dart' as http;
// import 'package:signalr_core/signalr_core.dart';

// class SplashLogics {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final ApprovalService _approvalService = ApprovalService();

//   /// Initialize user after splash
//   // void initializeUser(BuildContext context) async {
//   //   final User? user = _auth.currentUser;

//   //   if (user == null) {
//   //     // No user → go to Register immediately
//   //     if (context.mounted) {
//   //       context.goNamed(Routes().register);
//   //     }
//   //     return;
//   //   }

//   //   // 🚀 Navigate immediately to a loading/placeholder screen
//   //   if (context.mounted) {
//   //     context.goNamed(Routes().navigationScreen);
//   //   }

//   //   // ⚡ Run heavy setup in background
//   //   _runBackgroundSetup(context, user);

//   //   //  checkAndNavigate(user.uid, context);
//   // }

//   void initializeUser(BuildContext context) async {
//     final User? user = _auth.currentUser;

//     if (user == null) {
//       // No user → go to Register immediately
//       if (context.mounted) {
//         context.goNamed(Routes().register);
//       }
//       return;
//     }

//     // ✅ Instead of navigating immediately, check connectivity first
//     final isConnected = await _checkNetwork();
//     if (!isConnected) {
//       if (context.mounted) {
//         ErrorNotification().showError(
//           context,
//           "No internet connection. Please reconnect and restart the app.",
//         );
//         return;
//       }
//     }

//     // ✅ Now safely run backend + approval logic
//     await _runBackgroundSetup(context, user);
//   }

//   Future<void> checkAndNavigate(String firebaseId, BuildContext context) async {
//     final status = await _approvalService.checkApprovalStatus(firebaseId);

//     if (status == "yes") {
//       // ✅ Navigate to HomeScreen if approved
//       if (!context.mounted) return;
//       //await initSignalR();
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (context) => const HomeScreen()),
//       );
//     } else {
//       // ❌ Show a message if not approved
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Your account is not yet approved.")),
//       );
//     }
//   }

//   // Future<void> initSignalR() async {
//   //   hubConnection =
//   //       HubConnectionBuilder()
//   //           .withUrl('$baseUrldoc/hubs/location')
//   //           .withAutomaticReconnect()
//   //           .build();

//   //   // 1️⃣ Listen for ride requests
//   //   hubConnection.on('NewRideRequest', (arguments) {
//   //     if (arguments != null && arguments.isNotEmpty) {
//   //       final rideData = arguments[0] as Map<String, dynamic>;
//   //       print("New ride request: ${rideData['rideId']}");
//   //       // Show ride overlay or alert
//   //       // _currentRide = rideData;
//   //       // _rideRemaining = 30;
//   //       // _startRideAlert(rideData);
//   //     }
//   //   });

//   //   // 2️⃣ Start the connection
//   //   await hubConnection.start();

//   //   // 3️⃣ Join driver group
//   //   await hubConnection.invoke('JoinDriverGroup');
//   // }

//   // Future<void> initSignalR() async {
//   //   hubConnection =
//   //       HubConnectionBuilder()
//   //           .withUrl('$baseUrldoc/hubs/location')
//   //           .withAutomaticReconnect()
//   //           .build();

//   //   // -------------------------
//   //   // 1️⃣ Listen for ride requests
//   //   // -------------------------
//   //   hubConnection.on('NewRideRequest', (arguments) {
//   //     if (arguments != null && arguments.isNotEmpty) {
//   //       final rideData = Map<String, dynamic>.from(arguments[0]);
//   //       print("New ride request: ${rideData['rideId']}");

//   //       // Ensure UI code runs on main thread
//   //       WidgetsBinding.instance.addPostFrameCallback((_) {
//   //         // _currentRide = rideData;
//   //         // _rideRemaining = 30;
//   //         // _startRideAlert(rideData);
//   //       });
//   //     }
//   //   });

//   //   // -------------------------
//   //   // 2️⃣ Start the connection
//   //   // -------------------------
//   //   await hubConnection.start();

//   //   // -------------------------
//   //   // 3️⃣ Join driver group
//   //   // -------------------------
//   //   await hubConnection.invoke('JoinDriverGroup');
//   // }

//   Future<void> _runBackgroundSetup(BuildContext context, User user) async {
//     try {
//       final firebaseUid = user.uid;

//       // Fetch tokens + user check in parallel
//       final tokenFuture = user.getIdToken();
//       final fcmTokenFuture = FirebaseMessaging.instance.getToken();
//       final userCheckFuture = http.get(
//         Uri.parse("$baseUrl/auth/check-user/$firebaseUid"),
//         headers: {HttpHeaders.contentTypeHeader: 'application/json'},
//       );

//       final results = await Future.wait([
//         tokenFuture,
//         fcmTokenFuture,
//         userCheckFuture,
//       ]);

//       final idToken = results[0] as String;
//       final fcmToken = results[1] as String?;
//       final response = results[2] as http.Response;

//       if (response.statusCode != 200) {
//         if (context.mounted) context.goNamed(Routes().register);
//         return;
//       }
//       //await initSignalR();
//       final userData = jsonDecode(response.body);

//       // ✅ Parse JSON off the main thread

//       // final userData =
//       //     await compute<Map<String, dynamic>>(_parseUserData, response.body);

//       // final userData = await compute<String, Map<String, dynamic>>(
//       //   _parseUserData,
//       //   response.body,
//       // );
//       //await initSignalR();
//       final phoneFromBackend = userData['phone'];
//       final int roleIndex = userData['role'] ?? 0;
//       final UserRole role = UserRole.values[roleIndex];
//       final isApproved = userData['isApproved'] ?? false;

//       final hasBackendData =
//           phoneFromBackend != null && phoneFromBackend.trim().isNotEmpty;

//       if (!hasBackendData) {
//         if (context.mounted) context.goNamed(Routes().profilesetupscreen);
//         return;
//       }

//       // Fire-and-forget FCM token update
//       unawaited(_updateFcmToken(idToken, fcmToken));

//       // Restore pending ride in background
//       final pendingRide = await getPendingRide();
//       if (pendingRide != null && context.mounted) {
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder:
//                 (_) => RideAlertScreen(
//                   rideId: pendingRide['rideId'] ?? '',
//                   rideRequestId: pendingRide['rideRequestId'] ?? '',
//                   rider: pendingRide['rider'] ?? '',
//                   pickupName: pendingRide['pickupName'] ?? '',
//                   destinationName: pendingRide['destinationName'] ?? '',
//                   pickupLat: _parseDouble(pendingRide['pickupLat']),
//                   pickupLng: _parseDouble(pendingRide['pickupLng']),
//                   destLat: _parseDouble(pendingRide['destLat']),
//                   destLng: _parseDouble(pendingRide['destLng']),
//                 ),
//           ),
//         );
//         return;
//       }

//       // ✅ Redirect once backend check is ready
//       if (isApproved) {
//         // await initSignalR();
//         if (context.mounted) context.goNamed(Routes().navigationScreen);
//       }
//       else
//        {
//         if (context.mounted) {
//           switch (role) {
//             case UserRole.driver:
//             case UserRole.owner:
//             case UserRole.driverOwner:
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (_) => DriverOnboardingScreen(role: role),
//                 ),
//               );
//               break;
//             case UserRole.passenger:
//             default:
//               context.goNamed(Routes().navigationScreen);
//               break;
//           }
//         }
//       }
//     } catch (e) {
//       if (context.mounted) {
//         ErrorNotification().showError(context, "Initialization failed: $e");
//       }
//     }
//   }

//   /// Parse JSON safely in isolate
//   static Map<String, dynamic> _parseUserData(String body) {
//     return jsonDecode(body) as Map<String, dynamic>;
//   }

//   double _parseDouble(dynamic value) {
//     if (value == null) return 0.0;
//     if (value is num) return value.toDouble();
//     if (value is String) return double.tryParse(value) ?? 0.0;
//     return 0.0;
//   }

//   Future<bool> _checkNetwork() async {
//     try {
//       final result = await InternetAddress.lookup(
//         'google.com',
//       ).timeout(const Duration(seconds: 5));
//       return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
//     } catch (_) {
//       return false;
//     }
//   }

//   Future<void> _updateFcmToken(String token, String? fcmToken) async {
//     if (fcmToken == null) return;
//     try {
//       await http.post(
//         Uri.parse('$baseUrl/auth/update-fcm-token'),
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $token',
//         },
//         body: jsonEncode({'token': token, 'fcmToken': fcmToken}),
//       );
//     } catch (e) {
//       debugPrint("FCM token update failed: $e");
//     }
//   }

//   void checkPermissions(BuildContext context) async {
//     try {
//       LocationPermission permission = await Geolocator.checkPermission();

//       if (permission == LocationPermission.denied) {
//         await Geolocator.requestPermission();
//         permission = await Geolocator.checkPermission();
//       }

//       if (permission == LocationPermission.deniedForever ||
//           permission == LocationPermission.unableToDetermine) {
//         if (context.mounted) {
//           ErrorNotification().showError(
//             context,
//             "Location access is required to run Amini driver.",
//           );
//           await Future.delayed(const Duration(seconds: 2));
//           SystemChannels.platform.invokeMethod(
//             "SystemNavigator.exitApplication",
//           );
//         }
//         return;
//       }

//       if (permission == LocationPermission.whileInUse ||
//           permission == LocationPermission.always) {
//         initializeUser(context);
//       }
//     } catch (e) {
//       if (context.mounted) {
//         ErrorNotification().showError(context, "An error occurred: $e");
//       }
//     }
//   }

//   Future<List<dynamic>?> checkDriverVehicles(String firebaseId) async {
//     try {
//       final response = await http.get(
//         Uri.parse("$baseUrl/driver-vehicles/by-driver/$firebaseId"),
//       );
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         if (data is Map && data.containsKey('vehicles')) {
//           return data['vehicles'] is List ? data['vehicles'] : [];
//         }
//         if (data is List) return data;
//       }
//       return [];
//     } catch (e) {
//       debugPrint("Error fetching driver vehicles: $e");
//       return null;
//     }
//   }
// }

// // import 'dart:convert';
// // import 'dart:async';
// // import 'dart:io';
// // import 'package:aminidriver/Container/utils/error_notification.dart';
// // import 'package:aminidriver/Container/utils/keys.dart';
// // import 'package:aminidriver/Container/utils/pending_ride_storage.dart';
// // import 'package:aminidriver/Onboarding/driveronboardingscreen.dart';
// // import 'package:aminidriver/Onboarding/ride_alert.dart';
// // import 'package:aminidriver/Onboarding/user_role.dart';
// // import 'package:aminidriver/View/Screens/Auth_Screens/Register_Screen/register_screen.dart';
// // import 'package:firebase_auth/firebase_auth.dart';
// // import 'package:firebase_messaging/firebase_messaging.dart';
// // import 'package:flutter/material.dart';
// // import 'package:flutter/services.dart';
// // import 'package:geolocator/geolocator.dart';
// // import 'package:go_router/go_router.dart';
// // import 'package:aminidriver/View/Routes/routes.dart';
// // import 'package:http/http.dart' as http;

// // class SplashLogics {
// //   final FirebaseAuth _auth = FirebaseAuth.instance;

// //   /// Initialize user after splash
// //   void initializeUser(BuildContext context) async {
// //     final User? user = _auth.currentUser;

// //     if (user == null) {
// //       // Delay 1 second for splash animation
// //       Future.delayed(const Duration(seconds: 1), () {
// //         if (context.mounted) {
// //           Navigator.push(
// //             context,
// //             MaterialPageRoute(builder: (_) => RegisterScreen()),
// //           );
// //         }
// //       });
// //       return;
// //     }

// //     final firebaseUid = user.uid;
// //     final tokenFuture = user.getIdToken(); // Firebase ID token
// //     final fcmTokenFuture = FirebaseMessaging.instance.getToken(); // FCM token

// //     // Fetch user data and tokens in parallel
// //     final userCheckFuture = http.get(
// //       Uri.parse("$baseUrl/auth/check-user/$firebaseUid"),
// //       headers: {HttpHeaders.contentTypeHeader: 'application/json'},
// //     );

// //     final results = await Future.wait([
// //       tokenFuture,
// //       fcmTokenFuture,
// //       userCheckFuture,
// //     ]);
// //     final idToken = results[0] as String;
// //     final fcmToken = results[1] as String?;
// //     final response = results[2] as http.Response;

// //     if (response.statusCode != 200) {
// //       if (context.mounted) context.goNamed(Routes().register);
// //       return;
// //     }

// //     final userData = jsonDecode(response.body);
// //     final phoneFromBackend = userData['phone'];
// //     final int roleIndex = userData['role'] ?? 0;
// //     final UserRole role = UserRole.values[roleIndex];
// //     final isApproved = userData['isApproved'] ?? false;

// //     final hasBackendData =
// //         phoneFromBackend != null && phoneFromBackend.trim().isNotEmpty;

// //     if (!hasBackendData) {
// //       if (context.mounted) context.goNamed(Routes().profilesetupscreen);
// //       return;
// //     }

// //     // Update FCM token asynchronously (don't block navigation)
// //     unawaited(_updateFcmToken(idToken, fcmToken));

// //     final pendingRide = await getPendingRide();

// //     // Navigate after 1 frame to let splash render
// //     WidgetsBinding.instance.addPostFrameCallback((_) {
// //       if (!context.mounted) return;

// //       if (pendingRide != null) {
// //         Navigator.push(
// //           context,
// //           MaterialPageRoute(
// //             builder:
// //                 (_) => RideAlertScreen(
// //                   rideId: pendingRide['rideId'] ?? '',
// //                   rideRequestId: pendingRide['rideRequestId'] ?? '',
// //                   rider: pendingRide['rider'] ?? '',
// //                   pickupName: pendingRide['pickupName'] ?? '',
// //                   destinationName: pendingRide['destinationName'] ?? '',
// //                   pickupLat: _parseDouble(pendingRide['pickupLat']),
// //                   pickupLng: _parseDouble(pendingRide['pickupLng']),
// //                   destLat: _parseDouble(pendingRide['destLat']),
// //                   destLng: _parseDouble(pendingRide['destLng']),
// //                 ),
// //           ),
// //         );
// //         return;
// //       }

// //       if (isApproved) {
// //         context.goNamed(Routes().navigationScreen);
// //       } else {
// //         switch (role) {
// //           case UserRole.driver:
// //           case UserRole.owner:
// //           case UserRole.driverOwner:
// //             Navigator.push(
// //               context,
// //               MaterialPageRoute(
// //                 builder: (_) => DriverOnboardingScreen(role: role),
// //               ),
// //             );
// //             break;
// //           case UserRole.passenger:
// //           default:
// //             context.goNamed(Routes().navigationScreen);
// //             break;
// //         }
// //       }
// //     });
// //   }

// //   /// Helper: parse dynamic to double safely
// //   double _parseDouble(dynamic value) {
// //     if (value == null) return 0.0;
// //     if (value is num) return value.toDouble();
// //     if (value is String) return double.tryParse(value) ?? 0.0;
// //     return 0.0;
// //   }

// //   /// Asynchronous FCM token update (don't block splash)
// //   Future<void> _updateFcmToken(String token, String? fcmToken) async {
// //     if (fcmToken == null) return;
// //     try {
// //       await http.post(
// //         Uri.parse('$baseUrl/auth/update-fcm-token'),
// //         headers: {
// //           'Content-Type': 'application/json',
// //           'Authorization': 'Bearer $token',
// //         },
// //         body: jsonEncode({'token': token, 'fcmToken': fcmToken}),
// //       );
// //     } catch (e) {
// //       print("FCM token update failed: $e");
// //     }
// //   }

// //   /// Check permissions before initializing user
// //   void checkPermissions(BuildContext context) async {
// //     try {
// //       LocationPermission permission = await Geolocator.checkPermission();

// //       if (permission == LocationPermission.denied) {
// //         await Geolocator.requestPermission();
// //         permission = await Geolocator.checkPermission();
// //       }

// //       if (permission == LocationPermission.deniedForever ||
// //           permission == LocationPermission.unableToDetermine) {
// //         if (context.mounted) {
// //           ErrorNotification().showError(
// //             context,
// //             "Location access is required to run Amini driver.",
// //           );
// //           await Future.delayed(const Duration(seconds: 2));
// //           SystemChannels.platform.invokeMethod(
// //             "SystemNavigator.exitApplication",
// //           );
// //         }
// //         return;
// //       }

// //       if (permission == LocationPermission.whileInUse ||
// //           permission == LocationPermission.always) {
// //         initializeUser(context);
// //       }
// //     } catch (e) {
// //       if (context.mounted) {
// //         ErrorNotification().showError(context, "An error occurred: $e");
// //       }
// //     }
// //   }

// //   /// Check driver vehicles
// //   Future<List<dynamic>?> checkDriverVehicles(String firebaseId) async {
// //     try {
// //       final response = await http.get(
// //         Uri.parse("$baseUrl/driver-vehicles/by-driver/$firebaseId"),
// //       );
// //       if (response.statusCode == 200) {
// //         final data = jsonDecode(response.body);
// //         if (data is Map && data.containsKey('vehicles')) {
// //           return data['vehicles'] is List ? data['vehicles'] : [];
// //         }
// //         if (data is List) return data;
// //       }
// //       return [];
// //     } catch (e) {
// //       print("Error fetching driver vehicles: $e");
// //       return null;
// //     }
// //   }
// // }
// // // import 'dart:convert';
// // // import 'dart:async';
// // // import 'dart:io';
// // // import 'package:aminidriver/Container/utils/error_notification.dart';
// // // import 'package:aminidriver/Container/utils/keys.dart';
// // // import 'package:aminidriver/Container/utils/pending_ride_storage.dart';
// // // import 'package:aminidriver/Onboarding/driveronboardingscreen.dart';
// // // import 'package:aminidriver/Onboarding/ride_alert.dart';
// // // import 'package:aminidriver/Onboarding/user_role.dart';
// // // import 'package:aminidriver/Onboarding/vehicleonboardingscreen.dart';
// // // import 'package:aminidriver/View/Screens/Auth_Screens/Register_Screen/register_screen.dart';
// // // import 'package:aminidriver/View/Screens/Nav_Screens/navigation_screen.dart';
// // // import 'package:firebase_auth/firebase_auth.dart';
// // // import 'package:firebase_database/firebase_database.dart';
// // // import 'package:firebase_messaging/firebase_messaging.dart';
// // // import 'package:flutter/material.dart';
// // // import 'package:flutter/services.dart';
// // // import 'package:geolocator/geolocator.dart';
// // // import 'package:go_router/go_router.dart';
// // // import 'package:aminidriver/View/Routes/routes.dart';
// // // import 'package:aminidriver/Container/utils/api_constant.dart';
// // // import 'package:http/http.dart' as http;
// // // import 'package:latlong2/latlong.dart';

// // // class SplashLogics {
// // //   final FirebaseAuth _auth = FirebaseAuth.instance;

// // //   void initializeUser(BuildContext context) async {
// // //     final User? user = _auth.currentUser;

// // //     if (user == null) {
// // //       Timer(const Duration(seconds: 1), () {
// // //         Navigator.push(
// // //           context,
// // //           MaterialPageRoute(builder: (_) => RegisterScreen()),
// // //         );
// // //         //context.goNamed(Routes().register);
// // //       });
// // //       return;
// // //     }

// // //     double parseToDouble(dynamic value) {
// // //       if (value == null) return 0.0;
// // //       if (value is num) return value.toDouble();
// // //       if (value is String) return double.tryParse(value) ?? 0.0;
// // //       return 0.0;
// // //     }

// // //     final String firebaseUid = user.uid;
// // //     bool hasBackendData = false;
// // //     bool hasFirestoreData = false;
// // //     final uid = user.uid;
// // //     final phone = user.phoneNumber ?? '';
// // //     final email = user.email ?? '';
// // //     final token = await user.getIdToken();
// // //     final fcmToken = await FirebaseMessaging.instance.getToken();

// // //     try {
// // //       final String? idToken = await user.getIdToken();

// // //       final response = await http.get(
// // //         Uri.parse("$baseUrl/auth/check-user/$firebaseUid"),
// // //         headers: {
// // //           //   HttpHeaders.authorizationHeader: 'Bearer $idToken',
// // //           HttpHeaders.contentTypeHeader: 'application/json',
// // //         },
// // //       );
// // //       String? phoneFromBackend;
// // //       if (response.statusCode == 200) {
// // //         final userData = jsonDecode(response.body);
// // //         phoneFromBackend = userData['phone'];
// // //         //final UserRole role = userData['role'];
// // //         final int roleIndex = userData['role'] ?? 0;
// // //         final UserRole role = UserRole.values[roleIndex];
// // //         hasBackendData =
// // //             phoneFromBackend != null && phoneFromBackend.trim().isNotEmpty;

// // //         if (hasBackendData) {
// // //           final bool isApproved = userData['isApproved'] ?? false;
// // //           final response = await http.post(
// // //             Uri.parse('$baseUrl/auth/update-fcm-token'),
// // //             headers: {
// // //               'Content-Type': 'application/json',
// // //               'Authorization': 'Bearer $token',
// // //             },
// // //             body: jsonEncode({
// // //               'token': token, // Firebase ID token
// // //               'fcmToken': fcmToken, // Device's FCM token
// // //             }),
// // //           );
// // //           if (response.statusCode == 200) {
// // //             if (isApproved) {
// // //               final pendingRide = await getPendingRide();
// // //               Future.delayed(const Duration(seconds: 3), () {
// // //                 if (!context.mounted) return;

// // //                 if (pendingRide != null) {
// // //                   Navigator.push(
// // //                     context,
// // //                     MaterialPageRoute(
// // //                       builder:
// // //                           (_) => RideAlertScreen(
// // //                             rideId: pendingRide['rideId'] ?? '',
// // //                             rider: pendingRide['rider'] ?? '',
// // //                             pickupName: pendingRide['pickupName'] ?? '',
// // //                             destinationName:
// // //                                 pendingRide['destinationName'] ?? '',

// // //                             // pickupLat:
// // //                             //     (pendingRide['pickupLat'] as num?)
// // //                             //         ?.toDouble() ??
// // //                             //     0.0,
// // //                             // pickupLng:
// // //                             //     (pendingRide['pickupLng'] as num?)
// // //                             //         ?.toDouble() ??
// // //                             //     0.0,
// // //                             // destLat:
// // //                             //     (pendingRide['destLat'] as num?)?.toDouble() ??
// // //                             //     0.0,
// // //                             // destLng:
// // //                             //     (pendingRide['destLng'] as num?)?.toDouble() ??
// // //                             //     0.0,
// // //                             pickupLat: parseToDouble(pendingRide['pickupLat']),
// // //                             pickupLng: parseToDouble(pendingRide['pickupLng']),
// // //                             destLat: parseToDouble(pendingRide['destLat']),
// // //                             destLng: parseToDouble(pendingRide['destLng']),
// // //                           ),
// // //                     ),
// // //                   );
// // //                   return; // stop further navigation
// // //                 }
// // //                 context.goNamed(Routes().navigationScreen);
// // //               });
// // //               //context.goNamed(Routes().navigationScreen);
// // //               return;
// // //             } else {
// // //               if (role == UserRole.passenger) {
// // //                 // do something
// // //                 return;
// // //               }
// // //               final pendingRide = await getPendingRide();
// // //               switch (role) {
// // //                 case UserRole.driver:
// // //                   Navigator.push(
// // //                     context,
// // //                     MaterialPageRoute(
// // //                       builder:
// // //                           (_) => DriverOnboardingScreen(role: UserRole.driver),
// // //                     ),
// // //                   );
// // //                   break;

// // //                 case UserRole.owner:
// // //                   Navigator.push(
// // //                     context,
// // //                     MaterialPageRoute(
// // //                       builder:
// // //                           (_) => DriverOnboardingScreen(role: UserRole.owner),
// // //                     ),
// // //                   );
// // //                   break;
// // //                 case UserRole.driverOwner:
// // //                   Navigator.push(
// // //                     context,
// // //                     MaterialPageRoute(
// // //                       builder:
// // //                           (_) => DriverOnboardingScreen(
// // //                             role: UserRole.driverOwner,
// // //                           ),
// // //                     ),
// // //                   );
// // //                   break;

// // //                 case UserRole.passenger:
// // //                 default:
// // //                   if (pendingRide != null) {
// // //                     context.goNamed(Routes().ridealert);
// // //                     return; // stop further navigation
// // //                   }
// // //                   context.goNamed(Routes().navigationScreen);
// // //                   break;
// // //               }
// // //             }
// // //             // context.goNamed(Routes().home);
// // //           } else {
// // //             final pendingRide = await getPendingRide();
// // //             Future.delayed(const Duration(seconds: 3), () {
// // //               if (!context.mounted) return;
// // //               if (pendingRide != null) {
// // //                 context.goNamed(Routes().ridealert);
// // //                 return; // stop further navigation
// // //               }
// // //               context.goNamed(Routes().navigationScreen);
// // //             });
// // //             //debugPrint("Failed to validate token, contact amini support");
// // //           }
// // //         } else {
// // //           context.goNamed(Routes().profilesetupscreen);
// // //           //  debugPrint("Failed to validate user, contact amini support");
// // //         }
// // //       } else {
// // //         context.goNamed(Routes().register);
// // //       }
// // //     } catch (e) {
// // //       debugPrint("Backend or Firestore check failed: $e");
// // //       // Optionally: navigate to error screen or retry
// // //     }
// // //   }

// // //   Future<List<dynamic>?> checkDriverVehicles(String firebaseId) async {
// // //     try {
// // //       final response = await http.get(
// // //         Uri.parse("$baseUrl/driver-vehicles/by-driver/$firebaseId"),
// // //       );

// // //       if (response.statusCode == 200) {
// // //         final data = jsonDecode(response.body);

// // //         // If it's a map containing 'vehicles' key
// // //         if (data is Map && data.containsKey('vehicles')) {
// // //           return data['vehicles'] is List ? data['vehicles'] : [];
// // //         }

// // //         // If it's directly a list
// // //         if (data is List) {
// // //           return data;
// // //         }

// // //         return [];
// // //       } else {
// // //         print("API returned status: ${response.statusCode}");
// // //         return null;
// // //       }
// // //     } catch (e) {
// // //       print("Error fetching driver vehicles: $e");
// // //       return null;
// // //     }
// // //   }

// // //   // Future<bool> checkIfUserHasVehicle(String driverId) async {
// // //   //   try {
// // //   //     final response = await http.get(
// // //   //       Uri.parse(
// // //   //         "http://192.168.27.145:7047/api/driver-vehicles/by-driver/$driverId",
// // //   //       ),
// // //   //     );

// // //   //     if (response.statusCode == 200) {
// // //   //       final data = jsonDecode(response.body);

// // //   //       // Option 1: If your API returns a map with a `vehicles` array
// // //   //       if (data is Map && data.containsKey('vehicles')) {
// // //   //         return data['vehicles'] is List && data['vehicles'].isNotEmpty;
// // //   //       }

// // //   //       // Option 2: If your API returns a list directly (no wrapping map)
// // //   //       if (data is List) {
// // //   //         return data.isNotEmpty;
// // //   //       }

// // //   //       return false;
// // //   //     } else {
// // //   //       print("Non-200 from API: ${response.statusCode}");
// // //   //       return false;
// // //   //     }
// // //   //   } catch (e) {
// // //   //     print("Error checking vehicle: $e");
// // //   //     return false;
// // //   //   }
// // //   // }

// // //   // Future<bool> checkIfUserHasVehicle(String driverId) async {
// // //   //   try {
// // //   //     final response = await http.get(
// // //   //       Uri.parse(
// // //   //         "http://192.168.27.145:7047/api/driver-vehicles/by-driver/$driverId",
// // //   //       ),
// // //   //     );
// // //   //     if (response.statusCode == 200) {
// // //   //       final data = jsonDecode(response.body);
// // //   //       return data is List && data.isNotEmpty;
// // //   //     } else {
// // //   //       return false;
// // //   //     }
// // //   //   } catch (e) {
// // //   //     print("Error checking vehicle: $e");
// // //   //     return false;
// // //   //   }
// // //   // }

// // //   /// [checkPermissions] checking the permission status

// // //   void checkPermissions(BuildContext context) async {
// // //     try {
// // //       LocationPermission permission = await Geolocator.checkPermission();

// // //       if (permission == LocationPermission.denied) {
// // //         await Geolocator.requestPermission();
// // //         LocationPermission permission2 = await Geolocator.checkPermission();
// // //         if (context.mounted &&
// // //             (permission2 == LocationPermission.whileInUse ||
// // //                 permission2 == LocationPermission.always)) {
// // //           initializeUser(context);
// // //         } else {
// // //           if (context.mounted) {
// // //             ErrorNotification().showError(
// // //               context,
// // //               "Location Access is required to run Trippo.",
// // //             );
// // //           }

// // //           await Future.delayed(const Duration(seconds: 2));
// // //           SystemChannels.platform.invokeMethod(
// // //             "SystemNavigator.exitApplication",
// // //           );
// // //         }
// // //         return;
// // //       } else if (context.mounted &&
// // //           (permission == LocationPermission.whileInUse ||
// // //               permission == LocationPermission.always)) {
// // //         initializeUser(context);
// // //         return;
// // //       }
// // //       if (permission == LocationPermission.deniedForever ||
// // //           permission == LocationPermission.unableToDetermine) {
// // //         if (context.mounted) {
// // //           ErrorNotification().showError(
// // //             context,
// // //             "Location Access is required to run Amini driver.",
// // //           );
// // //           await Future.delayed(const Duration(seconds: 2));
// // //           SystemChannels.platform.invokeMethod(
// // //             "SystemNavigator.exitApplication",
// // //           );
// // //         }
// // //         return;
// // //       }
// // //     } catch (e) {
// // //       if (context.mounted) {
// // //         ErrorNotification().showError(context, "An Error Occurred $e");
// // //       }
// // //     }
// // //   }
// // // }
