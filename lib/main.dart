import 'dart:async';
import 'package:aminidriver/Container/utils/pending_ride_storage.dart';
import 'package:aminidriver/Onboarding/driver_location_live.dart';
import 'package:aminidriver/View/Routes/app_routes.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'package:go_router/go_router.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("🔙 Handling background message: ${message.messageId}");

  // Save ride for recovery
  if (message.data.containsKey('rideId')) {
    await savePendingRide(message.data, 300); // store for 5 minutes
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  setupFCM();
  DriverLocationService().startSendingLocation();

  // 🔑 Check if there is a pending ride saved locally
  final ride = await getPendingRide();

  runApp(ProviderScope(child: MyApp(pendingRide: ride)));
}

void setupFCM() {
  // 🚀 When user taps a notification while app is in background
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
    if (message.data.containsKey('rideId')) {
      await savePendingRide(message.data, 300);
      _openRideScreen(message.data);
    }
    // else {
    //   _openMessagesScreen();
    // }
  });

  // 🚀 When app was terminated and opened via a notification (cold start)
  FirebaseMessaging.instance.getInitialMessage().then((message) async {
    if (message != null && message.data.containsKey('rideId')) {
      await savePendingRide(message.data, 300);
      _openRideScreen(message.data);
    }
  });

  // 🚀 Foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    if (message.data.containsKey('rideId')) {
      await savePendingRide(message.data, 300);
      _openRideScreen(message.data);
    }
  });
}

void _openRideScreen(Map<String, dynamic> data) {
  final context = navigatorKey.currentContext;
  if (context == null) return;

  context.push('/ride-alert', extra: data);
}

// void _openMessagesScreen() {
//   final context = navigatorKey.currentContext;
//   if (context == null) return;
// context.push('/ride-alert', extra: data);
//  // context.push('/messages'); // 🔑 Make sure you have a /messages route defined
// }

class MyApp extends ConsumerWidget {
  final Map<String, dynamic>? pendingRide;

  const MyApp({super.key, this.pendingRide});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'amini driver',
      routerConfig: router,
    );
  }
}

// import 'dart:async';
// import 'package:aminidriver/Container/utils/pending_ride_storage.dart';
// import 'package:aminidriver/Onboarding/driver_location_live.dart';
// import 'package:aminidriver/Onboarding/ride_alert.dart';
// import 'package:aminidriver/View/Routes/app_routes.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'firebase_options.dart';
// import 'package:go_router/go_router.dart';

// final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// /// Background message handler
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
//   print("🔙 Handling background message: ${message.messageId}");

//   // Save ride for recovery
//   if (message.data.containsKey('rideId')) {
//     await savePendingRide(message.data, 300); // store for 5 minutes
//   }
// }

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

//   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

//   setupFCM();
//   DriverLocationService().startSendingLocation();

//   // 🔑 Check if there is a pending ride saved locally
//   final ride = await getPendingRide();

//   runApp(ProviderScope(child: MyApp(pendingRide: ride)));
// }

// // void setupFCM() {

// //   FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
// //     if (message.data.containsKey('rideId')) {
// //       await savePendingRide(message.data, 300);
// //       _openRideScreen(message.data);
// //     }
// //   });

// //   FirebaseMessaging.instance.getInitialMessage().then((message) async {
// //     if (message != null && message.data.containsKey('rideId')) {
// //       await savePendingRide(message.data, 300);
// //       _openRideScreen(message.data);
// //     }
// //   });

// //   FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
// //     if (message.data.containsKey('rideId')) {
// //       await savePendingRide(message.data, 300);
// //       _openRideScreen(message.data);
// //     }
// //   });
// // }

// // void _openRideScreen(Map<String, dynamic> data) {
// //   final context = navigatorKey.currentContext;
// //   if (context == null) return;

