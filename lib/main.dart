import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:aminidriver/Container/utils/keys.dart';
import 'package:aminidriver/Container/utils/pending_ride_storage.dart';
import 'package:aminidriver/Onboarding/driver_location_live.dart';
import 'package:aminidriver/Onboarding/ride_status_burner.dart';
import 'package:aminidriver/Onboarding/trip_detail_screen.dart';
import 'package:aminidriver/View/Routes/app_routes.dart';
import 'package:aminidriver/View/Routes/routes.dart';
import 'package:aminidriver/View/Screens/Nav_Screens/navigation_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'firebase_options.dart';
import 'firebase_passenger_options.dart' as passengerOptions;
import 'package:http/http.dart' as http;

// ------------------ Global Variables ------------------
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
late FirebaseApp passengerApp;
final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();
final AudioPlayer _audioPlayer = AudioPlayer();
Timer? _rideCountdownTimer;
int _rideRemaining = 30;
Map<String, dynamic>? _currentRide;

Timer? _vibrationTimer;

bool _isShowingRide = false;

// Notification channel
const AndroidNotificationChannel rideCallChannel = AndroidNotificationChannel(
  'ride_call',
  'Ride Calls',
  description: 'Incoming ride requests',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  sound: RawResourceAndroidNotificationSound('ringtone'),
);

final androidDetails = AndroidNotificationDetails(
  rideCallChannel.id,
  rideCallChannel.name,
  channelDescription: rideCallChannel.description,
  importance: Importance.high,
  priority: Priority.high,
  category: AndroidNotificationCategory.call,
  fullScreenIntent: true,
  autoCancel: false,
  ongoing: true,
  sound: RawResourceAndroidNotificationSound('ringtone'),
  vibrationPattern: Int64List.fromList([0, 1200, 800, 1200, 800]),
);

// ------------------ Main ------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Primary Firebase app
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Passenger Firebase app
  passengerApp = await Firebase.initializeApp(
    name: 'passengerApp',
    options: passengerOptions.DefaultFirebaseOptions.currentPlatform,
  );

  // Setup notifications
  await _setupCallNotifications();

  // Run app
  runApp(const ProviderScope(child: MyApp()));

  // Init background services
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initBackgroundServices();
  });

  // Register background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
}

// ------------------ Notifications Setup ------------------
// Future<void> _setupCallNotifications() async {
//   const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
//   const initSettings = InitializationSettings(android: androidInit);

//   await notificationsPlugin.initialize(initSettings);

//   await notificationsPlugin
//       .resolvePlatformSpecificImplementation<
//         AndroidFlutterLocalNotificationsPlugin
//       >()
//       ?.createNotificationChannel(rideCallChannel);
// }

Future<void> _setupCallNotifications() async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

  const initSettings = InitializationSettings(android: androidInit);

  await notificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (details) async {
      if (details.payload != null) {
        final data = jsonDecode(details.payload!);

        if (details.actionId == 'ACCEPT') {
          _currentRide = data;
          _acceptRide();
        } else if (details.actionId == 'REJECT') {
          _currentRide = data;
          _rejectRide();
        } else {
          _showRideOverlay(data);
        }
      }
    },
  );

  await notificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(rideCallChannel);
}

Future<void> showIncomingRideNotification(Map<String, dynamic> data) async {
  final androidDetails = AndroidNotificationDetails(
    rideCallChannel.id,
    rideCallChannel.name,
    importance: Importance.max,
    priority: Priority.high,
    fullScreenIntent: true,
    category: AndroidNotificationCategory.call,
    visibility: NotificationVisibility.public,
    ongoing: true,
    autoCancel: false,
    actions: const [
      AndroidNotificationAction('ACCEPT', 'Accept'),
      AndroidNotificationAction('REJECT', 'Reject'),
    ],
  );

  await notificationsPlugin.show(
    999,
    "Incoming Ride",
    "${data['pickup']} → ${data['destination']}",
    NotificationDetails(android: androidDetails),
    payload: jsonEncode(data),
  );
}

// ------------------ FCM Handlers ------------------
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("🔙 Handling background message: ${message.messageId}");

  if (message.data.containsKey('rideId')) {
    unawaited(savePendingRide(message.data, 300));
  }
}

