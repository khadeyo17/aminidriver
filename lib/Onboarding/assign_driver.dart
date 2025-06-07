import 'package:flutter/material.dart';

class AssignDriverScreen extends StatefulWidget {
  const AssignDriverScreen({super.key, required Null Function() onCompleted});

  @override
  State<AssignDriverScreen> createState() => _AssignDriverScreenState();
}

class _AssignDriverScreenState extends State<AssignDriverScreen> {
  String? selectedDriver;
  String? selectedVehicle;

  // Dummy data (replace with API calls)
  final List<String> drivers = ['John Doe', 'Jane Smith', 'Alex Kim'];
  final List<String> vehicles = ['KCN 123X', 'KDA 456B', 'KCY 789L'];

  void assignDriver() {
    if (selectedDriver != null && selectedVehicle != null) {
      // Send assignment to backend
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$selectedDriver assigned to $selectedVehicle'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both driver and vehicle.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Driver'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Select Driver',
                border: OutlineInputBorder(),
              ),
              value: selectedDriver,
              items:
                  drivers.map((driver) {
                    return DropdownMenuItem(value: driver, child: Text(driver));
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedDriver = value;
                });
              },
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Select Vehicle',
                border: OutlineInputBorder(),
              ),
              value: selectedVehicle,
              items:
                  vehicles.map((vehicle) {
                    return DropdownMenuItem(
                      value: vehicle,
                      child: Text(vehicle),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedVehicle = value;
                });
              },
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: assignDriver,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
              ),
              child: const Text('Assign Driver'),
            ),
          ],
        ),
      ),
    );
  }
}
