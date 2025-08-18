import 'dart:convert';
import 'package:aminidriver/Container/utils/api_constant.dart';
import 'package:aminidriver/Container/utils/keys.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AssignDriverScreen extends StatefulWidget {
  final VoidCallback? onCompleted;
  final int vehicleId;

  const AssignDriverScreen({
    super.key,
    this.onCompleted,
    required this.vehicleId,
  });

  @override
  State<AssignDriverScreen> createState() => _AssignDriverScreenState();
}

class _AssignDriverScreenState extends State<AssignDriverScreen> {
  String? selectedDriver;
  bool isLoading = false;

  List<Map<String, dynamic>> drivers = [];

  //final String baseUrl = "http://your-api-url.com"; // Replace with actual URL

  @override
  void initState() {
    super.initState();
    fetchDrivers();
  }

  Future<void> fetchDrivers() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/vehicles/unassigned-drivers"),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          drivers = List<Map<String, dynamic>>.from(data);
        });
      } else {
        showSnackBar("Failed to fetch drivers");
      }
    } catch (e) {
      showSnackBar("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> assignDriver() async {
    if (selectedDriver == null) {
      showSnackBar("Please select a driver.");
      return;
    }

    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/vehicles/assign-driver'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "vehicleId": widget.vehicleId,
          "firebaseId": selectedDriver,
        }),
      );

      if (response.statusCode == 200) {
        showSnackBar("Driver assigned successfully", color: Colors.green);
        // widget.onCompleted();
        // Navigator.pop(context);
      } else {
        showSnackBar("Failed to assign driver");
      }
    } catch (e) {
      showSnackBar("Error assigning driver: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void showSnackBar(String message, {Color color = Colors.red}) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Assign Driver"),
        centerTitle: true,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        // title: const Text('Assign Driver'),
        // backgroundColor: Colors.white,
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Select Driver',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedDriver,
                      items:
                          drivers
                              .map(
                                (driver) => DropdownMenuItem<String>(
                                  value: driver['firebaseId'].toString(),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(driver['fullName']),
                                      Text(
                                        driver['email'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedDriver = value;
                        });
                      },
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity, // ✅ Stretch to full width
                      child: ElevatedButton(
                        onPressed: assignDriver,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 15,
                          ),
                        ),
                        child: const Text('Assign Driver'),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