Future<void> setupFCM() async {
  FirebaseMessaging.onMessage.listen((message) async {
    if (message.data.containsKey('rideId')) {
      unawaited(savePendingRide(message.data, 300));
      // _currentRide = message.data;
      // _rideRemaining = 30;
      // _startRideCountdown();
      await showIncomingRideNotification(message.data);
      _startRideAlert(message.data);
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((message) async {
    if (message.data.containsKey('rideId')) {
      _currentRide = message.data;
      _showRideOverlay(message.data);
    }
  });

  FirebaseMessaging.instance.getInitialMessage().then((message) async {
    if (message != null && message.data.containsKey('rideId')) {
      _currentRide = message.data;
      _showRideOverlay(message.data);
    }
  });
}

// ------------------ Background Services ------------------
Future<void> _initBackgroundServices() async {
  setupFCM();

  // Start driver location updates
  Future.delayed(const Duration(seconds: 1), () {
    DriverLocationService().startSendingLocation();
  });

  // Restore pending ride
  final ride = await getPendingRide();
  if (ride != null) {
    _currentRide = ride;
    _rideRemaining = 30;
    _startRideAlert(ride);
  }
}

// ------------------ Ride Alert Helpers ------------------
// void _startRideAlert(Map<String, dynamic> ride) {
//   _showRideOverlay(ride);
//   _startRingtone();
//   _startVibration();
//   WakelockPlus.enable();
// }

// void _stopAlerts() {
//   _stopRingtone();
//   notificationsPlugin.cancel(999);
//   _currentRide = null;
//   _rideCountdownTimer?.cancel();
//   WakelockPlus.disable();
// }
void _startRideAlert(Map<String, dynamic> ride) {
  if (_isShowingRide) return;

  _isShowingRide = true;

  _startRideCountdown();
  _startRingtone();
  _startVibration();
  _showRideOverlay(ride);

  WakelockPlus.enable();
}

void _stopAlerts() {
  _rideCountdownTimer?.cancel();
  _vibrationTimer?.cancel();
  _audioPlayer.stop();
  notificationsPlugin.cancel(999);

  _isShowingRide = false;
  _currentRide = null;

  WakelockPlus.disable();
}

Future<void> _startRingtone() async {
  await _audioPlayer.setReleaseMode(ReleaseMode.loop);
  await _audioPlayer.play(AssetSource('ringtones/ringtone.mp3'), volume: 1.0);
}

// void _startRingtone() async {
//   const ringtoneUrl =
//       'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
//   await _audioPlayer.play(UrlSource(ringtoneUrl), volume: 1.0);
//   _audioPlayer.setReleaseMode(ReleaseMode.loop);
// }

//void _stopRingtone() async => await _audioPlayer.stop();

// void _startVibration() {
//   Timer.periodic(const Duration(seconds: 2), (timer) {
//     HapticFeedback.vibrate();
//     if (_currentRide == null) timer.cancel();
//   });
// }

void _startVibration() {
  _vibrationTimer?.cancel();

  _vibrationTimer = Timer.periodic(const Duration(seconds: 2), (_) {
    HapticFeedback.vibrate();
  });
}

void _startRideCountdown() {
  _rideRemaining = 30;

  _rideCountdownTimer?.cancel();

  _rideCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    if (_rideRemaining > 0) {
      _rideRemaining--;
    } else {
      timer.cancel();
      if (_currentRide != null) _rejectRide(auto: true);
    }
  });
}
// void _startRideCountdown() {
//   _rideCountdownTimer?.cancel();
//   _rideCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
//     if (_rideRemaining > 0) {
//       _rideRemaining--;
//     } else {
//       timer.cancel();
//       if (_currentRide != null) _rejectRide(auto: true);
//     }
//   });
// }

// void _showRideOverlay(Map<String, dynamic> ride) {
//   final context = navigatorKey.currentContext;
//   if (context == null) return;

//   showDialog(
//     context: context,
//     barrierDismissible: false,
//     builder:
//         (_) => WillPopScope(
//           onWillPop: () async => false,
//           child: Scaffold(
//             backgroundColor: Colors.black,
//             body: SafeArea(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   const SizedBox(height: 40),
//                   Column(
//                     children: [
//                       const Icon(
//                         Icons.phone_in_talk,
//                         color: Colors.green,
//                         size: 80,
//                       ),
//                       const SizedBox(height: 20),
//                       Text(
//                         ride['rider'] ?? '',
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 32,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       const SizedBox(height: 10),
//                       const Text(
//                         "Incoming Ride Call",
//                         style: TextStyle(color: Colors.grey, fontSize: 18),
//                       ),
//                       const SizedBox(height: 20),
//                       Text(
//                         "$_rideRemaining sec",
//                         style: const TextStyle(color: Colors.red, fontSize: 22),
//                       ),
//                     ],
//                   ),
//                   Column(
//                     children: [
//                       Text(
//                         ride['pickup'] ?? '',
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 20,
//                         ),
//                       ),
//                       const Icon(Icons.arrow_downward, color: Colors.grey),
//                       Text(
//                         ride['destination'] ?? '',
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 20,
//                         ),
//                       ),
//                     ],
//                   ),
//                   Padding(
//                     padding: const EdgeInsets.only(bottom: 40),
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                       children: [
//                         _callButton(
//                           icon: Icons.call_end,
//                           color: Colors.red,
//                           label: "Decline",
//                           onTap: () => _rejectRide(),
//                         ),
//                         _callButton(
//                           icon: Icons.call,
//                           color: Colors.green,
//                           label: "Accept",
//                           onTap: () => _acceptRide(),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//   );
// }

void _showRideOverlay(Map<String, dynamic> ride) {
  final context = navigatorKey.currentContext;
  if (context == null) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder:
        (_) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 40),

                /// DRIVER ICON
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, size: 40),
                ),

                /// RIDER INFO
                Column(
                  children: [
                    Text(
                      ride['rider'] ?? '',
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

                /// COUNTDOWN
                Text(
                  "$_rideRemaining sec",
                  style: const TextStyle(color: Colors.red, fontSize: 22),
                ),

                /// LOCATIONS
                Column(
                  children: [
                    _locationTile(ride['pickup'], Colors.green),
                    const SizedBox(height: 10),
                    _locationTile(ride['destination'], Colors.red),
                  ],
                ),

                /// ACTIONS
                Row(
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

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
  );
}

Widget _locationTile(String? text, Color color) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
    child: Row(
      children: [
        Icon(Icons.circle, color: color, size: 12),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}
// Widget _locationTile(String text, Color color) {
//   return Padding(
//     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
//     child: Row(
//       children: [
//         Icon(Icons.circle, color: color, size: 12),
//         const SizedBox(width: 10),
//         Expanded(
//           child: Text(
//             text ?? '',
//             style: const TextStyle(color: Colors.white, fontSize: 16),
//             overflow: TextOverflow.ellipsis,
//           ),
//         ),
//       ],
//     ),
//   );
// }
// Widget _callButton({
//   required IconData icon,
//   required Color color,
//   required String label,
//   required VoidCallback onTap,
// }) {
//   return Column(
//     children: [
//       GestureDetector(
//         onTap: onTap,
//         child: CircleAvatar(
//           radius: 38,
//           backgroundColor: color,
//           child: Icon(icon, color: Colors.white, size: 32),
//         ),
//       ),
//       const SizedBox(height: 10),
//       Text(label, style: const TextStyle(color: Colors.white)),
//     ],
//   );
// }

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

// ------------------ Accept / Reject ------------------
Future<void> _acceptRide() async {
  if (_currentRide == null) return;

  _rideCountdownTimer?.cancel();
  _stopAlerts();

  final user = FirebaseAuth.instance.currentUser;
  final position = await Geolocator.getCurrentPosition();

  await http.post(
    Uri.parse('$baseUrl/rides/driver/accept-ride'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'rideId': int.parse(_currentRide!['rideId']),
      'firebaseIdToken': user?.uid,
      'latitude': position.latitude,
      'longitude': position.longitude,
    }),
  );

  Navigator.popUntil(navigatorKey.currentContext!, (route) => route.isFirst);
  Navigator.pushReplacement(
    navigatorKey.currentContext!,
    MaterialPageRoute(
      builder:
          (_) => TripDetailScreen(
            rideId: _currentRide!['rideId'],
            rider: _currentRide!['rider'] ?? '',
            pickupName: _currentRide!['pickup'] ?? '',
            destinationName: _currentRide!['destination'] ?? '',
            pickupLat: double.tryParse('${_currentRide!['pickupLat']}') ?? 0,
            pickupLng: double.tryParse('${_currentRide!['pickupLng']}') ?? 0,
            destLat: double.tryParse('${_currentRide!['destLat']}') ?? 0,
            destLng: double.tryParse('${_currentRide!['destLng']}') ?? 0,
            mobile: '',
            riderId: '',
          ),
    ),
  );

  _currentRide = null;
}

Future<void> _rejectRide({bool auto = false}) async {
  if (_currentRide == null) return;

  _rideCountdownTimer?.cancel();
  _stopAlerts();

  await http.post(
    Uri.parse('$baseUrl/rides/reject-ride'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'rideId': _currentRide!['rideId']}),
  );

  Navigator.popUntil(navigatorKey.currentContext!, (route) => route.isFirst);
  Navigator.pushReplacement(
    navigatorKey.currentContext!,
    MaterialPageRoute(builder: (_) => const NavigationScreen()),
  );

  _currentRide = null;
}

// ------------------ MyApp ------------------
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'amini driver',
      routerConfig: router,
      builder: (context, child) => AuthAndBannerWrapper(child: child!),
    );
  }
}

// ------------------ Auth & Banner ------------------
class AuthAndBannerWrapper extends ConsumerWidget {
  final Widget child;
  const AuthAndBannerWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final userId = snapshot.data?.uid;
        return Stack(
          children: [
            child,
            if (userId != null) RideStatusBanner(userId: userId),
          ],
        );
      },
    );
  }
}

// import 'dart:async';
// import 'dart:typed_data';
// import 'package:aminidriver/Container/utils/pending_ride_storage.dart';
// import 'package:aminidriver/Onboarding/driver_location_live.dart';
// import 'package:aminidriver/Onboarding/ride_status_burner.dart';
// import 'package:aminidriver/View/Routes/app_routes.dart';
// import 'package:aminidriver/View/Routes/routes.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'firebase_options.dart';
// import 'firebase_passenger_options.dart' as passengerOptions;

// //final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>(
//   debugLabel: 'root',
// );
// late FirebaseApp passengerApp;
// final FlutterLocalNotificationsPlugin notificationsPlugin =
//     FlutterLocalNotificationsPlugin();

// const AndroidNotificationChannel rideCallChannel = AndroidNotificationChannel(
//   'ride_call',
//   'Ride Calls',
//   description: 'Incoming ride requests',
//   importance: Importance.max,
//   playSound: true,
//   enableVibration: true,
//   sound: RawResourceAndroidNotificationSound('ringtone'),
// );

// Future<void> setupCallNotifications() async {
//   const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

//   const initSettings = InitializationSettings(android: androidInit);

//   await notificationsPlugin.initialize(initSettings);

//   await notificationsPlugin
//       .resolvePlatformSpecificImplementation<
//         AndroidFlutterLocalNotificationsPlugin
//       >()
//       ?.createNotificationChannel(rideCallChannel);
// }

// final androidDetails = AndroidNotificationDetails(
//   rideCallChannel.id,
//   rideCallChannel.name,
//   channelDescription: rideCallChannel.description,
//   importance: Importance.max,
//   priority: Priority.max,
//   category: AndroidNotificationCategory.call,
//   fullScreenIntent: true,
//   autoCancel: false,
//   ongoing: true,
//   sound: RawResourceAndroidNotificationSound('ringtone'),
//   vibrationPattern: Int64List.fromList([0, 1200, 800, 1200, 800]),
// );

// /// Background message handler (runs in isolate, non-UI thread)
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
//   debugPrint("🔙 Handling background message: ${message.messageId}");

//   if (message.data.containsKey('rideId')) {
//     // Run save in background (don’t block handler)
//     unawaited(savePendingRide(message.data, 300));
//   }
// }

