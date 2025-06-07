import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

//import '../models/ride.dart'; // make sure to adjust the path

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<List<Ride>> fetchRides() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    final response = await http.get(
      Uri.parse("https://localhost:7047/api/rides/history"),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Ride.fromJson(json)).toList();
    } else {
      throw Exception("Failed to load ride history");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0.5,
        title: Text("Your Trips", style: TextStyle(color: textColor)),
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: FutureBuilder<List<Ride>>(
        future: fetchRides(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final trips = snapshot.data!;

          return ListView.separated(
            itemCount: trips.length,
            separatorBuilder:
                (context, index) =>
                    Divider(height: 1, color: Colors.grey.shade400),
            itemBuilder: (context, index) {
              final trip = trips[index];
              return ListTile(
                leading: const Icon(Icons.local_taxi, color: Colors.yellow),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.pickup,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      "→ ${trip.dropoff}",
                      style: TextStyle(
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  trip.date,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[800],
                  ),
                ),
                trailing: Text(
                  trip.fare,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class Ride {
  final String pickup;
  final String dropoff;
  final String date;
  final String fare;

  Ride({
    required this.pickup,
    required this.dropoff,
    required this.date,
    required this.fare,
  });

  factory Ride.fromJson(Map<String, dynamic> json) {
    return Ride(
      pickup: json['pickup'],
      dropoff: json['dropoff'],
      date: json['date'],
      fare: json['fare'],
    );
  }
}
// import 'package:flutter/material.dart';

// class HistoryScreen extends StatelessWidget {
//   const HistoryScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final isDark = theme.brightness == Brightness.dark;
//     final textColor = isDark ? Colors.white : Colors.black;

//     final trips = [
//       {
//         "pickup": "Westlands, Nairobi",
//         "dropoff": "CBD, Nairobi",
//         "date": "Apr 5, 2025 - 10:45 AM",
//         "fare": "KES 320",
//       },
//       {
//         "pickup": "Kilimani",
//         "dropoff": "Upper Hill",
//         "date": "Apr 3, 2025 - 2:15 PM",
//         "fare": "KES 280",
//       },
//       {
//         "pickup": "Karen",
//         "dropoff": "Westlands",
//         "date": "Mar 28, 2025 - 6:30 PM",
//         "fare": "KES 450",
//       },
//     ];

//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: theme.scaffoldBackgroundColor,
//         elevation: 0.5,
//         title: Text("Your Trips", style: TextStyle(color: textColor)),
//         centerTitle: true,
//         iconTheme: IconThemeData(color: textColor),
//       ),
//       body: ListView.separated(
//         itemCount: trips.length,
//         separatorBuilder:
//             (context, index) => Divider(height: 1, color: Colors.grey.shade400),
//         itemBuilder: (context, index) {
//           final trip = trips[index];
//           return ListTile(
//             leading: const Icon(
//               Icons.local_taxi,
//               color: Colors.yellow, // yellow taxi icon
//             ),
//             title: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   trip["pickup"]!,
//                   style: TextStyle(
//                     fontWeight: FontWeight.bold,
//                     color: textColor,
//                   ),
//                 ),
//                 Text(
//                   "→ ${trip["dropoff"]!}",
//                   style: TextStyle(
//                     color: isDark ? Colors.grey[300] : Colors.grey[700],
//                   ),
//                 ),
//               ],
//             ),
//             subtitle: Text(
//               trip["date"]!,
//               style: TextStyle(
//                 fontSize: 12,
//                 color: isDark ? Colors.grey[400] : Colors.grey[800],
//               ),
//             ),
//             trailing: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Text(
//                   trip["fare"]!,
//                   style: TextStyle(
//                     fontWeight: FontWeight.w600,
//                     color: Colors.blue, // blue for fare text
//                   ),
//                 ),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }
// }