// //   context.push(
// //     '/ride-alert',
// //     extra: data, // pass ride data if your route expects it
// //   );
// // }
// void setupFCM() {
//   // 🚀 When user taps a notification while app is in background
//   FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
//     if (message.data.containsKey('rideId')) {
//       await savePendingRide(message.data, 300);
//       _openRideScreen(message.data);
//     } else {
//       // fallback → maybe go to messages screen
//       navigatorKey.currentState?.push(
//         MaterialPageRoute(builder: (_) => RideAlertScreen()),
//       );
//     }
//   });

//   // 🚀 When app was terminated and opened via a notification (cold start)
//   FirebaseMessaging.instance.getInitialMessage().then((message) async {
//     if (message != null && message.data.containsKey('rideId')) {
//       await savePendingRide(message.data, 300);
//       _openRideScreen(message.data);
//     }
//   });

//   // 🚀 Foreground messages
//   FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
//     if (message.data.containsKey('rideId')) {
//       await savePendingRide(message.data, 300);
//       _openRideScreen(message.data);
//     }
//   });
// }

// void _openRideScreen(Map<String, dynamic> data) {
//   final context = navigatorKey.currentContext;
//   if (context == null) return;

//   // If the notification is ride type → go to RideAlertScreen
//   if (data['type'] == 'ride') {
//     context.push('/ride-alert', extra: data);
//   } else {
//     // Otherwise → go to messages screen
//     navigatorKey.currentState?.push(
//       MaterialPageRoute(builder: (_) => RideAlertScreen()),
//     );
//   }
// }

// class MyApp extends ConsumerWidget {
//   final Map<String, dynamic>? pendingRide;

//   const MyApp({super.key, this.pendingRide});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     return MaterialApp.router(
//       debugShowCheckedModeBanner: false,
//       title: 'amini driver',
//       routerConfig: router,
//     );
//   }
// }

// // Future<void> checkPendingRide(BuildContext context) async {
// //   final pending = await getPendingRide();
// //   if (pending != null) {
// //     Navigator.push(
// //       context,
// //       PageRouteBuilder(
// //         opaque: false,
// //         pageBuilder:
// //             (_, __, ___) => RideAlertScreen(
// //               rideId: pending['rideId'],
// //               rider: pending['rider'],
// //               pickupName: pending['pickupName'],
// //               destinationName: pending['destinationName'],
// //               pickupLat: (pending['pickupLat'] as num?)?.toDouble() ?? 0.0,
// //               pickupLng: (pending['pickupLng'] as num?)?.toDouble() ?? 0.0,
// //               destLat: (pending['destLat'] as num?)?.toDouble() ?? 0.0,
// //               destLng: (pending['destLng'] as num?)?.toDouble() ?? 0.0,
// //             ),
// //       ),
// //     );
// //   }
// // }

// // import 'dart:async';
// // import 'package:aminidriver/Container/utils/pending_ride_storage.dart';
// // import 'package:aminidriver/Onboarding/driver_location_live.dart';
// // import 'package:aminidriver/Onboarding/ride_alert.dart';
// // import 'package:aminidriver/View/Routes/app_routes.dart';
// // import 'package:firebase_core/firebase_core.dart';
// // import 'package:firebase_messaging/firebase_messaging.dart';
// // import 'package:flutter/material.dart';
// // import 'package:flutter_riverpod/flutter_riverpod.dart';
// // import 'firebase_options.dart';

// // final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// // /// Background message handler
// // Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
// //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
// //   print("🔙 Handling background message: ${message.messageId}");
// // }

// // Future<void> main() async {
// //   WidgetsFlutterBinding.ensureInitialized();
// //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

// //   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

// //   setupFCM();
// //   DriverLocationService().startSendingLocation();

// //   // 🔑 Check if there is a pending ride saved locally
// //   final ride = await getPendingRide();

// //   runApp(ProviderScope(child: MyApp(pendingRide: ride)));
// // }

// // void setupFCM() {
// //   FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
// //     _openRideScreen(message.data);
// //   });

// //   FirebaseMessaging.instance.getInitialMessage().then((message) {
// //     if (message != null) _openRideScreen(message.data);
// //   });
// // }