// Future<void> showIncomingRideCall(Map<String, dynamic> data) async {
//   // 🔔 Vibration handled via notification itself (no plugin)
//   await notificationsPlugin.show(
//     999,
//     '🚖 Incoming Ride',
//     '${data['pickup']} → ${data['destination']}',
//     NotificationDetails(
//       android: AndroidNotificationDetails(
//         rideCallChannel.id,
//         rideCallChannel.name,
//         channelDescription: rideCallChannel.description,
//         importance: Importance.high,
//         priority: Priority.high,
//         category: AndroidNotificationCategory.call,
//         fullScreenIntent: true,
//         ongoing: true,
//         autoCancel: false,
//         sound: const RawResourceAndroidNotificationSound('ringtone'),
//         vibrationPattern: Int64List.fromList([0, 1200, 800, 1200, 800]),
//       ),
//     ),
//   );
// }

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   // ⚡ Initialize only the primary Firebase app
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
//   passengerApp = await Firebase.initializeApp(
//     name: 'passengerApp',
//     options: passengerOptions.DefaultFirebaseOptions.currentPlatform,
//   );

//   await setupCallNotifications();
//   // 🚀 Show UI immediately
//   runApp(const ProviderScope(child: MyApp()));

//   // 🪄 Defer heavy setup
//   WidgetsBinding.instance.addPostFrameCallback((_) {
//     _initBackgroundServices();
//   });

//   // ✅ Register background message handler
//   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
// }

// Future<void> _initBackgroundServices() async {
//   // Initialize passenger Firebase in background
//   // unawaited(() async {
//   //   passengerApp = await Firebase.initializeApp(
//   //     name: 'passengerApp',
//   //     options: passengerOptions.DefaultFirebaseOptions.currentPlatform,
//   //   );
//   // }());

//   // Setup FCM listeners
//   setupFCM();

//   // Start location service lazily (small delay to avoid frame drop)
//   Future.delayed(const Duration(seconds: 1), () {
//     DriverLocationService().startSendingLocation();
//   });

//   // Restore pending ride (if exists)
//   final ride = await getPendingRide();
//   if (ride != null) {
//     _openRideScreen(ride);
//   }
// }

// void setupFCM() {
//   // Foreground
//   FirebaseMessaging.onMessage.listen((message) async {
//     if (message.data.containsKey('rideId')) {
//       unawaited(savePendingRide(message.data, 300));
//       await showIncomingRideCall(message.data);
//       _openRideScreen(message.data);
//     }
//   });

//   // Background → tap notification
//   FirebaseMessaging.onMessageOpenedApp.listen((message) async {
//     if (message.data.containsKey('rideId')) {
//       unawaited(savePendingRide(message.data, 300));
//       _openRideScreen(message.data);
//     }
//   });

//   // Terminated
//   FirebaseMessaging.instance.getInitialMessage().then((message) async {
//     if (message != null && message.data.containsKey('rideId')) {
//       unawaited(savePendingRide(message.data, 300));
//       _openRideScreen(message.data);
//     }
//   });
// }

// //working

// // void setupFCM() {
// //   // App opened from background
// //   FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
// //     if (message.data.containsKey('rideId')) {
// //       unawaited(savePendingRide(message.data, 300));
// //       _openRideScreen(message.data);
// //     }
// //   });

// //   // App opened from terminated (cold start)
// //   FirebaseMessaging.instance.getInitialMessage().then((message) async {
// //     if (message != null && message.data.containsKey('rideId')) {
// //       unawaited(savePendingRide(message.data, 300));
// //       _openRideScreen(message.data);
// //     }
// //   });

// //   // Foreground messages
// //   FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
// //     if (message.data.containsKey('rideId')) {
// //       unawaited(savePendingRide(message.data, 300));
// //       _openRideScreen(message.data);
// //     }
// //   });
// // }

// // void _openRideScreen(Map<String, dynamic> data) {
// //   final context = navigatorKey.currentContext;
// //   if (context == null) return;
// //   context.push('/ride-alert', extra: data);
// // }
// void _openRideScreen(Map<String, dynamic> data) {
//   debugPrint("🚀 Navigating to ridealert with: $data");
//   router.push('/${Routes().ridealert}', extra: data);
// }

// class MyApp extends ConsumerWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     return MaterialApp.router(
//       debugShowCheckedModeBanner: false,
//       title: 'amini driver',
//       routerConfig: router,
//       builder: (context, child) {
//         // This context is under GoRouter
//         return AuthAndBannerWrapper(child: child!);
//       },
//       //navigatorKey: navigatorKey,
//     );
//   }
// }

// class AuthAndBannerWrapper extends ConsumerWidget {
//   final Widget child;
//   const AuthAndBannerWrapper({super.key, required this.child});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     return StreamBuilder<User?>(
//       stream: FirebaseAuth.instance.authStateChanges(),
//       builder: (context, snapshot) {
//         final userId = snapshot.data?.uid;

//         return Stack(
//           children: [
//             child,
//             if (userId != null) RideStatusBanner(userId: userId),
//           ],
//         );
//       },
//     );
//   }
// }
// import 'dart:async';
// import 'package:aminidriver/Container/utils/pending_ride_storage.dart';
// import 'package:aminidriver/Onboarding/driver_location_live.dart';
// import 'package:aminidriver/View/Routes/app_routes.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'firebase_options.dart';
// import 'package:go_router/go_router.dart';
// import 'firebase_passenger_options.dart' as passengerOptions;

// final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// late FirebaseApp passengerApp;

// /// Background message handler
// Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
//   print("🔙 Handling background message: ${message.messageId}");

//   if (message.data.containsKey('rideId')) {
//     await savePendingRide(message.data, 300); // store for 5 minutes
//   }
// }

// // Future<void> main() async {
// //   WidgetsFlutterBinding.ensureInitialized();
// //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

// //   passengerApp = await Firebase.initializeApp(
// //     name: 'passengerApp',
// //     options: passengerOptions.DefaultFirebaseOptions.currentPlatform,
// //   );

// //   // Background handler for FCM
// //   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

// //   // Run UI immediately (don’t wait for other setup)
// //   runApp(const ProviderScope(child: MyApp()));

// //   // 🚀 Defer heavy setup after UI shows
// //   WidgetsBinding.instance.addPostFrameCallback((_) async {
// //     // Setup FCM listeners
// //     setupFCM();

// //     // Start driver location service only when needed
// //     DriverLocationService().startSendingLocation();

// //     // Restore pending ride
// //     final ride = await getPendingRide();
// //     if (ride != null) {
// //       _openRideScreen(ride);
// //     }
// //   });
// // }
// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   // Initialize main Firebase app quickly
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

//   // Run the UI immediately
//   runApp(const ProviderScope(child: MyApp()));

//   // Defer heavy setup after first frame
//   WidgetsBinding.instance.addPostFrameCallback((_) async {
//     // Passenger Firebase (secondary app)
//     passengerApp = await Firebase.initializeApp(
//       name: 'passengerApp',
//       options: passengerOptions.DefaultFirebaseOptions.currentPlatform,
//     );

//     // FCM setup
//     setupFCM();

//     // Start driver location service only if needed
//     DriverLocationService().startSendingLocation();

//     // Restore pending ride (if exists)
//     final ride = await getPendingRide();
//     if (ride != null) _openRideScreen(ride);
//   });

//   // Background message handler
//   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
// }

// void setupFCM() {
//   // App opened from background notification
//   FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
//     if (message.data.containsKey('rideId')) {
//       await savePendingRide(message.data, 300);
//       _openRideScreen(message.data);
//     }
//   });

//   // App opened from terminated state (cold start)
//   FirebaseMessaging.instance.getInitialMessage().then((message) async {
//     if (message != null && message.data.containsKey('rideId')) {
//       await savePendingRide(message.data, 300);
//       _openRideScreen(message.data);
//     }
//   });

//   // Foreground messages
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
//   context.push('/ride-alert', extra: data);
// }

// class MyApp extends ConsumerWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     return MaterialApp.router(
//       debugShowCheckedModeBanner: false,
//       title: 'amini driver',
//       routerConfig: router,
//       //navigatorKey: navigatorKey,
//     );
//   }
// }
// // // import 'dart:async';
// // // import 'package:aminidriver/Container/utils/pending_ride_storage.dart';
// // // import 'package:aminidriver/Onboarding/driver_location_live.dart';
// // // import 'package:aminidriver/View/Routes/app_routes.dart';
// // // import 'package:firebase_core/firebase_core.dart';
// // // import 'package:firebase_messaging/firebase_messaging.dart';
// // // import 'package:flutter/material.dart';
// // // import 'package:flutter_riverpod/flutter_riverpod.dart';
// // // import 'firebase_options.dart';
// // // import 'package:go_router/go_router.dart';

