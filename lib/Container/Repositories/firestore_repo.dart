import 'package:flutter/material.dart';
import 'package:geoflutterfire2/geoflutterfire2.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Driver {
  final String id;
  final String name;
  final String email;

  Driver({required this.id, required this.name, required this.email});

  // Factory constructor to create Driver from Firestore data
  factory Driver.fromMap(Map<String, dynamic> data) {
    return Driver(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      email: data['email'] ?? '',
    );
  }
}

class FirestoreRepo {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> setDriverLocationStatus(BuildContext context, GeoFirePoint? location) async {
    try {
      // Get the current user ID from Firebase Auth
      final userId = _auth.currentUser?.uid;

      if (userId == null) {
        throw Exception("User not authenticated");
      }

      final driverRef = _firestore.collection('drivers').doc(userId);

      if (location != null) {
        await driverRef.set({
          'position': location.data,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        // Remove location if offline
        await driverRef.update({
          'position': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint("Error updating driver location: $e");
      rethrow;
    }
  }

  /// Set Driver's Status (Online/Offline)
  Future<void> setDriverStatus(BuildContext context, String status) async {
    try {
      // Get the current user ID from Firebase Auth
      final userId = _auth.currentUser?.uid;

      if (userId == null) {
        throw Exception("User not authenticated");
      }

      final driverRef = _firestore.collection('drivers').doc(userId);
      await driverRef.set({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error setting driver status: $e");
      rethrow;
    }
  }

  Future<void> getDriverDetails(BuildContext context) async {
    try {
      // Get the current user ID from Firebase Auth
      final userId = _auth.currentUser?.uid;

      if (userId == null) {
        throw Exception("User not authenticated");
      }

      // Assuming you have a collection 'drivers' in your Firestore
      final driverSnapshot = await _firestore.collection('drivers').doc(userId).get();

      if (driverSnapshot.exists) {
        // Process the driver data, for example:
        final driverData = driverSnapshot.data();
        Driver driver = Driver.fromMap(driverData ?? {});  // Assuming a Driver model exists
        // You can update the UI or state as needed here
        debugPrint('Driver details: ${driver.name}');
      } else {
        debugPrint('Driver not found');
      }
    } catch (e) {
      debugPrint('Error fetching driver details: $e');
    }
  }
}



// // import 'package:aminidriver/Model/driver_info_model.dart';
// // import 'package:cloud_firestore/cloud_firestore.dart';
// // import 'package:firebase_auth/firebase_auth.dart';
// // import 'package:flutter/material.dart';
// // import 'package:flutter_riverpod/flutter_riverpod.dart';
// // import 'package:geoflutterfire2/geoflutterfire2.dart';

// // import '../utils/error_notification.dart';

// // final globalFirestoreRepoProvider = Provider<AddFirestoreData>((ref) {
// //   return AddFirestoreData();
// // });

// // class AddFirestoreData {
// //   FirebaseFirestore db = FirebaseFirestore.instance;
// //   FirebaseAuth auth = FirebaseAuth.instance;
// //   final geo = Geoflutterfire();

// //   void addDriversDataToFirestore(
// //     BuildContext context,
// //     String carName,
// //     String carPlateNum,
// //     String carType,
// //   ) async {
// //     try {
// //        String? userEmail = auth.currentUser?.email;
// //       if (userEmail == null) {
// //         if (context.mounted) {
// //           ErrorNotification().showError(context, "User is not authenticated.");
// //         }
// //         return;
// //       }
// //       await db
// //           .collection("Drivers")
// //           .doc(auth.currentUser!.email.toString())
// //           .set({
// //             "name": FirebaseAuth.instance.currentUser!.email!.split("@")[0],
// //             "email": FirebaseAuth.instance.currentUser!.email,
// //             "Car Name": carName,
// //             "Car Plate Num": carPlateNum,
// //             "Car Type": carType,
// //           });
// //     } catch (e) {
// //       if (context.mounted) {
// //         ErrorNotification().showError(context, "An Error Occurred $e");
// //       }
// //     }
// //   }

// //   void getDriverDetails(BuildContext context) async {
// //     try {
// //       DocumentSnapshot<Map<String, dynamic>> data =
// //           await db
// //               .collection("Drivers")
// //               .doc(auth.currentUser!.email.toString())
// //               .get();

// //       DriverInfoModel driver = DriverInfoModel(
// //         auth.currentUser!.uid,
// //         data.data()?["name"],
// //         data.data()?["email"],
// //         data.data()?["Car Name"],
// //         data.data()?["Car Plate Num"],
// //         data.data()?["Car Type"],
// //       );

// //       print("data is ${driver.carType}");
// //     } catch (e) {
// //       if (context.mounted) {
// //         ErrorNotification().showError(context, "An Error Occurred $e");
// //       }
// //     }
// //   }

// //   void setDriverStatus(BuildContext context, String status) async {
// //     try {
// //       await db
// //           .collection("Drivers")
// //           .doc(auth.currentUser!.email.toString())
// //           .update({"driverStatus": status});
// //     } catch (e) {
// //       if (context.mounted) {
// //         ErrorNotification().showError(context, "An Error Occurred $e");
// //       }
// //     }
// //   }

// //   void setDriverLocationStatus(BuildContext context, GeoFirePoint? loc) async {
// //     try {
// //       await db
// //           .collection("Drivers")
// //           .doc(auth.currentUser!.email.toString())
// //           .update({"driverLoc": loc?.data});
// //     } catch (e) {
// //       if (context.mounted) {
// //         ErrorNotification().showError(context, "An Error Occurred $e");
// //       }
// //     }
// //   }
// // }
// //import 'package:aminidriver/Model/driver_info_model.dart';
// //import 'package:aminidriver/View/Screens/Main_Screens/map_screen';
// //import 'package:aminidriver/View/Screens/Main_Screens/Home_Screen/home_screen.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// //import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
// import 'package:geoflutterfire2/geoflutterfire2.dart'; // Import geoflutterfire
// import 'package:latlong2/latlong.dart';

// import '../utils/error_notification.dart';

// final globalFirestoreRepoProvider = Provider<AddFirestoreData>((ref) {
//   return AddFirestoreData();
// });

// class AddFirestoreData {
//   FirebaseFirestore db = FirebaseFirestore.instance;
//   FirebaseAuth auth = FirebaseAuth.instance;
//   //final geo = geoflutterfire_plus();
//   GeoFlutterFire geo = GeoFlutterFire();

//   //final geo = Geoflutterfire(); // Instance of Geoflutterfire

//   // Add driver's location along with other data to Firestore
//   void addDriversDataToFirestore(
//     BuildContext context,
//     String vehicleName,
//     String vehiclePlateNum,
//     String vehicleType,
//     String category,
//     GeoFirePoint driverLocation,
//   ) async {
//     try {
//       String? userEmail = auth.currentUser?.email;
//       String? phone = auth.currentUser?.phoneNumber;
//       if (userEmail == null) {
//         if (context.mounted) {
//           ErrorNotification().showError(context, "User is not authenticated.");
//         }
//         return;
//       }

//       await db.collection("Drivers").doc(userEmail).set({
//         "name": userEmail.split("@")[0],
//         "email": userEmail,
//         "Phone": phone,
//         "Car Name": vehicleName,
//         "Car Plate Num": vehiclePlateNum,
//         "Car Type": vehicleType,
//         "Category": category,
//         "driverLoc": driverLocation.data, // Store location as GeoPoint
//       });
//     } catch (e, stackTrace) {
//       if (context.mounted) {
//         ErrorNotification().showError(context, "An Error Occurred $e");
//       }
//       print("Error: $e");
//       print("Stack Trace: $stackTrace");
//     }
//   }

//   // Retrieve driver's details and location
//   // void getDriverDetails(BuildContext context) async {
//   //   try {
//   //     String? userEmail = auth.currentUser?.email;
//   //     if (userEmail == null) {
//   //       if (context.mounted) {
//   //         ErrorNotification().showError(context, "User is not authenticated.");
//   //       }
//   //       return;
//   //     }

//   //     DocumentSnapshot<Map<String, dynamic>> data =
//   //         await db.collection("Drivers").doc(userEmail).get();

//   //     DriverInfoModel driver = DriverInfoModel(
//   //       auth.currentUser!.uid,
//   //       data.data()?["name"],
//   //       data.data()?["email"],
//   //       data.data()?["Car Name"],
//   //       data.data()?["Car Plate Num"],
//   //       data.data()?["Car Type"],
//   //     );

//   //     final loc = data.data()?["driverLoc"];

//   //     if (loc != null && loc is GeoPoint) {
//   //       print(
//   //         "Driver location: Latitude ${loc.latitude}, Longitude ${loc.longitude}",
//   //       );
//   //     } else {
//   //       print("Driver location is not set or invalid");
//   //     }

//   //     // GeoPoint location = data.data()?["driverLoc"];
//   //     // print(
//   //     //   "Driver location: Latitude ${location.latitude}, Longitude ${location.longitude}",
//   //     // );
//   //   } catch (e, stackTrace) {
//   //     if (context.mounted) {
//   //       ErrorNotification().showError(context, "An Error Occurred $e");
//   //     }
//   //     print("Error: $e");
//   //     print("Stack Trace: $stackTrace");
//   //   }
//   // }

//   void getDriverDetails(BuildContext context) async {
//     // try {
//     String? userEmail = auth.currentUser?.email;
//     if (userEmail == null) {
//       if (context.mounted) {
//         ErrorNotification().showError(context, "User is not authenticated.");
//       }
//       return;
//     }

//     DocumentSnapshot<Map<String, dynamic>> data =
//         await db.collection("Drivers").doc(userEmail).get();

//     final loc = data.data()?["driverLoc"];

//     if (loc != null && loc is GeoPoint) {
//       double lat = loc.latitude;
//       double lng = loc.longitude;

//       print("Driver location: Latitude $lat, Longitude $lng");

//       if (context.mounted) {
//         showDialog(
//           context: context,
//           builder:
//               (context) => AlertDialog(
//                 title: Text('Driver Location'),
//                 content: SizedBox(
//                   width: 300,
//                   height: 300,
//                   child: FlutterMap(
//                     options: MapOptions(center: LatLng(lat, lng), zoom: 13.0),
//                     children: [
//                       TileLayer(
//                         urlTemplate:
//                             'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
//                         subdomains: ['a', 'b', 'c'],
//                       ),
//                       MarkerLayer(
//                         markers: [
//                           Marker(
//                             width: 80.0,
//                             height: 80.0,
//                             point: LatLng(lat, lng),
//                             builder:
//                                 (ctx) => Icon(
//                                   Icons.location_pin,
//                                   size: 40,
//                                   color: Colors.red,
//                                 ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//                 actions: [
//                   TextButton(
//                     onPressed: () => Navigator.of(context).pop(),
//                     child: Text("Close"),
//                   ),
//                 ],
//               ),
//         );
//       }
//     } else {
//       if (context.mounted) {
//         ErrorNotification().showError(context, "Driver location is missing.");
//       }
//     }
//     // } catch (e, stackTrace) {
//     //   if (context.mounted) {
//     //     ErrorNotification().showError(context, "An Error Occurred $e");
//     //   }
//     //   print("Error: $e");
//     //   print("Stack Trace: $stackTrace");
//     // }
//   }

//   // Set driver's status (e.g., available, offline, etc.)
//   void setDriverStatus(BuildContext context, String status) async {
//     //try {
//     String? userEmail = auth.currentUser?.email;
//     if (userEmail == null) {
//       if (context.mounted) {
//         ErrorNotification().showError(context, "User is not authenticated.");
//       }
//       return;
//     }

//     await db.collection("Drivers").doc(userEmail).update({
//       "driverStatus": status,
//     });
//     // } catch (e, stackTrace) {
//     //   if (context.mounted) {
//     //     ErrorNotification().showError(context, "An Error Occurred $e");
//     //   }
//     //   print("Error: $e");
//     //   print("Stack Trace: $stackTrace");
//     // }
//   }

//   // Update driver's location
//   void setDriverLocationStatus(BuildContext context, GeoFirePoint? loc) async {
//     try {
//       String? userEmail = auth.currentUser?.email;
//       if (userEmail == null) {
//         if (context.mounted) {
//           ErrorNotification().showError(context, "User is not authenticated.");
//         }
//         return;
//       }

//       if (loc != null) {
//         await db.collection("Drivers").doc(userEmail).update({
//           "driverLoc": loc.data,
//         });
//       } else {
//         if (context.mounted) {
//           ErrorNotification().showError(
//             context,
//             "Driver location is not available.",
//           );
//         }
//       }
//     } catch (e, stackTrace) {
//       if (context.mounted) {
//         ErrorNotification().showError(context, "An Error Occurred $e");
//       }
//       print("Error: $e");
//       print("Stack Trace: $stackTrace");
//     }
//   }

//   // Get nearby drivers using geospatial queries
//   void getNearbyDrivers(
//     BuildContext context,
//     GeoFirePoint center,
//     double radius,
//   ) async {
//     try {
//       var geoRef = geo.collection(collectionRef: db.collection('Drivers'));
//       var centerLocation = geo.point(
//         latitude: center.latitude,
//         longitude: center.longitude,
//       );

//       // Perform geospatial query to find nearby drivers
//       var query = geoRef.within(
//         center: centerLocation,
//         radius: radius,
//         field: 'driverLoc',
//       );
//       query.listen((List<DocumentSnapshot> driverDocs) {
//         for (var driverDoc in driverDocs) {
//           print("Nearby Driver: ${driverDoc.id}");
//         }
//       });
//     } catch (e, stackTrace) {
//       if (context.mounted) {
//         ErrorNotification().showError(context, "An Error Occurred $e");
//       }
//       print("Error: $e");
//       print("Stack Trace: $stackTrace");
//     }
//   }
// }