// // void _openRideScreen(Map<String, dynamic> data) {
// //   if (data.containsKey('rideId')) {
// //     navigatorKey.currentState?.push(
// //       MaterialPageRoute(
// //         builder:
// //             (context) => RideAlertScreen(
// //               rideId: data['rideId'],
// //               rider: data['rider'] ?? '',
// //               pickupName: data['pickupName'] ?? '',
// //               destinationName: data['destinationName'] ?? '',
// //               pickupLat: double.tryParse(data['pickupLat'] ?? '') ?? 0.0,
// //               pickupLng: double.tryParse(data['pickupLng'] ?? '') ?? 0.0,
// //               destLat: double.tryParse(data['destLat'] ?? '') ?? 0.0,
// //               destLng: double.tryParse(data['destLng'] ?? '') ?? 0.0,
// //             ),
// //       ),
// //     );
// //   }
// // }
// // Future<void> checkPendingRide(BuildContext context) async {
// //   final pending = await getPendingRide();
// //   if (pending != null) {
// //     Navigator.push(
// //       context,
// //       PageRouteBuilder(
// //         opaque: false,
// //         pageBuilder: (_, __, ___) => RideAlertScreen(
// //           rideId: pending['rideId'],
// //           rider: pending['rider'],
// //           pickupName: pending['pickupName'],
// //           destinationName: pending['destinationName'],
// //           pickupLat: pending['pickupLat'],
// //           pickupLng: pending['pickupLng'],
// //           destLat: pending['destLat'],
// //           destLng: pending['destLng'],
// //         ),
// //       ),
// //     );
// //   }
// // }

// // class MyApp extends ConsumerWidget {
// //   final Map<String, dynamic>? pendingRide;

// //   const MyApp({super.key, this.pendingRide});

// //   @override
// //   Widget build(BuildContext context, WidgetRef ref) {
// //     return MaterialApp.router(
// //       debugShowCheckedModeBanner: false,
// //       title: 'amini driver',
// //       routerConfig: router, //use your router here
// //       builder: (context, child) {
// //         if (pendingRide != null) {
// //           return RideAlertScreen(
// //             rideId: pendingRide!['rideId'],
// //             rider: pendingRide!['rider'] ?? '',
// //             pickupName: pendingRide!['pickupName'] ?? '',
// //             destinationName: pendingRide!['destinationName'] ?? '',
// //             pickupLat: (pendingRide!['pickupLat'] as num?)?.toDouble() ?? 0.0,
// //             pickupLng: (pendingRide!['pickupLng'] as num?)?.toDouble() ?? 0.0,
// //             destLat: (pendingRide!['destLat'] as num?)?.toDouble() ?? 0.0,
// //             destLng: (pendingRide!['destLng'] as num?)?.toDouble() ?? 0.0,
// //           );
// //         }
// //         return child!;
// //       },
// //       //routerConfig: router,
// //     );
// //   }
// // }
// // // class MyApp extends ConsumerWidget {
// // //   final Map<String, dynamic>? pendingRide;

// // //   const MyApp({super.key, this.pendingRide});
// // //   //const MyApp({super.key});

// // //   @override
// // //   Widget build(BuildContext context, WidgetRef ref) {
// // //     return MaterialApp.router(
// // //       debugShowCheckedModeBanner: false,
// // //       title: 'amini driver',
// // //       routerConfig: router,
// // //     );
// // //   }
// // // }
// // // // class MyApp extends ConsumerWidget {
// // //   final Map<String, dynamic>? pendingRide;

// // //   const MyApp({super.key, this.pendingRide});