// // // final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// // // /// Background message handler
// // // Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
// // //   // ✅ Prevent duplicate Firebase initialization
// // //   // if (Firebase.apps.isEmpty) {
// // //   //   await Firebase.initializeApp(
// // //   //     options: DefaultFirebaseOptions.currentPlatform,
// // //   //   );
// // //   // }

// // //   print("🔙 Handling background message: ${message.messageId}");

// // //   // Save ride for recovery
// // //   if (message.data.containsKey('rideId')) {
// // //     await savePendingRide(message.data, 300); // store for 5 minutes
// // //   }
// // // }

// // // // Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
// // // //   if (Firebase.apps.isEmpty) {
// // // //     await Firebase.initializeApp(
// // // //       options: DefaultFirebaseOptions.currentPlatform,
// // // //     );
// // // //   }

// // // //   print("🔙 Handling background message: ${message.messageId}");

// // // //   if (message.data.containsKey('rideId')) {
// // // //     await savePendingRide(message.data, 300);
// // // //   }
// // // // }

// // // Future<void> main() async {
// // //   WidgetsFlutterBinding.ensureInitialized();

// // //   if (Firebase.apps.isEmpty) {
// // //     await Firebase.initializeApp(
// // //       options: DefaultFirebaseOptions.currentPlatform,
// // //     );
// // //   }

// // //   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

// // //   setupFCM();
// // //   DriverLocationService().startSendingLocation();

// // //   final ride = await getPendingRide();

// // //   runApp(ProviderScope(child: MyApp(pendingRide: ride)));
// // // }

// // // // Future<void> main() async {
// // // //   WidgetsFlutterBinding.ensureInitialized();

// // // //   // ✅ Initialize Firebase only once
// // // //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

// // // //   // Register background message handler
// // // //   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

// // // //   // Setup FCM listeners
// // // //   setupFCM();

// // // //   // Start driver live location service
// // // //   DriverLocationService().startSendingLocation();

// // // //   // 🔑 Check if there is a pending ride saved locally
// // // //   final ride = await getPendingRide();

// // // //   runApp(ProviderScope(child: MyApp(pendingRide: ride)));
// // // // }

// // // void setupFCM() {
// // //   // 🚀 When user taps a notification while app is in background
// // //   FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
// // //     if (message.data.containsKey('rideId')) {
// // //       await savePendingRide(message.data, 300);
// // //       _openRideScreen(message.data);
// // //     }
// // //   });

// // //   // 🚀 When app was terminated and opened via a notification (cold start)
// // //   FirebaseMessaging.instance.getInitialMessage().then((message) async {
// // //     if (message != null && message.data.containsKey('rideId')) {
// // //       await savePendingRide(message.data, 300);
// // //       _openRideScreen(message.data);
// // //     }
// // //   });

// // //   // 🚀 Foreground messages
// // //   FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
// // //     if (message.data.containsKey('rideId')) {
// // //       await savePendingRide(message.data, 300);
// // //       _openRideScreen(message.data);
// // //     }
// // //   });
// // // }

// // // void _openRideScreen(Map<String, dynamic> data) {
// // //   final context = navigatorKey.currentContext;
// // //   if (context == null) return;

// // //   context.push('/ride-alert', extra: data);
// // // }

// // // class MyApp extends ConsumerWidget {
// // //   final Map<String, dynamic>? pendingRide;

// // //   const MyApp({super.key, this.pendingRide});

// // //   @override
// // //   Widget build(BuildContext context, WidgetRef ref) {
// // //     return MaterialApp.router(
// // //       debugShowCheckedModeBanner: false,
// // //       title: 'amini driver',
// // //       routerConfig: router,
// // //     );
// // //   }
// // // }
// // import 'dart:async';
// // import 'package:aminidriver/Container/utils/pending_ride_storage.dart';
// // import 'package:aminidriver/Onboarding/driver_location_live.dart';
// // import 'package:aminidriver/View/Routes/app_routes.dart';
// // import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/ride_alert_service.dart';
// // import 'package:firebase_core/firebase_core.dart';
// // import 'package:firebase_messaging/firebase_messaging.dart';
// // import 'package:flutter/material.dart';
// // import 'package:flutter_riverpod/flutter_riverpod.dart';
// // import 'firebase_options.dart';
// // import 'package:go_router/go_router.dart';

// // final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// // //final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// // /// Background message handler
// // Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
// //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
// //   print("🔙 Handling background message: ${message.messageId}");

// //   // Save ride for recovery
// //   if (message.data.containsKey('rideId')) {
// //     await savePendingRide(message.data, 300); // store for 5 minutes
// //   }
// // }

// // Future<void> main() async {
// //   WidgetsFlutterBinding.ensureInitialized();
// //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

// //   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

// //   setupFCM();
// //   DriverLocationService().startSendingLocation();

// //   //RideAlertService().start();
// //   //RideAlertService().start(navigatorKey.currentContext!);

// //   // 🔑 Check if there is a pending ride saved locally
// //   final ride = await getPendingRide();

// //   runApp(ProviderScope(child: MyApp(pendingRide: ride)));
// //   WidgetsBinding.instance.addPostFrameCallback((_) {
// //     final context = navigatorKey.currentContext;
// //     if (context != null) {
// //       // setupFCM();
// //       // RideAlertService().start(context);
// //     }
// //   });
// // }

// // void setupFCM() {
// //   // 🚀 When user taps a notification while app is in background
// //   FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
// //     if (message.data.containsKey('rideId')) {
// //       await savePendingRide(message.data, 300);
// //       WidgetsBinding.instance.addPostFrameCallback((_) {
// //         _openRideScreen(message.data);
// //       });
// //     }
// //     // else {
// //     //   _openMessagesScreen();
// //     // }
// //   });

// //   // 🚀 When app was terminated and opened via a notification (cold start)
// //   FirebaseMessaging.instance.getInitialMessage().then((message) async {
// //     if (message != null && message.data.containsKey('rideId')) {
// //       await savePendingRide(message.data, 300);
// //       WidgetsBinding.instance.addPostFrameCallback((_) {
// //         _openRideScreen(message.data);
// //       });
// //     }
// //   });

// //   // 🚀 Foreground messages
// //   FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
// //     if (message.data.containsKey('rideId')) {
// //       await savePendingRide(message.data, 300);
// //       WidgetsBinding.instance.addPostFrameCallback((_) {
// //         _openRideScreen(message.data);
// //       });
// //     }
// //   });
// // }

// // void _openRideScreen(Map<String, dynamic> data) {
// //   final context = navigatorKey.currentContext;
// //   if (context == null) return;

// //   context.push('/ride-alert', extra: data);
// // }

// // // void _openMessagesScreen() {
// // //   final context = navigatorKey.currentContext;
// // //   if (context == null) return;
// // // context.push('/ride-alert', extra: data);
// // //  // context.push('/messages'); // 🔑 Make sure you have a /messages route defined
// // // }

// // class MyApp extends ConsumerWidget {
// //   final Map<String, dynamic>? pendingRide;

// //   const MyApp({super.key, this.pendingRide});

// //   @override
// //   Widget build(BuildContext context, WidgetRef ref) {
// //     return MaterialApp.router(
// //       debugShowCheckedModeBanner: false,
// //       title: 'amini driver',
// //       routerConfig: router,
// //       //_rootNavigatorKey: navigatorKey,
// //     );
// //   }
// // }

// // // // import 'dart:async';
// // // // import 'package:aminidriver/Container/utils/pending_ride_storage.dart';
// // // // import 'package:aminidriver/Onboarding/driver_location_live.dart';
// // // // import 'package:aminidriver/Onboarding/ride_alert.dart';
// // // // import 'package:aminidriver/View/Routes/app_routes.dart';
// // // // import 'package:firebase_core/firebase_core.dart';
// // // // import 'package:firebase_messaging/firebase_messaging.dart';
// // // // import 'package:flutter/material.dart';
// // // // import 'package:flutter_riverpod/flutter_riverpod.dart';
// // // // import 'firebase_options.dart';
// // // // import 'package:go_router/go_router.dart';

// // // // final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// // // // /// Background message handler
// // // // Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
// // // //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
// // // //   print("🔙 Handling background message: ${message.messageId}");

// // // //   // Save ride for recovery
// // // //   if (message.data.containsKey('rideId')) {
// // // //     await savePendingRide(message.data, 300); // store for 5 minutes
// // // //   }
// // // // }

// // // // Future<void> main() async {
// // // //   WidgetsFlutterBinding.ensureInitialized();
// // // //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

