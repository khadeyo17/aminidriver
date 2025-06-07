import 'dart:convert';
import 'package:aminidriver/Container/utils/api_constant.dart';
import 'package:aminidriver/View/Routes/routes.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

class DriverVehiclesScreen extends StatefulWidget {
  @override
  State<DriverVehiclesScreen> createState() => _DriverVehiclesScreenState();
}

class _DriverVehiclesScreenState extends State<DriverVehiclesScreen> {
  List<Map<String, dynamic>> vehicles = [];
  String driverId = "";

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      driverId = user.uid;
      fetchVehicles();
    }
  }

  Future<void> fetchVehicles() async {
    final response = await http.get(
      Uri.parse("$baseUrl/driver-vehicles/by-driver/$driverId"),
    );

    if (response.statusCode == 200) {
      setState(() {
        vehicles = List<Map<String, dynamic>>.from(json.decode(response.body));
      });
    } else {
      showSnack("Failed to fetch vehicles: ${response.body}", isError: true);
    }
  }

  void goToAddVehicle() {
    GoRouter.of(context).goNamed(Routes().driverConfig);
  }

  void assignDriver(int vehicleId) async {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Assign Driver"),
            content: TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: "Driver's Email",
                prefixIcon: Icon(Icons.email, color: Colors.blue),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final email = emailController.text.trim();
                  Navigator.of(context).pop();

                  final response = await http.post(
                    Uri.parse(
                      "$baseUrl/driver-vehicles/assign-driver-by-email",
                    ),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({'email': email, 'vehicleId': vehicleId}),
                  );

                  if (response.statusCode == 200) {
                    showSnack("Driver assigned successfully");
                    fetchVehicles();
                  } else {
                    showSnack(
                      "Failed to assign driver: ${response.body}",
                      isError: true,
                    );
                  }
                },
                child: const Text("Assign"),
              ),
            ],
          ),
    );
  }

  void removeDriver(int vehicleId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Remove Driver"),
            content: const Text(
              "Are you sure you want to unassign the driver?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  "Remove",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      final response = await http.post(
        Uri.parse("$baseUrl/driver-vehicles/remove-driver"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'vehicleId': vehicleId}),
      );

      if (response.statusCode == 200) {
        showSnack("Driver removed successfully");
        fetchVehicles();
      } else {
        showSnack("Failed to remove driver: ${response.body}", isError: true);
      }
    }
  }

  void showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Vehicles"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: goToAddVehicle,
            color: Colors.black,
          ),
        ],
      ),
      body:
          vehicles.isEmpty
              ? const Center(child: Text("No vehicles found"))
              : ListView.builder(
                itemCount: vehicles.length,
                itemBuilder: (context, index) {
                  final v = vehicles[index];
                  return Card(
                    margin: const EdgeInsets.all(10),
                    elevation: 4,
                    child: ListTile(
                      title: Text("${v['vehicleMake']} ${v['vehicleModel']}"),
                      subtitle: Text(
                        "Reg: ${v['registrationNumber']} | Year: ${v['year']}",
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (v['driverId'] != null &&
                              v['driverId'].toString().isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.yellow,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    "Driver Assigned",
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                TextButton(
                                  onPressed: () => removeDriver(v['id']),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text("Remove Driver"),
                                ),
                              ],
                            )
                          else
                            ElevatedButton(
                              onPressed: () => assignDriver(v['id']),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text("Assign Driver"),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: goToAddVehicle,
        backgroundColor: Colors.yellow,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}