// // //   @override
// // //   Widget build(BuildContext context, WidgetRef ref) {
// // //     return MaterialApp(
// // //       debugShowCheckedModeBanner: false,
// // //       title: 'amini driver',
// // //       navigatorKey: navigatorKey, // ✅ Works with MaterialApp
// // //       onGenerateRoute: router.con, // ✅ connect your router
// // //       builder: (context, child) {
// // //         // 🔑 If there’s a saved pending ride, show RideAlertScreen first
// // //         if (pendingRide != null) {
// // //           return RideAlertScreen(
// // //             rideId: pendingRide!['rideId'],
// // //             rider: pendingRide!['rider'] ?? '',
// // //             pickupName: pendingRide!['pickupName'] ?? '',
// // //             destinationName: pendingRide!['destinationName'] ?? '',
// // //             pickupLat: (pendingRide!['pickupLat'] as num?)?.toDouble() ?? 0.0,
// // //             pickupLng: (pendingRide!['pickupLng'] as num?)?.toDouble() ?? 0.0,
// // //             destLat: (pendingRide!['destLat'] as num?)?.toDouble() ?? 0.0,
// // //             destLng: (pendingRide!['destLng'] as num?)?.toDouble() ?? 0.0,
// // //           );
// // //         }
// // //         return child!;
// // //       },
// // //     );
// // //   }
// // // }

// // // import 'dart:async';
// // // import 'dart:convert';
// // // import 'package:aminidriver/Container/utils/api_constant.dart';
// // // import 'package:aminidriver/Container/utils/pending_ride_storage.dart';
// // // import 'package:aminidriver/Onboarding/driver_location_live.dart';
// // // import 'package:aminidriver/Onboarding/ride_alert.dart';
// // // import 'package:aminidriver/Onboarding/trip_detail_screen.dart';
// // // import 'package:aminidriver/View/Routes/app_routes.dart';
// // // import 'package:firebase_auth/firebase_auth.dart';
// // // import 'package:firebase_core/firebase_core.dart';
// // // import 'package:firebase_messaging/firebase_messaging.dart';
// // // import 'package:flutter/material.dart';
// // // import 'package:flutter_riverpod/flutter_riverpod.dart';
// // // import 'package:geolocator/geolocator.dart';
// // // import 'package:http/http.dart' as http;
// // // import 'firebase_options.dart';

// // // final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// // // /// Background message handler
// // // Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
// // //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
// // //   print("🔙 Handling background message: ${message.messageId}");
// // // }

// // // void main() async {
// // //   WidgetsFlutterBinding.ensureInitialized();
// // //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

// // //   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

// // //   setupFCM();
// // //   DriverLocationService().startSendingLocation();
// // //   final ride = await getPendingRide();
// // //   runApp(const ProviderScope(child: MyApp())); // <-- MyApp constructor
// // // }

// // // void setupFCM() {
// // //   FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
// // //     _openRideScreen(message);
// // //   });

// // //   FirebaseMessaging.instance.getInitialMessage().then((message) {
// // //     if (message != null) _openRideScreen(message);
// // //   });
// // // }

// // // void _openRideScreen(RemoteMessage message) {
// // //   final data = message.data;

// // //   if (data.containsKey('rideId')) {
// // //     navigatorKey.currentState?.push(
// // //       MaterialPageRoute(
// // //         builder:
// // //             (context) => RideAlertScreen(
// // //               rideId: data['rideId'],
// // //               rider: data['rider'] ?? '',
// // //               pickupName: data['pickupName'] ?? '',
// // //               destinationName: data['destinationName'] ?? '',
// // //               pickupLat: double.tryParse(data['pickupLat'] ?? '') ?? 0.0,
// // //               pickupLng: double.tryParse(data['pickupLng'] ?? '') ?? 0.0,
// // //               destLat: double.tryParse(data['destLat'] ?? '') ?? 0.0,
// // //               destLng: double.tryParse(data['destLng'] ?? '') ?? 0.0,
// // //             ),
// // //       ),
// // //     );
// // //   }
// // // }

// // // class MyApp extends ConsumerWidget {
// // //   const MyApp({super.key});

// // //   @override
// // //   Widget build(BuildContext context, WidgetRef ref) {
// // //     return MaterialApp.router(
// // //       debugShowCheckedModeBanner: false,
// // //       title: 'amini driver',
// // //       routerConfig: router,
// // //     );
// // //   }
// // // }

