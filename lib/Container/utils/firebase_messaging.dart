import 'package:aminidriver/Container/utils/pending_ride_storage.dart';
import 'package:aminidriver/Onboarding/ride_alert.dart';
import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_providers.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MessagingService {
  final _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> init(BuildContext context, WidgetRef ref) async {
    // Request permission on iOS
    await _firebaseMessaging.requestPermission();

    /// Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // handleMessage(context, ref, message);
      _showLocalNotification(message);
    });

    /// Handle messages when app is in background and user taps notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      handleMessage(context, ref, message);
    });

    /// Handle messages when app is terminated and launched via notification
    RemoteMessage? initialMessage =
        await _firebaseMessaging.getInitialMessage();

    if (initialMessage != null) {
      handleMessage(context, ref, initialMessage);
    }
  }

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    final android = notification?.android;

    if (notification != null && android != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel', // Must match your NotificationChannel ID
            'High Importance Notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        payload: message.data['rideId'], // optional
      );
    }
  }

  Future<void> checkInitialMessage(BuildContext context, WidgetRef ref) async {
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      // App was opened via a notification when it was terminated
      print("📦 App opened from terminated state via notification");

      final messagingService = MessagingService();
      messagingService.handleMessage(context, ref, initialMessage);
      //messagingService.handleMessage(initialMessage, context, ref);
    }
  }

  void handleMessage(
    BuildContext context,
    WidgetRef ref,
    RemoteMessage message,
  ) async {
    final isOnline = ref.read(homeScreenIsDriverActiveProvider);
    if (!isOnline) return;

    final data = message.data;

    final rideId = data['rideId'];
    final rider = data['rider'];
    final pickup =
        data['pickupName'] ?? message.notification?.title ?? 'New Ride';
    final drop = data['destinationName'] ?? message.notification?.body ?? '';
    final pickupLat = double.tryParse(data['pickupLat'] ?? '');
    final pickupLng = double.tryParse(data['pickupLng'] ?? '');
    final destLat = double.tryParse(data['destLat'] ?? '');
    final destLng = double.tryParse(data['destLng'] ?? '');

    if (pickupLat == null ||
        pickupLng == null ||
        destLat == null ||
        destLng == null) {
      print('❌ Invalid or missing coordinates in message data');
      return;
    }

    if (rideId != null && pickup.isNotEmpty && drop.isNotEmpty) {
      // 🔹 Save pending ride for 5 minutes
      await savePendingRide({
        'rideId': rideId,
        'rider': rider,
        'pickupName': pickup,
        'destinationName': drop,
        'pickupLat': pickupLat,
        'pickupLng': pickupLng,
        'destLat': destLat,
        'destLng': destLng,
      }, 300);

      // 🔹 Navigate immediately if app is active
      Future.delayed(Duration.zero, () {
        Navigator.push(
          context,
          PageRouteBuilder(
            opaque: false,
            pageBuilder:
                (_, __, ___) => RideAlertScreen(
                  rideId: rideId,
                  rider: rider,
                  pickupName: pickup,
                  destinationName: drop,
                  pickupLat: pickupLat,
                  pickupLng: pickupLng,
                  destLat: destLat,
                  destLng: destLng,
                ),
          ),
        );
      });
    }
  }

  // void handleMessage(
  //   BuildContext context,
  //   WidgetRef ref,
  //   RemoteMessage message,
  // ) {
  //   final isOnline = ref.read(homeScreenIsDriverActiveProvider);
  //   if (!isOnline) return;

  //   final data = message.data;

  //   final rideId = data['rideId'];
  //   final rider = data['rider'];
  //   final pickup =
  //       data['pickupName'] ?? message.notification?.title ?? 'New Ride';
  //   final drop = data['destinationName'] ?? message.notification?.body ?? '';
  //   final pickupLat = double.tryParse(data['pickupLat'] ?? '');
  //   final pickupLng = double.tryParse(data['pickupLng'] ?? '');
  //   final destLat = double.tryParse(data['destLat'] ?? '');
  //   final destLng = double.tryParse(data['destLng'] ?? '');

  //   if (pickupLat == null ||
  //       pickupLng == null ||
  //       destLat == null ||
  //       destLng == null) {
  //     print('❌ Invalid or missing coordinates in message data');
  //     return;
  //   }
  //   if (rideId != null && pickup.isNotEmpty && drop.isNotEmpty) {
  //     Future.delayed(Duration.zero, () {
  //       Navigator.push(
  //         context,
  //         PageRouteBuilder(
  //           opaque: false,
  //           pageBuilder:
  //               (_, __, ___) => RideAlertScreen(
  //                 rideId: rideId,
  //                 rider: rider,
  //                 pickupName: pickup,
  //                 destinationName: drop,
  //                 pickupLat: pickupLat,
  //                 pickupLng: pickupLng,
  //                 destLat: destLat,
  //                 destLng: destLng,
  //               ),
  //         ),
  //       );
  //     });
  //   }
  // }
}


  // void _handleMessage(
  //   BuildContext context,
  //   WidgetRef ref,
  //   RemoteMessage message,
  // ) {
  //   final isOnline = ref.read(homeScreenIsDriverActiveProvider);
  //   if (!isOnline) return;

  //   final rideId = message.data['rideId'];
  //   final pickup = message.notification?.title ?? 'New Ride';
  //   final drop = message.notification?.body ?? '';
  //   final pickupLat = double.tryParse(message.data['pickupLat'] ?? '');

  //   if (pickupLat == null) {
  //     print('Missing or invalid pickupLat');
  //     return;
  //   }
  //   final pickupLng = double.tryParse(message.data['pickupLng'] ?? '');

  //   if (pickupLng == null) {
  //     print('Missing or invalid pickupLng');
  //     return;
  //   }
  //   final destLat = double.tryParse(message.data['destLat'] ?? '');

  //   if (destLat == null) {
  //     print('Missing or invalid destLat');
  //     return;
  //   }
  //   final destLng = double.tryParse(message.data['destLng'] ?? '');

  //   if (destLng == null) {
  //     print('Missing or invalid destLng');
  //     return;
  //   }
  //   Navigator.push(
  //     context,
  //     PageRouteBuilder(
  //       opaque: false,
  //       pageBuilder:
  //           (_, __, ___) => RideAlertPopup(
  //             rideId: rideId,
  //             pickupName: pickup,
  //             destinationName: drop,
  //             pickupLat: pickupLat,
  //             pickupLng: pickupLng,
  //             destLat: destLat,
  //             destLng: destLng,
  //             onAccept: () => Navigator.pop(context),
  //             onReject: () => Navigator.pop(context),
  //           ),
  //     ),
  //   );
  // }

  