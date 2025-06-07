import 'package:aminidriver/Onboarding/assign_driver.dart';
import 'package:aminidriver/Onboarding/driveronboardingscreen.dart';
import 'package:aminidriver/Onboarding/vehicleonboardingscreen.dart';
import 'package:flutter/material.dart';

enum UserRole { ownerOnly, driverOnly, ownerAndDriver }

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({Key? key}) : super(key: key);

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  UserRole? _selectedRole;

  InputDecoration borderedDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    );
  }

  void _continue() {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a role to continue')),
      );
      return;
    }

    switch (_selectedRole!) {
      case UserRole.driverOnly:
        // Skip vehicle onboarding
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => //AssignDriverScreen(
                    DriverOnboardingScreen(
                  onCompleted: () {
                    // You may want to do something after completion
                  },
                  skipVehicleOnboarding: true,
                ),
          ),
        );
        break;

      case UserRole.ownerOnly:
        // Skip driver onboarding
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => VehicleOnboardingScreen(
                  skipDriverOnboarding: true,
                  hasownerOnboarding: true,
                ),
          ),
        );
        break;

      case UserRole.ownerAndDriver:
        // Do driver onboarding, then vehicle onboarding without skip flags
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => DriverOnboardingScreen(
                  onCompleted: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => VehicleOnboardingScreen(
                              skipDriverOnboarding: true,
                            ),
                      ),
                    );
                  },
                  skipVehicleOnboarding: false,
                ),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Your Role')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              decoration: borderedBoxDecoration(),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: RadioListTile<UserRole>(
                title: const Text('Register as Driver Only'),
                value: UserRole.driverOnly,
                groupValue: _selectedRole,
                onChanged: (val) {
                  setState(() {
                    _selectedRole = val;
                  });
                },
              ),
            ),
            Container(
              decoration: borderedBoxDecoration(),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: RadioListTile<UserRole>(
                title: const Text('Register as Vehicle Owner Only'),
                value: UserRole.ownerOnly,
                groupValue: _selectedRole,
                onChanged: (val) {
                  setState(() {
                    _selectedRole = val;
                  });
                },
              ),
            ),
            Container(
              decoration: borderedBoxDecoration(),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: RadioListTile<UserRole>(
                title: const Text('Register as Both Driver and Vehicle Owner'),
                value: UserRole.ownerAndDriver,
                groupValue: _selectedRole,
                onChanged: (val) {
                  setState(() {
                    _selectedRole = val;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _continue,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 16,
                ),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration borderedBoxDecoration() {
    return BoxDecoration(
      border: Border.all(color: Colors.grey.shade400),
      borderRadius: BorderRadius.circular(8),
    );
  }
}