// // // /// MyApp definition
// // // // class MyApp extends ConsumerWidget {
// // // //   const MyApp({super.key});

// // // //   @override
// // // //   Widget build(BuildContext context, WidgetRef ref) {
// // // //     return MaterialApp(
// // // //       title: 'Amini Driver',
// // // //       debugShowCheckedModeBanner: false,
// // // //       navigatorKey: navigatorKey,
// // // //     //  theme: ThemeData(primarySwatch: Colors.green),
// // // //       home: const Scaffold(
// // // //         body: Center(child: Text("Welcome to Amini Driver")),
// // // //       ),
// // // //     );
// // // //   }
// // // // }

// // // // import 'package:aminidriver/Onboarding/driver_location_live.dart';
// // // // import 'package:firebase_core/firebase_core.dart';
// // // // import 'package:firebase_messaging/firebase_messaging.dart';
// // // // import 'package:flutter/material.dart';
// // // // import 'package:flutter_riverpod/flutter_riverpod.dart';
// // // // import 'View/Routes/app_routes.dart';
// // // // import 'firebase_options.dart';

// // // // /// Background message handler
// // // // Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
// // // //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
// // // //   print("🔙 Handling background message: ${message.messageId}");
// // // // }

// // // // Future<void> main() async {
// // // //   WidgetsFlutterBinding.ensureInitialized();
// // // //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

// // // //   // Register background message handler
// // // //   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

// // // //   //FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

// // // //   RemoteMessage? initialMessage =
// // // //       await FirebaseMessaging.instance.getInitialMessage();
// // // //   handleInitialMessage(initialMessage);
// // // //   DriverLocationService().startSendingLocation();
// // // //   runApp(const ProviderScope(child: MyApp()));
// // // // }

// // // // class MyApp extends ConsumerWidget {
// // // //   const MyApp({super.key});

// // // //   @override
// // // //   Widget build(BuildContext context, WidgetRef ref) {
// // // //     return MaterialApp.router(
// // // //       debugShowCheckedModeBanner: false,
// // // //       title: 'amini driver',
// // // //       routerConfig: router,
// // // //     );
// // // //   }
// // // // }

// // // // RemoteMessage? initialRideMessage;

// // // // void firebaseMessagingBackgroundHandler(RemoteMessage message) async {
// // // //   // Handle background message
// // // // }
// // // // void handleInitialMessage(RemoteMessage? message) {
// // // //   if (message != null && message.data.containsKey('rideId')) {
// // // //     initialRideMessage = message;
// // // //   }
// // // // }
// // // // //import 'package:aminidriver/Container/utils/firebase_messaging.dart';
// // // // // import 'package:aminidriver/Container/utils/message_service.dart';
// // // // // import 'package:firebase_messaging/firebase_messaging.dart';
// // // // // import 'package:flutter/material.dart';
// // // // // import 'package:flutter_riverpod/flutter_riverpod.dart';
// // // // // import 'View/Routes/app_routes.dart';
// // // // // import 'package:firebase_core/firebase_core.dart';
// // // // // import 'firebase_options.dart';

// // // // // //final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// // // // // Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
// // // // //   await Firebase.initializeApp();
// // // // //   print("🔙 Handling background message: ${message.messageId}");
// // // // // }

// // // // // Future<void> main() async {
// // // // //   WidgetsFlutterBinding.ensureInitialized();
// // // // //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
// // // // //   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

// // // // //   final messagingService = MessagingService();
// // // // //   await messagingService.init();
// // // // //   runApp(const ProviderScope(child: MyApp()));
// // // // // }

// // // // // class MyApp extends StatelessWidget {
// // // // //   const MyApp({super.key});

// // // // //   @override
// // // // //   Widget build(BuildContext context) {
// // // // //     return MaterialApp.router(
// // // // //       debugShowCheckedModeBanner: false,
// // // // //       title: 'aminidriver',
// // // // //       routerConfig: router,
// // // // //       //navigatorKey: navigatorKey,
// // // // //     );
// // // // //   }
// // // // // }