// // // //   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

// // // //   setupFCM();
// // // //   DriverLocationService().startSendingLocation();

// // // //   // 🔑 Check if there is a pending ride saved locally
// // // //   final ride = await getPendingRide();

// // // //   runApp(ProviderScope(child: MyApp(pendingRide: ride)));
// // // // }

// // // // // void setupFCM() {

// // // // //   FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
// // // // //     if (message.data.containsKey('rideId')) {
// // // // //       await savePendingRide(message.data, 300);
// // // // //       _openRideScreen(message.data);
// // // // //     }
// // // // //   });

// // // // //   FirebaseMessaging.instance.getInitialMessage().then((message) async {
// // // // //     if (message != null && message.data.containsKey('rideId')) {
// // // // //       await savePendingRide(message.data, 300);
// // // // //       _openRideScreen(message.data);
// // // // //     }
// // // // //   });

// // // // //   FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
// // // // //     if (message.data.containsKey('rideId')) {
// // // // //       await savePendingRide(message.data, 300);
// // // // //       _openRideScreen(message.data);
// // // // //     }
// // // // //   });
// // // // // }

// // // // // void _openRideScreen(Map<String, dynamic> data) {
// // // // //   final context = navigatorKey.currentContext;
// // // // //   if (context == null) return;

// // // // //   context.push(
// // // // //     '/ride-alert',
// // // // //     extra: data, // pass ride data if your route expects it
// // // // //   );
// // // // // }
// // // // void setupFCM() {
// // // //   // 🚀 When user taps a notification while app is in background
// // // //   FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
// // // //     if (message.data.containsKey('rideId')) {
// // // //       await savePendingRide(message.data, 300);
// // // //       _openRideScreen(message.data);
// // // //     } else {
// // // //       // fallback → maybe go to messages screen
// // // //       navigatorKey.currentState?.push(
// // // //         MaterialPageRoute(builder: (_) => RideAlertScreen()),
// // // //       );
// // // //     }
// // // //   });

// // // //   // 🚀 When app was terminated and opened via a notification (cold start)
// // // //   FirebaseMessaging.instance.getInitialMessage().then((message) async {
// // // //     if (message != null && message.data.containsKey('rideId')) {
// // // //       await savePendingRide(message.data, 300);
// // // //       _openRideScreen(message.data);
// // // //     }
// // // //   });

// // // //   // 🚀 Foreground messages
// // // //   FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
// // // //     if (message.data.containsKey('rideId')) {
// // // //       await savePendingRide(message.data, 300);
// // // //       _openRideScreen(message.data);
// // // //     }
// // // //   });
// // // // }

// // // // void _openRideScreen(Map<String, dynamic> data) {
// // // //   final context = navigatorKey.currentContext;
// // // //   if (context == null) return;

// // // //   // If the notification is ride type → go to RideAlertScreen
// // // //   if (data['type'] == 'ride') {
// // // //     context.push('/ride-alert', extra: data);
// // // //   } else {
// // // //     // Otherwise → go to messages screen
// // // //     navigatorKey.currentState?.push(
// // // //       MaterialPageRoute(builder: (_) => RideAlertScreen()),
// // // //     );
// // // //   }
// // // // }

// // // // class MyApp extends ConsumerWidget {
// // // //   final Map<String, dynamic>? pendingRide;

// // // //   const MyApp({super.key, this.pendingRide});

// // // //   @override
// // // //   Widget build(BuildContext context, WidgetRef ref) {
// // // //     return MaterialApp.router(
// // // //       debugShowCheckedModeBanner: false,
// // // //       title: 'amini driver',
// // // //       routerConfig: router,
// // // //     );
// // // //   }
// // // // }

// // // // // Future<void> checkPendingRide(BuildContext context) async {
// // // // //   final pending = await getPendingRide();
// // // // //   if (pending != null) {
// // // // //     Navigator.push(
// // // // //       context,
// // // // //       PageRouteBuilder(
// // // // //         opaque: false,
// // // // //         pageBuilder:
// // // // //             (_, __, ___) => RideAlertScreen(
// // // // //               rideId: pending['rideId'],
// // // // //               rider: pending['rider'],
// // // // //               pickupName: pending['pickupName'],
// // // // //               destinationName: pending['destinationName'],
// // // // //               pickupLat: (pending['pickupLat'] as num?)?.toDouble() ?? 0.0,
// // // // //               pickupLng: (pending['pickupLng'] as num?)?.toDouble() ?? 0.0,
// // // // //               destLat: (pending['destLat'] as num?)?.toDouble() ?? 0.0,
// // // // //               destLng: (pending['destLng'] as num?)?.toDouble() ?? 0.0,
// // // // //             ),
// // // // //       ),
// // // // //     );
// // // // //   }
// // // // // }

// // // // // import 'dart:async';
// // // // // import 'package:aminidriver/Container/utils/pending_ride_storage.dart';
// // // // // import 'package:aminidriver/Onboarding/driver_location_live.dart';
// // // // // import 'package:aminidriver/Onboarding/ride_alert.dart';
// // // // // import 'package:aminidriver/View/Routes/app_routes.dart';
// // // // // import 'package:firebase_core/firebase_core.dart';
// // // // // import 'package:firebase_messaging/firebase_messaging.dart';
// // // // // import 'package:flutter/material.dart';
// // // // // import 'package:flutter_riverpod/flutter_riverpod.dart';
// // // // // import 'firebase_options.dart';

// // // // // final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// // // // // /// Background message handler
// // // // // Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
// // // // //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
// // // // //   print("🔙 Handling background message: ${message.messageId}");
// // // // // }

// // // // // Future<void> main() async {
// // // // //   WidgetsFlutterBinding.ensureInitialized();
// // // // //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

// // // // //   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

// // // // //   setupFCM();
// // // // //   DriverLocationService().startSendingLocation();

// // // // //   // 🔑 Check if there is a pending ride saved locally
// // // // //   final ride = await getPendingRide();

// // // // //   runApp(ProviderScope(child: MyApp(pendingRide: ride)));
// // // // // }

// // // // // void setupFCM() {
// // // // //   FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
// // // // //     _openRideScreen(message.data);
// // // // //   });

// // // // //   FirebaseMessaging.instance.getInitialMessage().then((message) {
// // // // //     if (message != null) _openRideScreen(message.data);
// // // // //   });
// // // // // }

// // // // // void _openRideScreen(Map<String, dynamic> data) {
// // // // //   if (data.containsKey('rideId')) {
// // // // //     navigatorKey.currentState?.push(
// // // // //       MaterialPageRoute(
// // // // //         builder:
// // // // //             (context) => RideAlertScreen(
// // // // //               rideId: data['rideId'],
// // // // //               rider: data['rider'] ?? '',
// // // // //               pickupName: data['pickupName'] ?? '',
// // // // //               destinationName: data['destinationName'] ?? '',
// // // // //               pickupLat: double.tryParse(data['pickupLat'] ?? '') ?? 0.0,
// // // // //               pickupLng: double.tryParse(data['pickupLng'] ?? '') ?? 0.0,
// // // // //               destLat: double.tryParse(data['destLat'] ?? '') ?? 0.0,
// // // // //               destLng: double.tryParse(data['destLng'] ?? '') ?? 0.0,
// // // // //             ),
// // // // //       ),
// // // // //     );
// // // // //   }
// // // // // }
// // // // // Future<void> checkPendingRide(BuildContext context) async {
// // // // //   final pending = await getPendingRide();
// // // // //   if (pending != null) {
// // // // //     Navigator.push(
// // // // //       context,
// // // // //       PageRouteBuilder(
// // // // //         opaque: false,
// // // // //         pageBuilder: (_, __, ___) => RideAlertScreen(
// // // // //           rideId: pending['rideId'],
// // // // //           rider: pending['rider'],
// // // // //           pickupName: pending['pickupName'],
// // // // //           destinationName: pending['destinationName'],
// // // // //           pickupLat: pending['pickupLat'],
// // // // //           pickupLng: pending['pickupLng'],
// // // // //           destLat: pending['destLat'],
// // // // //           destLng: pending['destLng'],
// // // // //         ),
// // // // //       ),
// // // // //     );
// // // // //   }
// // // // // }

// // // // // class MyApp extends ConsumerWidget {
// // // // //   final Map<String, dynamic>? pendingRide;

// // // // //   const MyApp({super.key, this.pendingRide});

