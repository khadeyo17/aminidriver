import 'package:aminidriver/Container/utils/keys.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<List<RideHistory>> fetchRides(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();

    try {
      final response = await http.get(
        Uri.parse("$baseUrl/rides/driver/history/${user!.uid}"),
        // headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => RideHistory.fromJson(json)).toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Your Trips"),
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        foregroundColor: textColor,
      ),
      body: FutureBuilder<List<RideHistory>>(
        future: fetchRides(context),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Show circular loader while fetching
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            // No rides
            return Center(
              child: Text(
                "No rides yet",
                style: TextStyle(
                  fontSize: 18,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }

          final trips = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final trip = trips[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black12 : Colors.grey.shade300,
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Vehicle / Icon
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.yellow[700],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.local_taxi, color: Colors.black),
                    ),
                    const SizedBox(width: 16),
                    // Trip details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${trip.pickupLocation} → ${trip.destination}",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Passenger: ${trip.passenger.name ?? 'Unknown'}",
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  isDark ? Colors.grey[300] : Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Status: ${trip.status}",
                            style: const TextStyle(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${trip.requestTime?.toLocal().toString().split('.')[0] ?? ''}",
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Fare
                    Text(
                      "KES ${trip.fare.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class RideHistory {
  final int id;
  final String pickupLocation;
  final String destination;
  final DateTime? requestTime;
  final DateTime? pickupTime;
  final DateTime? dropoffTime;
  final double pickupLatitude;
  final double pickupLongitude;
  final double destinationLatitude;
  final double destinationLongitude;
  final String? photoUrl;
  final String? subCategory;
  final String vehicleType;
  final double fare;
  final String status;
  final int rating;
  final DateTime? scheduledDate;
  final Passenger passenger;
  final Vehicle vehicle;

  RideHistory({
    required this.id,
    required this.pickupLocation,
    required this.destination,
    this.requestTime,
    this.pickupTime,
    this.dropoffTime,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.destinationLatitude,
    required this.destinationLongitude,
    this.photoUrl,
    this.subCategory,
    required this.vehicleType,
    required this.fare,
    required this.status,
    required this.rating,
    this.scheduledDate,
    required this.passenger,
    required this.vehicle,
  });

  factory RideHistory.fromJson(Map<String, dynamic> json) {
    return RideHistory(
      id: json['id'],
      pickupLocation: json['pickupLocation'],
      destination: json['destination'],
      // requestTime: DateTime.parse(json['requestTime']),
      requestTime:
          json['requestTime'] != null
              ? DateTime.tryParse(json['requestTime'])
              : null,
      pickupTime:
          json['pickupTime'] != null
              ? DateTime.tryParse(json['pickupTime'])
              : null,
      dropoffTime:
          json['dropoffTime'] != null
              ? DateTime.tryParse(json['dropoffTime'])
              : null,

      // pickupLatitude: json['pickupLatitude'].toDouble(),
      // pickupLongitude: json['pickupLongitude'].toDouble(),
      // destinationLatitude: json['destinationLatitude'].toDouble(),
      // destinationLongitude: json['destinationLongitude'].toDouble(),
      pickupLatitude: (json['pickupLatitude'] ?? 0).toDouble(),
      pickupLongitude: (json['pickupLongitude'] ?? 0).toDouble(),
      destinationLatitude: (json['destinationLatitude'] ?? 0).toDouble(),
      destinationLongitude: (json['destinationLongitude'] ?? 0).toDouble(),
      fare: (json['fare'] ?? 0).toDouble(),
      status: json['status'] ?? '',

      photoUrl: json['photoUrl'],
      subCategory: json['subCategory'],
      vehicleType: json['vehicleType'],

      rating: json['rating'] ?? '0',
      scheduledDate:
          json['scheduledDate'] != null
              ? DateTime.tryParse(json['scheduledDate'])
              : null,
      passenger: Passenger.fromJson(json['passenger']),
      vehicle: Vehicle.fromJson(json['vehicle']),
    );
  }
}

class Passenger {
  final String? name;
  final String? phone;
  final String? email;

  Passenger({required this.name, required this.phone, required this.email});

  factory Passenger.fromJson(Map<String, dynamic> json) {
    return Passenger(
      name: json['name'],
      phone: json['phone'],
      email: json['email'],
    );
  }
}

class Vehicle {
  final String? make;
  final String? model;
  final String? colour;
  final String? registrationNumber;

  Vehicle({this.make, this.model, this.colour, this.registrationNumber});

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      make: json['make'],
      model: json['model'],
      colour: json['colour'],
      registrationNumber: json['registrationNumber'],
    );
  }
}

// import 'package:aminidriver/Container/utils/keys.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';

// class HistoryScreen extends StatelessWidget {
//   const HistoryScreen({super.key});

//   Future<List<RideHistory>> fetchRides(BuildContext context) async {
//     final user = FirebaseAuth.instance.currentUser;
//     final token = await user?.getIdToken();

//     final response = await http.get(
//       Uri.parse("$baseUrl/rides/driver/history/${user!.uid}"),
//       // headers: {'Authorization': 'Bearer $token'},
//     );

//     if (response.statusCode == 200) {
//       final List<dynamic> data = jsonDecode(response.body);
//       return data.map((json) => RideHistory.fromJson(json)).toList();
//     } else {
//       final errorMessage = response.body;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text("Failed to load rides: $errorMessage"),
//           backgroundColor: Colors.red,
//         ),
//       );
//       return []; // Return empty list on error
//     }
//   }

//   // Future<List<RideHistory>> fetchRides() async {
//   //   final user = FirebaseAuth.instance.currentUser;
//   //   final token = await user?.getIdToken();

//   //   final response = await http.get(
//   //     Uri.parse("$baseUrl/rides/driver/history/${user!.uid}"),
//   //     //headers: {'Authorization': 'Bearer $token'},
//   //   );

//   //   if (response.statusCode == 200) {
//   //     final List<dynamic> data = jsonDecode(response.body);
//   //     return data.map((json) => RideHistory.fromJson(json)).toList();
//   //   } else {
//   //     if (mounted) {
//   //     ScaffoldMessenger.of(context).showSnackBar(
//   //       SnackBar(
//   //         content: Text("Failed to load rides: $errorMessage"),
//   //         backgroundColor: Colors.red,
//   //       ),
//   //     );
//   //   }
//   //     //throw ({response.body});  // ${response.body} Exception("Failed to load ride history: ${response.body}");
//   //   }
//   // }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final isDark = theme.brightness == Brightness.dark;
//     final textColor = isDark ? Colors.white : Colors.black;

//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         title: const Text("Your Trips"),
//         centerTitle: true,
//         backgroundColor: Colors.white,
//         elevation: 0,
//         foregroundColor: Colors.black,

//         // backgroundColor: theme.scaffoldBackgroundColor,
//         // elevation: 0.5,
//         // centerTitle: true,
//         // iconTheme: IconThemeData(color: textColor),
//         // title: Text(
//         //   "Your Trips",
//         //   style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
//       ),
//       body: FutureBuilder<List<RideHistory>>(
//         future: fetchRides(context),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           } else if (snapshot.hasError) {
//             return Center(child: Text("Error: ${snapshot.error}"));
//           }

//           final trips = snapshot.data!;

//           return ListView.builder(
//             itemCount: trips.length,
//             itemBuilder: (context, index) {
//               final trip = trips[index];
//               return Container(
//                 margin: const EdgeInsets.symmetric(
//                   horizontal: 15,
//                   vertical: 10,
//                 ),
//                 padding: const EdgeInsets.all(15),
//                 decoration: BoxDecoration(
//                   color: isDark ? Colors.grey[850] : Colors.white,
//                   borderRadius: BorderRadius.circular(12),
//                   boxShadow: [
//                     BoxShadow(
//                       color: isDark ? Colors.black12 : Colors.grey.shade300,
//                       blurRadius: 4,
//                       offset: const Offset(0, 2),
//                     ),
//                   ],
//                 ),
//                 child: Row(
//                   children: [
//                     Container(
//                       padding: const EdgeInsets.all(8),
//                       decoration: BoxDecoration(
//                         color: Colors.yellow[700],
//                         shape: BoxShape.circle,
//                       ),
//                       child: const Icon(Icons.local_taxi, color: Colors.black),
//                     ),
//                     const SizedBox(width: 15),
//                     Expanded(
//                       child:
//                       // child: Column(
//                       //   crossAxisAlignment: CrossAxisAlignment.start,
//                       //   children: [
//                       //     Text(
//                       //       "${trip.pickupLocation} → ${trip.destination}",
//                       //       style: TextStyle(
//                       //         fontWeight: FontWeight.w600,
//                       //         fontSize: 16,
//                       //         color: textColor,
//                       //       ),
//                       //     ),
//                       //     Text(
//                       //       "${trip.requestTime!.toLocal()}".split(
//                       //         ".",
//                       //       )[0], // Format datetime nicely
//                       //       style: TextStyle(
//                       //         color:
//                       //             isDark ? Colors.grey[400] : Colors.grey[700],
//                       //         fontSize: 12,
//                       //       ),
//                       //     ),
//                       //     Text(
//                       //       "KES ${trip.fare.toStringAsFixed(2)}",
//                       //       style: TextStyle(
//                       //         fontWeight: FontWeight.bold,
//                       //         color: Colors.blue[700],
//                       //       ),
//                       //     ),
//                       //   ],
//                       // ),
//                       Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             "${trip.pickupLocation} → ${trip.destination}",
//                             style: TextStyle(
//                               fontWeight: FontWeight.w600,
//                               fontSize: 16,
//                               color: textColor,
//                             ),
//                           ),
//                           const SizedBox(height: 4),
//                           Text(
//                             "Passenger: ${trip.passenger.name}", // 👈 Passenger Name
//                             style: TextStyle(
//                               color:
//                                   isDark ? Colors.grey[300] : Colors.grey[800],
//                               fontSize: 13,
//                             ),
//                           ),
//                           const SizedBox(height: 4),
//                           Text(
//                             "Status: ${trip.status}", // 👈 Ride Status
//                             style: TextStyle(
//                               color: Colors.deepPurple,
//                               fontWeight: FontWeight.w500,
//                               fontSize: 13,
//                             ),
//                           ),
//                           const SizedBox(height: 4),
//                           Text(
//                             "${trip.requestTime!.toLocal()}".split(
//                               ".",
//                             )[0], // nicely formatted datetime
//                             style: TextStyle(
//                               color:
//                                   isDark ? Colors.grey[400] : Colors.grey[700],
//                               fontSize: 12,
//                             ),
//                           ),
//                           Text(
//                             "KES ${trip.fare.toStringAsFixed(2)}",
//                             style: TextStyle(
//                               fontWeight: FontWeight.bold,
//                               color: Colors.blue[700],
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     // Text(
//                     //   "KES ${trip.fare.toStringAsFixed(2)}",
//                     //   style: TextStyle(
//                     //     fontWeight: FontWeight.bold,
//                     //     color: Colors.blue[700],
//                     //   ),
//                     // ),
//                   ],
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }

// class RideHistory {
//   final int id;
//   final String pickupLocation;
//   final String destination;
//   final DateTime? requestTime;
//   final DateTime? pickupTime;
//   final DateTime? dropoffTime;
//   final double pickupLatitude;
//   final double pickupLongitude;
//   final double destinationLatitude;
//   final double destinationLongitude;
//   final String? photoUrl;
//   final String? subCategory;
//   final String vehicleType;
//   final double fare;
//   final String status;
//   final int rating;
//   final DateTime? scheduledDate;
//   final Passenger passenger;
//   final Vehicle vehicle;

//   RideHistory({
//     required this.id,
//     required this.pickupLocation,
//     required this.destination,
//     this.requestTime,
//     this.pickupTime,
//     this.dropoffTime,
//     required this.pickupLatitude,
//     required this.pickupLongitude,
//     required this.destinationLatitude,
//     required this.destinationLongitude,
//     this.photoUrl,
//     this.subCategory,
//     required this.vehicleType,
//     required this.fare,
//     required this.status,
//     required this.rating,
//     this.scheduledDate,
//     required this.passenger,
//     required this.vehicle,
//   });

//   factory RideHistory.fromJson(Map<String, dynamic> json) {
//     return RideHistory(
//       id: json['id'],
//       pickupLocation: json['pickupLocation'],
//       destination: json['destination'],
//       // requestTime: DateTime.parse(json['requestTime']),
//       requestTime:
//           json['requestTime'] != null
//               ? DateTime.tryParse(json['requestTime'])
//               : null,
//       pickupTime:
//           json['pickupTime'] != null
//               ? DateTime.tryParse(json['pickupTime'])
//               : null,
//       dropoffTime:
//           json['dropoffTime'] != null
//               ? DateTime.tryParse(json['dropoffTime'])
//               : null,

//       // pickupLatitude: json['pickupLatitude'].toDouble(),
//       // pickupLongitude: json['pickupLongitude'].toDouble(),
//       // destinationLatitude: json['destinationLatitude'].toDouble(),
//       // destinationLongitude: json['destinationLongitude'].toDouble(),
//       pickupLatitude: (json['pickupLatitude'] ?? 0).toDouble(),
//       pickupLongitude: (json['pickupLongitude'] ?? 0).toDouble(),
//       destinationLatitude: (json['destinationLatitude'] ?? 0).toDouble(),
//       destinationLongitude: (json['destinationLongitude'] ?? 0).toDouble(),
//       fare: (json['fare'] ?? 0).toDouble(),
//       status: json['status'] ?? '',

//       photoUrl: json['photoUrl'],
//       subCategory: json['subCategory'],
//       vehicleType: json['vehicleType'],

//       rating: json['rating'] ?? '0',
//       scheduledDate:
//           json['scheduledDate'] != null
//               ? DateTime.tryParse(json['scheduledDate'])
//               : null,
//       passenger: Passenger.fromJson(json['passenger']),
//       vehicle: Vehicle.fromJson(json['vehicle']),
//     );
//   }
// }

// class Passenger {
//   final String? name;
//   final String? phone;
//   final String? email;

//   Passenger({required this.name, required this.phone, required this.email});

//   factory Passenger.fromJson(Map<String, dynamic> json) {
//     return Passenger(
//       name: json['name'],
//       phone: json['phone'],
//       email: json['email'],
//     );
//   }
// }

// class Vehicle {
//   final String? make;
//   final String? model;
//   final String? colour;
//   final String? registrationNumber;

//   Vehicle({this.make, this.model, this.colour, this.registrationNumber});

//   factory Vehicle.fromJson(Map<String, dynamic> json) {
//     return Vehicle(
//       make: json['make'],
//       model: json['model'],
//       colour: json['colour'],
//       registrationNumber: json['registrationNumber'],
//     );
//   }
// }

// // class Ride {
// //   final String pickup;
// //   final String dropoff;
// //   final String date;
// //   final String fare;

// //   Ride({
// //     required this.pickup,
// //     required this.dropoff,
// //     required this.date,
// //     required this.fare,
// //   });

// //   factory Ride.fromJson(Map<String, dynamic> json) {
// //     return Ride(
// //       pickup: json['pickup'] ?? '',
// //       dropoff: json['dropoff'] ?? '',
// //       date: json['date'] ?? '',
// //       fare: json['fare'] ?? '',
// //     );
// //   }
// // }

// // import 'package:firebase_auth/firebase_auth.dart';
// // import 'package:flutter/material.dart';
// // import 'package:http/http.dart' as http;
// // import 'dart:convert';

// // class HistoryScreen extends StatelessWidget {
// //   const HistoryScreen({super.key});

// //   Future<List<Ride>> fetchRides() async {
// //     final user = FirebaseAuth.instance.currentUser;
// //     final token = await user?.getIdToken();
// //     final response = await http.get(
// //       Uri.parse("https://localhost:7047/api/rides/history"),
// //       headers: {'Authorization': 'Bearer $token'},
// //     );

// //     if (response.statusCode == 200) {
// //       final List<dynamic> data = jsonDecode(response.body);
// //       return data.map((json) => Ride.fromJson(json)).toList();
// //     } else {
// //       throw Exception("Failed to load ride history");
// //     }
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     final theme = Theme.of(context);
// //     final isDark = theme.brightness == Brightness.dark;

// //     return Scaffold(
// //       appBar: AppBar(
// //         backgroundColor: theme.scaffoldBackgroundColor,
// //         elevation: 0.5,
// //         title: const Text(
// //           "Your Trips",
// //           style: TextStyle(fontWeight: FontWeight.bold),
// //         ),
// //         centerTitle: true,
// //         iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
// //       ),
// //       body: FutureBuilder<List<Ride>>(
// //         future: fetchRides(),
// //         builder: (context, snapshot) {
// //           if (snapshot.connectionState == ConnectionState.waiting) {
// //             return const Center(child: CircularProgressIndicator());
// //           } else if (snapshot.hasError) {
// //             return Center(child: Text("Error: ${snapshot.error}"));
// //           }

// //           final trips = snapshot.data!;

// //           return ListView.separated(
// //             padding: const EdgeInsets.all(16),
// //             itemCount: trips.length,
// //             separatorBuilder: (_, __) => const SizedBox(height: 16),
// //             itemBuilder: (context, index) {
// //               final trip = trips[index];
// //               return Container(
// //                 decoration: BoxDecoration(
// //                   color: isDark ? Colors.grey[900] : Colors.white,
// //                   borderRadius: BorderRadius.circular(12),
// //                   boxShadow: [
// //                     BoxShadow(
// //                       color: Colors.black.withOpacity(0.05),
// //                       blurRadius: 8,
// //                       offset: const Offset(0, 4),
// //                     ),
// //                   ],
// //                 ),
// //                 padding: const EdgeInsets.all(16),
// //                 child: Column(
// //                   crossAxisAlignment: CrossAxisAlignment.start,
// //                   children: [
// //                     Row(
// //                       children: [
// //                         const Icon(
// //                           Icons.my_location,
// //                           color: Colors.green,
// //                           size: 20,
// //                         ),
// //                         const SizedBox(width: 8),
// //                         Expanded(
// //                           child: Text(
// //                             trip.pickup,
// //                             style: TextStyle(
// //                               fontWeight: FontWeight.bold,
// //                               fontSize: 16,
// //                               color: isDark ? Colors.white : Colors.black,
// //                             ),
// //                           ),
// //                         ),
// //                       ],
// //                     ),
// //                     const SizedBox(height: 8),
// //                     Row(
// //                       children: [
// //                         const Icon(
// //                           Icons.location_on,
// //                           color: Colors.red,
// //                           size: 20,
// //                         ),
// //                         const SizedBox(width: 8),
// //                         Expanded(
// //                           child: Text(
// //                             trip.dropoff,
// //                             style: TextStyle(
// //                               fontSize: 16,
// //                               color:
// //                                   isDark ? Colors.grey[300] : Colors.grey[800],
// //                             ),
// //                           ),
// //                         ),
// //                       ],
// //                     ),
// //                     const SizedBox(height: 12),
// //                     Row(
// //                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //                       children: [
// //                         Text(
// //                           trip.date,
// //                           style: TextStyle(
// //                             fontSize: 13,
// //                             color: isDark ? Colors.grey[400] : Colors.grey[600],
// //                           ),
// //                         ),
// //                         Text(
// //                           trip.fare,
// //                           style: const TextStyle(
// //                             fontWeight: FontWeight.bold,
// //                             color: Colors.blue,
// //                             fontSize: 16,
// //                           ),
// //                         ),
// //                       ],
// //                     ),
// //                   ],
// //                 ),
// //               );
// //             },
// //           );
// //         },
// //       ),
// //     );
// //   }
// // }

// // class Ride {
// //   final String pickup;
// //   final String dropoff;
// //   final String date;
// //   final String fare;

// //   Ride({
// //     required this.pickup,
// //     required this.dropoff,
// //     required this.date,
// //     required this.fare,
// //   });

// //   factory Ride.fromJson(Map<String, dynamic> json) {
// //     return Ride(
// //       pickup: json['pickup'],
// //       dropoff: json['dropoff'],
// //       date: json['date'], // consider formatting if ISO string
// //       fare: json['fare'],
// //     );
// //   }
// // }

// // // import 'package:firebase_auth/firebase_auth.dart';
// // // import 'package:flutter/material.dart';
// // // import 'package:http/http.dart' as http;
// // // import 'dart:convert';
// // // import 'package:intl/intl.dart'; // For date formatting

// // // class HistoryScreen extends StatelessWidget {
// // //   const HistoryScreen({super.key});

// // //   Future<List<Ride>> fetchRides() async {
// // //     final user = FirebaseAuth.instance.currentUser;
// // //     final token = await user?.getIdToken();
// // //     final response = await http.get(
// // //       Uri.parse("https://localhost:7047/api/rides/history"),
// // //       headers: {'Authorization': 'Bearer $token'},
// // //     );

// // //     if (response.statusCode == 200) {
// // //       final List<dynamic> data = jsonDecode(response.body);
// // //       return data.map((json) => Ride.fromJson(json)).toList();
// // //     } else {
// // //       throw Exception("Failed to load ride history");
// // //     }
// // //   }

// // //   @override
// // //   Widget build(BuildContext context) {
// // //     final theme = Theme.of(context);
// // //     final isDark = theme.brightness == Brightness.dark;

// // //     return Scaffold(
// // //       appBar: AppBar(
// // //         backgroundColor: theme.scaffoldBackgroundColor,
// // //         elevation: 0.5,
// // //         title: Text(
// // //           "Your Trips",
// // //           style: TextStyle(
// // //             color: isDark ? Colors.white : Colors.black,
// // //             fontWeight: FontWeight.bold,
// // //             fontSize: 20,
// // //           ),
// // //         ),
// // //         centerTitle: true,
// // //         iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
// // //       ),
// // //       body: FutureBuilder<List<Ride>>(
// // //         future: fetchRides(),
// // //         builder: (context, snapshot) {
// // //           if (snapshot.connectionState == ConnectionState.waiting) {
// // //             return const Center(child: CircularProgressIndicator());
// // //           } else if (snapshot.hasError) {
// // //             return Center(child: Text("Error: ${snapshot.error}"));
// // //           }

// // //           final trips = snapshot.data!;

// // //           return ListView.builder(
// // //             itemCount: trips.length,
// // //             padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
// // //             itemBuilder: (context, index) {
// // //               final trip = trips[index];

// // //               return Card(
// // //                 elevation: 3,
// // //                 margin: const EdgeInsets.only(bottom: 12),
// // //                 shape: RoundedRectangleBorder(
// // //                   borderRadius: BorderRadius.circular(12),
// // //                 ),
// // //                 child: ListTile(
// // //                   contentPadding: const EdgeInsets.all(16),
// // //                   leading: Container(
// // //                     padding: const EdgeInsets.all(10),
// // //                     decoration: BoxDecoration(
// // //                       color: Colors.yellow[700],
// // //                       shape: BoxShape.circle,
// // //                     ),
// // //                     child: const Icon(
// // //                       Icons.local_taxi,
// // //                       color: Colors.white,
// // //                       size: 24,
// // //                     ),
// // //                   ),
// // //                   title: Column(
// // //                     crossAxisAlignment: CrossAxisAlignment.start,
// // //                     children: [
// // //                       Text(
// // //                         trip.pickup,
// // //                         style: const TextStyle(
// // //                           fontWeight: FontWeight.bold,
// // //                           fontSize: 16,
// // //                         ),
// // //                       ),
// // //                       const SizedBox(height: 4),
// // //                       Text(
// // //                         "→ ${trip.dropoff}",
// // //                         style: TextStyle(fontSize: 14, color: Colors.grey[600]),
// // //                       ),
// // //                     ],
// // //                   ),
// // //                   subtitle: Padding(
// // //                     padding: const EdgeInsets.only(top: 8.0),
// // //                     child: Text(
// // //                       _formatDate(trip.date),
// // //                       style: TextStyle(fontSize: 13, color: Colors.grey[500]),
// // //                     ),
// // //                   ),
// // //                   trailing: Text(
// // //                     trip.fare,
// // //                     style: const TextStyle(
// // //                       fontWeight: FontWeight.bold,
// // //                       fontSize: 16,
// // //                       color: Colors.blue,
// // //                     ),
// // //                   ),
// // //                 ),
// // //               );
// // //             },
// // //           );
// // //         },
// // //       ),
// // //     );
// // //   }

// // //   String _formatDate(String rawDate) {
// // //     try {
// // //       final dateTime = DateTime.parse(rawDate);
// // //       return DateFormat.yMMMd().add_jm().format(dateTime);
// // //     } catch (e) {
// // //       return rawDate;
// // //     }
// // //   }
// // // }

// // // class Ride {
// // //   final String pickup;
// // //   final String dropoff;
// // //   final String date;
// // //   final String fare;

// // //   Ride({
// // //     required this.pickup,
// // //     required this.dropoff,
// // //     required this.date,
// // //     required this.fare,
// // //   });

// // //   factory Ride.fromJson(Map<String, dynamic> json) {
// // //     return Ride(
// // //       pickup: json['pickup'],
// // //       dropoff: json['dropoff'],
// // //       date: json['date'],
// // //       fare: json['fare'],
// // //     );
// // //   }
// // // }

// // // // import 'package:firebase_auth/firebase_auth.dart';
// // // // import 'package:flutter/material.dart';
// // // // import 'package:http/http.dart' as http;
// // // // import 'dart:convert';

// // // // //import '../models/ride.dart'; // make sure to adjust the path

// // // // class HistoryScreen extends StatelessWidget {
// // // //   const HistoryScreen({super.key});

// // // //   Future<List<Ride>> fetchRides() async {
// // // //     final user = FirebaseAuth.instance.currentUser;
// // // //     final token = await user?.getIdToken();
// // // //     final response = await http.get(
// // // //       Uri.parse("https://localhost:7047/api/rides/history"),
// // // //       headers: {'Authorization': 'Bearer $token'},
// // // //     );

// // // //     if (response.statusCode == 200) {
// // // //       final List<dynamic> data = jsonDecode(response.body);
// // // //       return data.map((json) => Ride.fromJson(json)).toList();
// // // //     } else {
// // // //       throw Exception("Failed to load ride history");
// // // //     }
// // // //   }

// // // //   @override
// // // //   Widget build(BuildContext context) {
// // // //     final theme = Theme.of(context);
// // // //     final isDark = theme.brightness == Brightness.dark;
// // // //     final textColor = isDark ? Colors.white : Colors.black;

// // // //     return Scaffold(
// // // //       appBar: AppBar(
// // // //         backgroundColor: theme.scaffoldBackgroundColor,
// // // //         elevation: 0.5,
// // // //         title: Text("Your Trips", style: TextStyle(color: textColor)),
// // // //         centerTitle: true,
// // // //         iconTheme: IconThemeData(color: textColor),
// // // //       ),
// // // //       body: FutureBuilder<List<Ride>>(
// // // //         future: fetchRides(),
// // // //         builder: (context, snapshot) {
// // // //           if (snapshot.connectionState == ConnectionState.waiting) {
// // // //             return const Center(child: CircularProgressIndicator());
// // // //           } else if (snapshot.hasError) {
// // // //             return Center(child: Text("Error: ${snapshot.error}"));
// // // //           }

// // // //           final trips = snapshot.data!;

// // // //           return ListView.separated(
// // // //             itemCount: trips.length,
// // // //             separatorBuilder:
// // // //                 (context, index) =>
// // // //                     Divider(height: 1, color: Colors.grey.shade400),
// // // //             itemBuilder: (context, index) {
// // // //               final trip = trips[index];
// // // //               return ListTile(
// // // //                 leading: const Icon(Icons.local_taxi, color: Colors.yellow),
// // // //                 title: Column(
// // // //                   crossAxisAlignment: CrossAxisAlignment.start,
// // // //                   children: [
// // // //                     Text(
// // // //                       trip.pickup,
// // // //                       style: TextStyle(
// // // //                         fontWeight: FontWeight.bold,
// // // //                         color: textColor,
// // // //                       ),
// // // //                     ),
// // // //                     Text(
// // // //                       "→ ${trip.dropoff}",
// // // //                       style: TextStyle(
// // // //                         color: isDark ? Colors.grey[300] : Colors.grey[700],
// // // //                       ),
// // // //                     ),
// // // //                   ],
// // // //                 ),
// // // //                 subtitle: Text(
// // // //                   trip.date,
// // // //                   style: TextStyle(
// // // //                     fontSize: 12,
// // // //                     color: isDark ? Colors.grey[400] : Colors.grey[800],
// // // //                   ),
// // // //                 ),
// // // //                 trailing: Text(
// // // //                   trip.fare,
// // // //                   style: const TextStyle(
// // // //                     fontWeight: FontWeight.w600,
// // // //                     color: Colors.blue,
// // // //                   ),
// // // //                 ),
// // // //               );
// // // //             },
// // // //           );
// // // //         },
// // // //       ),
// // // //     );
// // // //   }
// // // // }

// // // // class Ride {
// // // //   final String pickup;
// // // //   final String dropoff;
// // // //   final String date;
// // // //   final String fare;

// // // //   Ride({
// // // //     required this.pickup,
// // // //     required this.dropoff,
// // // //     required this.date,
// // // //     required this.fare,
// // // //   });

// // // //   factory Ride.fromJson(Map<String, dynamic> json) {
// // // //     return Ride(
// // // //       pickup: json['pickup'],
// // // //       dropoff: json['dropoff'],
// // // //       date: json['date'],
// // // //       fare: json['fare'],
// // // //     );
// // // //   }
// // // // }
// // // // // import 'package:flutter/material.dart';

// // // // // class HistoryScreen extends StatelessWidget {
// // // // //   const HistoryScreen({super.key});

// // // // //   @override
// // // // //   Widget build(BuildContext context) {
// // // // //     final theme = Theme.of(context);
// // // // //     final isDark = theme.brightness == Brightness.dark;
// // // // //     final textColor = isDark ? Colors.white : Colors.black;

// // // // //     final trips = [
// // // // //       {
// // // // //         "pickup": "Westlands, Nairobi",
// // // // //         "dropoff": "CBD, Nairobi",
// // // // //         "date": "Apr 5, 2025 - 10:45 AM",
// // // // //         "fare": "KES 320",
// // // // //       },
// // // // //       {
// // // // //         "pickup": "Kilimani",
// // // // //         "dropoff": "Upper Hill",
// // // // //         "date": "Apr 3, 2025 - 2:15 PM",
// // // // //         "fare": "KES 280",
// // // // //       },
// // // // //       {
// // // // //         "pickup": "Karen",
// // // // //         "dropoff": "Westlands",
// // // // //         "date": "Mar 28, 2025 - 6:30 PM",
// // // // //         "fare": "KES 450",
// // // // //       },
// // // // //     ];

// // // // //     return Scaffold(
// // // // //       appBar: AppBar(
// // // // //         backgroundColor: theme.scaffoldBackgroundColor,
// // // // //         elevation: 0.5,
// // // // //         title: Text("Your Trips", style: TextStyle(color: textColor)),
// // // // //         centerTitle: true,
// // // // //         iconTheme: IconThemeData(color: textColor),
// // // // //       ),
// // // // //       body: ListView.separated(
// // // // //         itemCount: trips.length,
// // // // //         separatorBuilder:
// // // // //             (context, index) => Divider(height: 1, color: Colors.grey.shade400),
// // // // //         itemBuilder: (context, index) {
// // // // //           final trip = trips[index];
// // // // //           return ListTile(
// // // // //             leading: const Icon(
// // // // //               Icons.local_taxi,
// // // // //               color: Colors.yellow, // yellow taxi icon
// // // // //             ),
// // // // //             title: Column(
// // // // //               crossAxisAlignment: CrossAxisAlignment.start,
// // // // //               children: [
// // // // //                 Text(
// // // // //                   trip["pickup"]!,
// // // // //                   style: TextStyle(
// // // // //                     fontWeight: FontWeight.bold,
// // // // //                     color: textColor,
// // // // //                   ),
// // // // //                 ),
// // // // //                 Text(
// // // // //                   "→ ${trip["dropoff"]!}",
// // // // //                   style: TextStyle(
// // // // //                     color: isDark ? Colors.grey[300] : Colors.grey[700],
// // // // //                   ),
// // // // //                 ),
// // // // //               ],
// // // // //             ),
// // // // //             subtitle: Text(
// // // // //               trip["date"]!,
// // // // //               style: TextStyle(
// // // // //                 fontSize: 12,
// // // // //                 color: isDark ? Colors.grey[400] : Colors.grey[800],
// // // // //               ),
// // // // //             ),
// // // // //             trailing: Column(
// // // // //               mainAxisAlignment: MainAxisAlignment.center,
// // // // //               children: [
// // // // //                 Text(
// // // // //                   trip["fare"]!,
// // // // //                   style: TextStyle(
// // // // //                     fontWeight: FontWeight.w600,
// // // // //                     color: Colors.blue, // blue for fare text
// // // // //                   ),
// // // // //                 ),
// // // // //               ],
// // // // //             ),
// // // // //           );
// // // // //         },
// // // // //       ),
// // // // //     );
// // // // //   }
// // // // // }