// // // // // //import 'package:aminidriver/View/Screens/Auth_Screens/Register_Screen/vehicle_registration_screen';
// // // // // import 'package:aminidriver/Container/utils/firebase_messaging.dart';
// // // // // import 'package:flutter/material.dart';
// // // // // import 'package:flutter_riverpod/flutter_riverpod.dart';
// // // // // import 'View/Routes/app_routes.dart';
// // // // // //import 'View/Themes/app_theme.dart';
// // // // // import 'package:firebase_core/firebase_core.dart';

// // // // // import 'firebase_options.dart';

// // // // // Future<void> main() async {
// // // // //   WidgetsFlutterBinding.ensureInitialized();
// // // // //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
// // // // //   final MessagingService _messagingService = MessagingService();
// // // // //   await _messagingService.init();
// // // // //   runApp(const ProviderScope(child: MyApp()));
// // // // // }

// // // // // final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// // // // // class MyApp extends StatelessWidget {
// // // // //   const MyApp({super.key});
// // // // //   @override
// // // // //   Widget build(BuildContext context) {
// // // // //     return MaterialApp.router(
// // // // //       debugShowCheckedModeBanner: false,
// // // // //       title: 'aminidriver',
// // // // //       //themeMode: ThemeMode.system,
// // // // //       //theme: appTheme,
// // // // //       //runApp(const MaterialApp(home: VehicleOnboardingScreen()));
// // // // //       //darkTheme: appDarkTheme,
// // // // //       routerConfig: router,
// // // // //      // navigatorKey: navigatorKey,
// // // // //     );

// // // // //     // return MaterialApp.router(
// // // // //     //   debugShowCheckedModeBanner: false,
// // // // //     //   title: 'aminidriver',
// // // // //     //   theme: appTheme,
// // // // //     //   routerConfig: router,
// // // // //     // );
// // // // //   }
// // // // // }

// // // // // // import 'package:flutter/material.dart';

// // // // // // void main() {
// // // // // //   runApp(const MyApp());
// // // // // // }

// // // // // // class MyApp extends StatelessWidget {
// // // // // //   const MyApp({super.key});

// // // // // //   // This widget is the root of your application.
// // // // // //   @override
// // // // // //   Widget build(BuildContext context) {
// // // // // //     return MaterialApp(
// // // // // //       title: 'Flutter Demo',
// // // // // //       theme: ThemeData(
// // // // // //         // This is the theme of your application.
// // // // // //         //
// // // // // //         // TRY THIS: Try running your application with "flutter run". You'll see
// // // // // //         // the application has a purple toolbar. Then, without quitting the app,
// // // // // //         // try changing the seedColor in the colorScheme below to Colors.green
// // // // // //         // and then invoke "hot reload" (save your changes or press the "hot
// // // // // //         // reload" button in a Flutter-supported IDE, or press "r" if you used
// // // // // //         // the command line to start the app).
// // // // // //         //
// // // // // //         // Notice that the counter didn't reset back to zero; the application
// // // // // //         // state is not lost during the reload. To reset the state, use hot
// // // // // //         // restart instead.
// // // // // //         //
// // // // // //         // This works for code too, not just values: Most code changes can be
// // // // // //         // tested with just a hot reload.
// // // // // //         colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
// // // // // //       ),
// // // // // //       home: const MyHomePage(title: 'Flutter Demo Home Page'),
// // // // // //     );
// // // // // //   }
// // // // // // }

// // // // // // class MyHomePage extends StatefulWidget {
// // // // // //   const MyHomePage({super.key, required this.title});

// // // // // //   // This widget is the home page of your application. It is stateful, meaning
// // // // // //   // that it has a State object (defined below) that contains fields that affect
// // // // // //   // how it looks.