// // // // //   @override
// // // // //   Widget build(BuildContext context, WidgetRef ref) {
// // // // //     return MaterialApp.router(
// // // // //       debugShowCheckedModeBanner: false,
// // // // //       title: 'amini driver',
// // // // //       routerConfig: router, //use your router here
// // // // //       builder: (context, child) {
// // // // //         if (pendingRide != null) {
// // // // //           return RideAlertScreen(
// // // // //             rideId: pendingRide!['rideId'],
// // // // //             rider: pendingRide!['rider'] ?? '',
// // // // //             pickupName: pendingRide!['pickupName'] ?? '',
// // // // //             destinationName: pendingRide!['destinationName'] ?? '',
// // // // //             pickupLat: (pendingRide!['pickupLat'] as num?)?.toDouble() ?? 0.0,
// // // // //             pickupLng: (pendingRide!['pickupLng'] as num?)?.toDouble() ?? 0.0,
// // // // //             destLat: (pendingRide!['destLat'] as num?)?.toDouble() ?? 0.0,
// // // // //             destLng: (pendingRide!['destLng'] as num?)?.toDouble() ?? 0.0,
// // // // //           );
// // // // //         }
// // // // //         return child!;
// // // // //       },
// // // // //       //routerConfig: router,
// // // // //     );
// // // // //   }
// // // // // }
// // // // // // class MyApp extends ConsumerWidget {
// // // // // //   final Map<String, dynamic>? pendingRide;

// // // // // //   const MyApp({super.key, this.pendingRide});
// // // // // //   //const MyApp({super.key});

// // // // // //   @override
// // // // // //   Widget build(BuildContext context, WidgetRef ref) {
// // // // // //     return MaterialApp.router(
// // // // // //       debugShowCheckedModeBanner: false,
// // // // // //       title: 'amini driver',
// // // // // //       routerConfig: router,
// // // // // //     );
// // // // // //   }
// // // // // // }
// // // // // // // class MyApp extends ConsumerWidget {
// // // // // //   final Map<String, dynamic>? pendingRide;

// // // // // //   const MyApp({super.key, this.pendingRide});

// // // // // //   @override
// // // // // //   Widget build(BuildContext context, WidgetRef ref) {
// // // // // //     return MaterialApp(
// // // // // //       debugShowCheckedModeBanner: false,
// // // // // //       title: 'amini driver',
// // // // // //       navigatorKey: navigatorKey, // ✅ Works with MaterialApp
// // // // // //       onGenerateRoute: router.con, // ✅ connect your router
// // // // // //       builder: (context, child) {
// // // // // //         // 🔑 If there’s a saved pending ride, show RideAlertScreen first
// // // // // //         if (pendingRide != null) {
// // // // // //           return RideAlertScreen(
// // // // // //             rideId: pendingRide!['rideId'],
// // // // // //             rider: pendingRide!['rider'] ?? '',
// // // // // //             pickupName: pendingRide!['pickupName'] ?? '',
// // // // // //             destinationName: pendingRide!['destinationName'] ?? '',
// // // // // //             pickupLat: (pendingRide!['pickupLat'] as num?)?.toDouble() ?? 0.0,
// // // // // //             pickupLng: (pendingRide!['pickupLng'] as num?)?.toDouble() ?? 0.0,
// // // // // //             destLat: (pendingRide!['destLat'] as num?)?.toDouble() ?? 0.0,
// // // // // //             destLng: (pendingRide!['destLng'] as num?)?.toDouble() ?? 0.0,
// // // // // //           );
// // // // // //         }
// // // // // //         return child!;
// // // // // //       },
// // // // // //     );
// // // // // //   }
// // // // // // }

// // // // // // import 'dart:async';
// // // // // // import 'dart:convert';
// // // // // // import 'package:aminidriver/Container/utils/api_constant.dart';
// // // // // // import 'package:aminidriver/Container/utils/pending_ride_storage.dart';
// // // // // // import 'package:aminidriver/Onboarding/driver_location_live.dart';
// // // // // // import 'package:aminidriver/Onboarding/ride_alert.dart';
// // // // // // import 'package:aminidriver/Onboarding/trip_detail_screen.dart';
// // // // // // import 'package:aminidriver/View/Routes/app_routes.dart';
// // // // // // import 'package:firebase_auth/firebase_auth.dart';
// // // // // // import 'package:firebase_core/firebase_core.dart';
// // // // // // import 'package:firebase_messaging/firebase_messaging.dart';
// // // // // // import 'package:flutter/material.dart';
// // // // // // import 'package:flutter_riverpod/flutter_riverpod.dart';
// // // // // // import 'package:geolocator/geolocator.dart';
// // // // // // import 'package:http/http.dart' as http;
// // // // // // import 'firebase_options.dart';

// // // // // // final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// // // // // // /// Background message handler
// // // // // // Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
// // // // // //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
// // // // // //   print("🔙 Handling background message: ${message.messageId}");
// // // // // // }

// // // // // // void main() async {
// // // // // //   WidgetsFlutterBinding.ensureInitialized();
// // // // // //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

// // // // // //   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

// // // // // //   setupFCM();
// // // // // //   DriverLocationService().startSendingLocation();
// // // // // //   final ride = await getPendingRide();
// // // // // //   runApp(const ProviderScope(child: MyApp())); // <-- MyApp constructor
// // // // // // }

// // // // // // void setupFCM() {
// // // // // //   FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
// // // // // //     _openRideScreen(message);
// // // // // //   });

// // // // // //   FirebaseMessaging.instance.getInitialMessage().then((message) {
// // // // // //     if (message != null) _openRideScreen(message);
// // // // // //   });
// // // // // // }

// // // // // // void _openRideScreen(RemoteMessage message) {
// // // // // //   final data = message.data;

// // // // // //   if (data.containsKey('rideId')) {
// // // // // //     navigatorKey.currentState?.push(
// // // // // //       MaterialPageRoute(
// // // // // //         builder:
// // // // // //             (context) => RideAlertScreen(
// // // // // //               rideId: data['rideId'],
// // // // // //               rider: data['rider'] ?? '',
// // // // // //               pickupName: data['pickupName'] ?? '',
// // // // // //               destinationName: data['destinationName'] ?? '',
// // // // // //               pickupLat: double.tryParse(data['pickupLat'] ?? '') ?? 0.0,
// // // // // //               pickupLng: double.tryParse(data['pickupLng'] ?? '') ?? 0.0,
// // // // // //               destLat: double.tryParse(data['destLat'] ?? '') ?? 0.0,
// // // // // //               destLng: double.tryParse(data['destLng'] ?? '') ?? 0.0,
// // // // // //             ),
// // // // // //       ),
// // // // // //     );
// // // // // //   }
// // // // // // }

// // // // // // class MyApp extends ConsumerWidget {
// // // // // //   const MyApp({super.key});

// // // // // //   @override
// // // // // //   Widget build(BuildContext context, WidgetRef ref) {
// // // // // //     return MaterialApp.router(
// // // // // //       debugShowCheckedModeBanner: false,
// // // // // //       title: 'amini driver',
// // // // // //       routerConfig: router,
// // // // // //     );
// // // // // //   }
// // // // // // }

// // // // // // /// MyApp definition
// // // // // // // class MyApp extends ConsumerWidget {
// // // // // // //   const MyApp({super.key});

// // // // // // //   @override
// // // // // // //   Widget build(BuildContext context, WidgetRef ref) {
// // // // // // //     return MaterialApp(
// // // // // // //       title: 'Amini Driver',
// // // // // // //       debugShowCheckedModeBanner: false,
// // // // // // //       navigatorKey: navigatorKey,
// // // // // // //     //  theme: ThemeData(primarySwatch: Colors.green),
// // // // // // //       home: const Scaffold(
// // // // // // //         body: Center(child: Text("Welcome to Amini Driver")),
// // // // // // //       ),
// // // // // // //     );
// // // // // // //   }
// // // // // // // }

// // // // // // // import 'package:aminidriver/Onboarding/driver_location_live.dart';
// // // // // // // import 'package:firebase_core/firebase_core.dart';
// // // // // // // import 'package:firebase_messaging/firebase_messaging.dart';
// // // // // // // import 'package:flutter/material.dart';
// // // // // // // import 'package:flutter_riverpod/flutter_riverpod.dart';
// // // // // // // import 'View/Routes/app_routes.dart';
// // // // // // // import 'firebase_options.dart';

