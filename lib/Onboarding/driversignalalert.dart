// import 'package:aminidriver/Container/utils/keys.dart';
// import 'package:aminidriver/Onboarding/ride_alert.dart';
// import 'package:signalr_core/signalr_core.dart';
// import 'package:flutter/material.dart';

// class DriverSignalRService {
//   static final DriverSignalRService _instance =
//       DriverSignalRService._internal();
//   factory DriverSignalRService() => _instance;
//   DriverSignalRService._internal();

//   late HubConnection hubConnection;

//   void init(BuildContext context) async {
//     hubConnection =
//         HubConnectionBuilder()
//             .withUrl('$baseUrldoc/hubs/location') // your driver API URL
//             .withAutomaticReconnect()
//             .build();

//     // Listen for ride requests
//     hubConnection.on('NewRideRequest', (arguments) {
//       if (arguments != null && arguments.isNotEmpty) {
//         final rideData = Map<String, dynamic>.from(arguments[0]);
//         print("New ride request: ${rideData['rideId']}");

//         // Open the RideAlertScreen
//         WidgetsBinding.instance.addPostFrameCallback((_) {
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder:
//                   (_) => RideAlertScreen(
//                     rideId: rideData['rideId'].toString(),
//                     rideRequestId: rideData['rideRequestId']?.toString() ?? '',
//                     rider: rideData['rider'] ?? '',
//                     pickupName: rideData['pickup'] ?? '',
//                     destinationName: rideData['destination'] ?? '',
//                     pickupLat:
//                         double.tryParse('${rideData['pickupLat']}') ?? 0.0,
//                     pickupLng:
//                         double.tryParse('${rideData['pickupLng']}') ?? 0.0,
//                     destLat: double.tryParse('${rideData['destLat']}') ?? 0.0,
//                     destLng: double.tryParse('${rideData['destLng']}') ?? 0.0,
//                   ),
//             ),
//           );
//         });
//       }
//     });

//     await hubConnection.start();
//     await hubConnection.invoke('JoinDriverGroup');
//   }
// }