// // // // // //   // This class is the configuration for the state. It holds the values (in this
// // // // // //   // case the title) provided by the parent (in this case the App widget) and
// // // // // //   // used by the build method of the State. Fields in a Widget subclass are
// // // // // //   // always marked "final".

// // // // // //   final String title;

// // // // // //   @override
// // // // // //   State<MyHomePage> createState() => _MyHomePageState();
// // // // // // }

// // // // // // class _MyHomePageState extends State<MyHomePage> {
// // // // // //   int _counter = 0;

// // // // // //   void _incrementCounter() {
// // // // // //     setState(() {
// // // // // //       // This call to setState tells the Flutter framework that something has
// // // // // //       // changed in this State, which causes it to rerun the build method below
// // // // // //       // so that the display can reflect the updated values. If we changed
// // // // // //       // _counter without calling setState(), then the build method would not be
// // // // // //       // called again, and so nothing would appear to happen.
// // // // // //       _counter++;
// // // // // //     });
// // // // // //   }

// // // // // //   @override
// // // // // //   Widget build(BuildContext context) {
// // // // // //     // This method is rerun every time setState is called, for instance as done
// // // // // //     // by the _incrementCounter method above.
// // // // // //     //
// // // // // //     // The Flutter framework has been optimized to make rerunning build methods
// // // // // //     // fast, so that you can just rebuild anything that needs updating rather
// // // // // //     // than having to individually change instances of widgets.
// // // // // //     return Scaffold(
// // // // // //       appBar: AppBar(
// // // // // //         // TRY THIS: Try changing the color here to a specific color (to
// // // // // //         // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
// // // // // //         // change color while the other colors stay the same.
// // // // // //         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
// // // // // //         // Here we take the value from the MyHomePage object that was created by
// // // // // //         // the App.build method, and use it to set our appbar title.
// // // // // //         title: Text(widget.title),
// // // // // //       ),
// // // // // //       body: Center(
// // // // // //         // Center is a layout widget. It takes a single child and positions it
// // // // // //         // in the middle of the parent.
// // // // // //         child: Column(
// // // // // //           // Column is also a layout widget. It takes a list of children and
// // // // // //           // arranges them vertically. By default, it sizes itself to fit its
// // // // // //           // children horizontally, and tries to be as tall as its parent.
// // // // // //           //
// // // // // //           // Column has various properties to control how it sizes itself and
// // // // // //           // how it positions its children. Here we use mainAxisAlignment to
// // // // // //           // center the children vertically; the main axis here is the vertical
// // // // // //           // axis because Columns are vertical (the cross axis would be
// // // // // //           // horizontal).
// // // // // //           //
// // // // // //           // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
// // // // // //           // action in the IDE, or press "p" in the console), to see the
// // // // // //           // wireframe for each widget.
// // // // // //           mainAxisAlignment: MainAxisAlignment.center,
// // // // // //           children: <Widget>[
// // // // // //             const Text('You have pushed the button this many times:'),
// // // // // //             Text(
// // // // // //               '$_counter',
// // // // // //               style: Theme.of(context).textTheme.headlineMedium,
// // // // // //             ),
// // // // // //           ],
// // // // // //         ),
// // // // // //       ),
// // // // // //       floatingActionButton: FloatingActionButton(
// // // // // //         onPressed: _incrementCounter,
// // // // // //         tooltip: 'Increment',
// // // // // //         child: const Icon(Icons.add),
// // // // // //       ), // This trailing comma makes auto-formatting nicer for build methods.
// // // // // //     );
// // // // // //   }
// // // // // // }
// // // // // import 'package:flutter/material.dart';
// // // // // import 'package:firebase_core/firebase_core.dart';
// // // // // import 'firebase_options.dart';
// // // // // import 'package:cloud_firestore/cloud_firestore.dart';
// // // // // import 'package:firebase_auth/firebase_auth.dart';
// // // // // import 'package:http/http.dart' as http;
// // // // // import 'dart:convert';