// // // // // // // /// Background message handler
// // // // // // // Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
// // // // // // //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
// // // // // // //   print("🔙 Handling background message: ${message.messageId}");
// // // // // // // }

// // // // // // // Future<void> main() async {
// // // // // // //   WidgetsFlutterBinding.ensureInitialized();
// // // // // // //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

// // // // // // //   // Register background message handler
// // // // // // //   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

// // // // // // //   //FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

// // // // // // //   RemoteMessage? initialMessage =
// // // // // // //       await FirebaseMessaging.instance.getInitialMessage();
// // // // // // //   handleInitialMessage(initialMessage);
// // // // // // //   DriverLocationService().startSendingLocation();
// // // // // // //   runApp(const ProviderScope(child: MyApp()));
// // // // // // // }

// // // // // // // class MyApp extends ConsumerWidget {
// // // // // // //   const MyApp({super.key});

// // // // // // //   @override
// // // // // // //   Widget build(BuildContext context, WidgetRef ref) {
// // // // // // //     return MaterialApp.router(
// // // // // // //       debugShowCheckedModeBanner: false,
// // // // // // //       title: 'amini driver',
// // // // // // //       routerConfig: router,
// // // // // // //     );
// // // // // // //   }
// // // // // // // }

// // // // // // // RemoteMessage? initialRideMessage;

// // // // // // // void firebaseMessagingBackgroundHandler(RemoteMessage message) async {
// // // // // // //   // Handle background message
// // // // // // // }
// // // // // // // void handleInitialMessage(RemoteMessage? message) {
// // // // // // //   if (message != null && message.data.containsKey('rideId')) {
// // // // // // //     initialRideMessage = message;
// // // // // // //   }
// // // // // // // }
// // // // // // // //import 'package:aminidriver/Container/utils/firebase_messaging.dart';
// // // // // // // // import 'package:aminidriver/Container/utils/message_service.dart';
// // // // // // // // import 'package:firebase_messaging/firebase_messaging.dart';
// // // // // // // // import 'package:flutter/material.dart';
// // // // // // // // import 'package:flutter_riverpod/flutter_riverpod.dart';
// // // // // // // // import 'View/Routes/app_routes.dart';
// // // // // // // // import 'package:firebase_core/firebase_core.dart';
// // // // // // // // import 'firebase_options.dart';

// // // // // // // // //final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
// // // // // // // // Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
// // // // // // // //   await Firebase.initializeApp();
// // // // // // // //   print("🔙 Handling background message: ${message.messageId}");
// // // // // // // // }

// // // // // // // // Future<void> main() async {
// // // // // // // //   WidgetsFlutterBinding.ensureInitialized();
// // // // // // // //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
// // // // // // // //   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

// // // // // // // //   final messagingService = MessagingService();
// // // // // // // //   await messagingService.init();
// // // // // // // //   runApp(const ProviderScope(child: MyApp()));
// // // // // // // // }

// // // // // // // // class MyApp extends StatelessWidget {
// // // // // // // //   const MyApp({super.key});

// // // // // // // //   @override
// // // // // // // //   Widget build(BuildContext context) {
// // // // // // // //     return MaterialApp.router(
// // // // // // // //       debugShowCheckedModeBanner: false,
// // // // // // // //       title: 'aminidriver',
// // // // // // // //       routerConfig: router,
// // // // // // // //       //navigatorKey: navigatorKey,
// // // // // // // //     );
// // // // // // // //   }
// // // // // // // // }

// // // // // // // // //import 'package:aminidriver/View/Screens/Auth_Screens/Register_Screen/vehicle_registration_screen';
// // // // // // // // import 'package:aminidriver/Container/utils/firebase_messaging.dart';
// // // // // // // // import 'package:flutter/material.dart';
// // // // // // // // import 'package:flutter_riverpod/flutter_riverpod.dart';
// // // // // // // // import 'View/Routes/app_routes.dart';
// // // // // // // // //import 'View/Themes/app_theme.dart';
// // // // // // // // import 'package:firebase_core/firebase_core.dart';

// // // // // // // // import 'firebase_options.dart';

// // // // // // // // Future<void> main() async {
// // // // // // // //   WidgetsFlutterBinding.ensureInitialized();
// // // // // // // //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
// // // // // // // //   final MessagingService _messagingService = MessagingService();
// // // // // // // //   await _messagingService.init();
// // // // // // // //   runApp(const ProviderScope(child: MyApp()));
// // // // // // // // }

// // // // // // // // final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// // // // // // // // class MyApp extends StatelessWidget {
// // // // // // // //   const MyApp({super.key});
// // // // // // // //   @override
// // // // // // // //   Widget build(BuildContext context) {
// // // // // // // //     return MaterialApp.router(
// // // // // // // //       debugShowCheckedModeBanner: false,
// // // // // // // //       title: 'aminidriver',
// // // // // // // //       //themeMode: ThemeMode.system,
// // // // // // // //       //theme: appTheme,
// // // // // // // //       //runApp(const MaterialApp(home: VehicleOnboardingScreen()));
// // // // // // // //       //darkTheme: appDarkTheme,
// // // // // // // //       routerConfig: router,
// // // // // // // //      // navigatorKey: navigatorKey,
// // // // // // // //     );

// // // // // // // //     // return MaterialApp.router(
// // // // // // // //     //   debugShowCheckedModeBanner: false,
// // // // // // // //     //   title: 'aminidriver',
// // // // // // // //     //   theme: appTheme,
// // // // // // // //     //   routerConfig: router,
// // // // // // // //     // );
// // // // // // // //   }
// // // // // // // // }

// // // // // // // // // import 'package:flutter/material.dart';

// // // // // // // // // void main() {
// // // // // // // // //   runApp(const MyApp());
// // // // // // // // // }

// // // // // // // // // class MyApp extends StatelessWidget {
// // // // // // // // //   const MyApp({super.key});

// // // // // // // // //   // This widget is the root of your application.
// // // // // // // // //   @override
// // // // // // // // //   Widget build(BuildContext context) {
// // // // // // // // //     return MaterialApp(
// // // // // // // // //       title: 'Flutter Demo',
// // // // // // // // //       theme: ThemeData(
// // // // // // // // //         // This is the theme of your application.
// // // // // // // // //         //
// // // // // // // // //         // TRY THIS: Try running your application with "flutter run". You'll see
// // // // // // // // //         // the application has a purple toolbar. Then, without quitting the app,
// // // // // // // // //         // try changing the seedColor in the colorScheme below to Colors.green
// // // // // // // // //         // and then invoke "hot reload" (save your changes or press the "hot
// // // // // // // // //         // reload" button in a Flutter-supported IDE, or press "r" if you used
// // // // // // // // //         // the command line to start the app).
// // // // // // // // //         //
// // // // // // // // //         // Notice that the counter didn't reset back to zero; the application
// // // // // // // // //         // state is not lost during the reload. To reset the state, use hot
// // // // // // // // //         // restart instead.
// // // // // // // // //         //
// // // // // // // // //         // This works for code too, not just values: Most code changes can be
// // // // // // // // //         // tested with just a hot reload.
// // // // // // // // //         colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
// // // // // // // // //       ),
// // // // // // // // //       home: const MyHomePage(title: 'Flutter Demo Home Page'),
// // // // // // // // //     );
// // // // // // // // //   }
// // // // // // // // // }

// // // // // // // // // class MyHomePage extends StatefulWidget {
// // // // // // // // //   const MyHomePage({super.key, required this.title});

// // // // // // // // //   // This widget is the home page of your application. It is stateful, meaning
// // // // // // // // //   // that it has a State object (defined below) that contains fields that affect
// // // // // // // // //   // how it looks.

// // // // // // // // //   // This class is the configuration for the state. It holds the values (in this
// // // // // // // // //   // case the title) provided by the parent (in this case the App widget) and
// // // // // // // // //   // used by the build method of the State. Fields in a Widget subclass are
// // // // // // // // //   // always marked "final".

// // // // // // // // //   final String title;

// // // // // // // // //   @override
// // // // // // // // //   State<MyHomePage> createState() => _MyHomePageState();
// // // // // // // // // }

// // // // // // // // // class _MyHomePageState extends State<MyHomePage> {
// // // // // // // // //   int _counter = 0;

