import 'dart:async';

import 'package:aminidriver/Container/utils/pending_ride_storage.dart';
import 'package:aminidriver/Onboarding/ride_alert.dart';
import 'package:aminidriver/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RideAlertService {
  static final RideAlertService _instance = RideAlertService._internal();
  factory RideAlertService() => _instance;
  RideAlertService._internal();

  StreamSubscription<DatabaseEvent>? _rideSubscription;
  bool _isAlertVisible = false;

  void start(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _rideSubscription = FirebaseDatabase.instance
        .ref('rides')
        .orderByChild('driverId')
        .equalTo(user.uid)
        .onValue
        .listen((event) async {
          final data = event.snapshot.value as Map<dynamic, dynamic>?;
          if (data == null) return;

          // Find the first pending ride
          // final pendingRideEntry = data.entries.firstWhere(
          //   (e) => e.value['status'] == 'pending',
          //   orElse: () => null,
          // );

          // if (pendingRideEntry != null && !_isAlertVisible) {
          //   _isAlertVisible = true;

          //   final ride = pendingRideEntry.value;
          //   final pickup = ride['pickup'];
          //   final destination = ride['destination'];
          //   final rider = ride['riderName'] ?? 'Rider';

          //   // Save ride temporarily if you use pending storage
          //   await savePendingRide(pendingRideEntry.key, ride);

          //   if (context.mounted) {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(
          //         builder: (_) => RideAlertScreen(
          //           rideId: pendingRideEntry.key,
          //           rider: rider,
          //           pickupName: pickup['name'],
          //           destinationName: destination['name'],
          //           pickupLat: pickup['lat'],
          //           pickupLng: pickup['lng'],
          //           destLat: destination['lat'],
          //           destLng: destination['lng'],
          //         ),
          //       ),
          //     ).then((_) {
          //       _isAlertVisible = false; // allow next alert
          //     });
          //   }
          final pendingRides =
              data.entries
                  .where((e) => e.value['status'] == 'pending')
                  .toList();

          if (pendingRides.isNotEmpty && !_isAlertVisible) {
            final pendingRideEntry = pendingRides.first;

            _isAlertVisible = true;

            final ride = pendingRideEntry.value;
            final pickup = ride['pickup'];
            final destination = ride['destination'];
            final rider = ride['riderName'] ?? 'Rider';

            // Save pending ride
            await savePendingRide(pendingRideEntry.key, 300);

            final context = navigatorKey.currentContext;
            if (context != null) {
              context
                  .push(
                    '/ride-alert',
                    extra: {
                      "rideId": pendingRideEntry.key,
                      "rider": rider,
                      "pickupName": pickup['name'],
                      "destinationName": destination['name'],
                      "pickupLat": pickup['lat'],
                      "pickupLng": pickup['lng'],
                      "destLat": destination['lat'],
                      "destLng": destination['lng'],
                    },
                  )
                  .then((_) => _isAlertVisible = false);
            } else {
              _isAlertVisible = false;
            }
          }
        });
  }

  void stop() {
    _rideSubscription?.cancel();
    _rideSubscription = null;
  }
}