// // // // // void main() async {
// // // // //   WidgetsFlutterBinding.ensureInitialized();
// // // // //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
// // // // //   runApp(const MaterialApp(home: RegisterDriverScreen()));
// // // // // }

// // // // // class RegisterDriverScreen extends StatelessWidget {
// // // // //   const RegisterDriverScreen({super.key});

// // // // //   @override
// // // // //   Widget build(BuildContext context) {
// // // // //     return Scaffold(
// // // // //       appBar: AppBar(title: const Text("Register Driver")),
// // // // //       body: Center(
// // // // //         child: ElevatedButton(
// // // // //           onPressed: () {
// // // // //             registerDriver(
// // // // //               name: "Kevin Otieno",
// // // // //               email: "ibrahimomar@darkaez.co.ke",
// // // // //               password: "ba4nyibA,", // ensure this is valid
// // // // //               phone: "+254712345678",
// // // // //               category: "Matatu",
// // // // //             );
// // // // //           },
// // // // //           child: const Text("Register Driver"),
// // // // //         ),
// // // // //       ),
// // // // //     );
// // // // //   }
// // // // // }

// // // // // Future<void> registerDriver({
// // // // //   required String name,
// // // // //   required String email,
// // // // //   required String password,
// // // // //   required String phone,
// // // // //   required String category,
// // // // // }) async {
// // // // //   UserCredential userCredential;

// // // // //   // 🔐 Step 1: Create user in Firebase Auth
// // // // //   try {
// // // // //     userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
// // // // //       email: email,
// // // // //       password: password,
// // // // //     );
// // // // //     debugPrint("✅ FirebaseAuth: User created");
// // // // //   } on FirebaseAuthException catch (e) {
// // // // //     if (e.code == 'email-already-in-use') {
// // // // //       debugPrint("⚠️ User already exists, trying to sign in...");
// // // // //       userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
// // // // //         email: email,
// // // // //         password: password,
// // // // //       );
// // // // //     } else {
// // // // //       debugPrint("❌ FirebaseAuth error: ${e.message}");
// // // // //       return;
// // // // //     }
// // // // //   } catch (e) {
// // // // //     debugPrint("❌ Unexpected FirebaseAuth error: $e");
// // // // //     return;
// // // // //   }

// // // // //   final token = await userCredential.user?.getIdToken();

// // // // //   // 📦 Step 2: Prepare driver data
// // // // //   final driverData = {
// // // // //     "name": name,
// // // // //     "email": email,
// // // // //     "phone": phone,
// // // // //     "category": category,
// // // // //     "createdAt": FieldValue.serverTimestamp(),
// // // // //   };

// // // // //   // 📝 Step 3: Post to Firestore
// // // // //   try {
// // // // //     await FirebaseFirestore.instance.collection("drivers").add(driverData);
// // // // //     debugPrint("✅ Firestore: Driver data added");
// // // // //   } catch (e) {
// // // // //     debugPrint("❌ Firestore error: $e");
// // // // //   }

// // // // //   // 🌐 Step 4: Post to backend API
// // // // //   try {
// // // // //     final response = await http.post(
// // // // //       Uri.parse("http://192.168.27.145:7047/api/auth/firebase-login"),
// // // // //       headers: {
// // // // //         'Content-Type': 'application/json',
// // // // //         'Authorization': 'Bearer $token',
// // // // //       },
// // // // //       body: jsonEncode({
// // // // //         "fullname": name,
// // // // //         "email": email,
// // // // //         "phone": phone,
// // // // //         "role": category,
// // // // //         "token": token,
// // // // //       }),
// // // // //     );

// // // // //     if (response.statusCode == 200 || response.statusCode == 201) {
// // // // //       debugPrint("✅ Backend: Driver posted");
// // // // //     } else {
// // // // //       debugPrint("❌ Backend failed: ${response.statusCode} - ${response.body}");
// // // // //     }
// // // // //   } catch (e) {
// // // // //     debugPrint("❌ Backend error: $e");
// // // // //   }
// // // // // }