// // // // // // // // //   void _incrementCounter() {
// // // // // // // // //     setState(() {
// // // // // // // // //       // This call to setState tells the Flutter framework that something has
// // // // // // // // //       // changed in this State, which causes it to rerun the build method below
// // // // // // // // //       // so that the display can reflect the updated values. If we changed
// // // // // // // // //       // _counter without calling setState(), then the build method would not be
// // // // // // // // //       // called again, and so nothing would appear to happen.
// // // // // // // // //       _counter++;
// // // // // // // // //     });
// // // // // // // // //   }

// // // // // // // // //   @override
// // // // // // // // //   Widget build(BuildContext context) {
// // // // // // // // //     // This method is rerun every time setState is called, for instance as done
// // // // // // // // //     // by the _incrementCounter method above.
// // // // // // // // //     //
// // // // // // // // //     // The Flutter framework has been optimized to make rerunning build methods
// // // // // // // // //     // fast, so that you can just rebuild anything that needs updating rather
// // // // // // // // //     // than having to individually change instances of widgets.
// // // // // // // // //     return Scaffold(
// // // // // // // // //       appBar: AppBar(
// // // // // // // // //         // TRY THIS: Try changing the color here to a specific color (to
// // // // // // // // //         // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
// // // // // // // // //         // change color while the other colors stay the same.
// // // // // // // // //         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
// // // // // // // // //         // Here we take the value from the MyHomePage object that was created by
// // // // // // // // //         // the App.build method, and use it to set our appbar title.
// // // // // // // // //         title: Text(widget.title),
// // // // // // // // //       ),
// // // // // // // // //       body: Center(
// // // // // // // // //         // Center is a layout widget. It takes a single child and positions it
// // // // // // // // //         // in the middle of the parent.
// // // // // // // // //         child: Column(
// // // // // // // // //           // Column is also a layout widget. It takes a list of children and
// // // // // // // // //           // arranges them vertically. By default, it sizes itself to fit its
// // // // // // // // //           // children horizontally, and tries to be as tall as its parent.
// // // // // // // // //           //
// // // // // // // // //           // Column has various properties to control how it sizes itself and
// // // // // // // // //           // how it positions its children. Here we use mainAxisAlignment to
// // // // // // // // //           // center the children vertically; the main axis here is the vertical
// // // // // // // // //           // axis because Columns are vertical (the cross axis would be
// // // // // // // // //           // horizontal).
// // // // // // // // //           //
// // // // // // // // //           // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
// // // // // // // // //           // action in the IDE, or press "p" in the console), to see the
// // // // // // // // //           // wireframe for each widget.
// // // // // // // // //           mainAxisAlignment: MainAxisAlignment.center,
// // // // // // // // //           children: <Widget>[
// // // // // // // // //             const Text('You have pushed the button this many times:'),
// // // // // // // // //             Text(
// // // // // // // // //               '$_counter',
// // // // // // // // //               style: Theme.of(context).textTheme.headlineMedium,
// // // // // // // // //             ),
// // // // // // // // //           ],
// // // // // // // // //         ),
// // // // // // // // //       ),
// // // // // // // // //       floatingActionButton: FloatingActionButton(
// // // // // // // // //         onPressed: _incrementCounter,
// // // // // // // // //         tooltip: 'Increment',
// // // // // // // // //         child: const Icon(Icons.add),
// // // // // // // // //       ), // This trailing comma makes auto-formatting nicer for build methods.
// // // // // // // // //     );
// // // // // // // // //   }
// // // // // // // // // }
// // // // // // // // import 'package:flutter/material.dart';
// // // // // // // // import 'package:firebase_core/firebase_core.dart';
// // // // // // // // import 'firebase_options.dart';
// // // // // // // // import 'package:cloud_firestore/cloud_firestore.dart';
// // // // // // // // import 'package:firebase_auth/firebase_auth.dart';
// // // // // // // // import 'package:http/http.dart' as http;
// // // // // // // // import 'dart:convert';

// // // // // // // // void main() async {
// // // // // // // //   WidgetsFlutterBinding.ensureInitialized();
// // // // // // // //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
// // // // // // // //   runApp(const MaterialApp(home: RegisterDriverScreen()));
// // // // // // // // }

// // // // // // // // class RegisterDriverScreen extends StatelessWidget {
// // // // // // // //   const RegisterDriverScreen({super.key});

// // // // // // // //   @override
// // // // // // // //   Widget build(BuildContext context) {
// // // // // // // //     return Scaffold(
// // // // // // // //       appBar: AppBar(title: const Text("Register Driver")),
// // // // // // // //       body: Center(
// // // // // // // //         child: ElevatedButton(
// // // // // // // //           onPressed: () {
// // // // // // // //             registerDriver(
// // // // // // // //               name: "Kevin Otieno",
// // // // // // // //               email: "ibrahimomar@darkaez.co.ke",
// // // // // // // //               password: "ba4nyibA,", // ensure this is valid
// // // // // // // //               phone: "+254712345678",
// // // // // // // //               category: "Matatu",
// // // // // // // //             );
// // // // // // // //           },
// // // // // // // //           child: const Text("Register Driver"),
// // // // // // // //         ),
// // // // // // // //       ),
// // // // // // // //     );
// // // // // // // //   }
// // // // // // // // }

// // // // // // // // Future<void> registerDriver({
// // // // // // // //   required String name,
// // // // // // // //   required String email,
// // // // // // // //   required String password,
// // // // // // // //   required String phone,
// // // // // // // //   required String category,
// // // // // // // // }) async {
// // // // // // // //   UserCredential userCredential;

// // // // // // // //   // 🔐 Step 1: Create user in Firebase Auth
// // // // // // // //   try {
// // // // // // // //     userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
// // // // // // // //       email: email,
// // // // // // // //       password: password,
// // // // // // // //     );
// // // // // // // //     debugPrint("✅ FirebaseAuth: User created");
// // // // // // // //   } on FirebaseAuthException catch (e) {
// // // // // // // //     if (e.code == 'email-already-in-use') {
// // // // // // // //       debugPrint("⚠️ User already exists, trying to sign in...");
// // // // // // // //       userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
// // // // // // // //         email: email,
// // // // // // // //         password: password,
// // // // // // // //       );
// // // // // // // //     } else {
// // // // // // // //       debugPrint("❌ FirebaseAuth error: ${e.message}");
// // // // // // // //       return;
// // // // // // // //     }
// // // // // // // //   } catch (e) {
// // // // // // // //     debugPrint("❌ Unexpected FirebaseAuth error: $e");
// // // // // // // //     return;
// // // // // // // //   }

// // // // // // // //   final token = await userCredential.user?.getIdToken();

// // // // // // // //   // 📦 Step 2: Prepare driver data
// // // // // // // //   final driverData = {
// // // // // // // //     "name": name,
// // // // // // // //     "email": email,
// // // // // // // //     "phone": phone,
// // // // // // // //     "category": category,
// // // // // // // //     "createdAt": FieldValue.serverTimestamp(),
// // // // // // // //   };

// // // // // // // //   // 📝 Step 3: Post to Firestore
// // // // // // // //   try {
// // // // // // // //     await FirebaseFirestore.instance.collection("drivers").add(driverData);
// // // // // // // //     debugPrint("✅ Firestore: Driver data added");
// // // // // // // //   } catch (e) {
// // // // // // // //     debugPrint("❌ Firestore error: $e");
// // // // // // // //   }

// // // // // // // //   // 🌐 Step 4: Post to backend API
// // // // // // // //   try {
// // // // // // // //     final response = await http.post(
// // // // // // // //       Uri.parse("http://192.168.27.145:7047/api/auth/firebase-login"),
// // // // // // // //       headers: {
// // // // // // // //         'Content-Type': 'application/json',
// // // // // // // //         'Authorization': 'Bearer $token',
// // // // // // // //       },
// // // // // // // //       body: jsonEncode({
// // // // // // // //         "fullname": name,
// // // // // // // //         "email": email,
// // // // // // // //         "phone": phone,
// // // // // // // //         "role": category,
// // // // // // // //         "token": token,
// // // // // // // //       }),
// // // // // // // //     );

// // // // // // // //     if (response.statusCode == 200 || response.statusCode == 201) {
// // // // // // // //       debugPrint("✅ Backend: Driver posted");
// // // // // // // //     } else {
// // // // // // // //       debugPrint("❌ Backend failed: ${response.statusCode} - ${response.body}");
// // // // // // // //     }
// // // // // // // //   } catch (e) {
// // // // // // // //     debugPrint("❌ Backend error: $e");
// // // // // // // //   }
// // // // // // // // }
