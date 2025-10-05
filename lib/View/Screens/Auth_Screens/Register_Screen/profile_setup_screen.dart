import 'dart:convert';
import 'dart:io';
import 'package:aminidriver/Container/utils/api_constant.dart';
import 'package:aminidriver/Container/utils/keys.dart';
import 'package:aminidriver/Onboarding/driveronboardingscreen.dart';
import 'package:aminidriver/Onboarding/user_role.dart';
import 'package:aminidriver/Onboarding/vehicle_category.dart';
import 'package:aminidriver/Onboarding/vehicleonboardingscreen.dart';
import 'package:aminidriver/View/Routes/routes.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController dealerNameController = TextEditingController();

  final List<String> userTypes = ['Individual', 'Corporate'];
  String selectedUserType = 'Individual';
  //List<String> categories = [];
  //VehicleCategory? selectedCategory;
  UserRole? _selectedRole;
  bool isLoadingCategories = false;

  List<VehicleCategoryModel> categories = [];
  VehicleCategory? selectedCategory; //? selectedCategory;

  @override
  void initState() {
    super.initState();
    fetchCategories();
    if (selectedUserType == 'Corporate') {
      _selectedRole = UserRole.owner;
    }
  }

  Future<void> fetchCategories() async {
    setState(() => isLoadingCategories = true);
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/vehicles/categories'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        setState(() {
          categories =
              jsonList
                  .map((json) => VehicleCategoryModel.fromJson(json))
                  .toList();
        });
      } else {
        throw Exception("Failed to load categories: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error fetching categories: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not load categories")),
      );
    } finally {
      setState(() => isLoadingCategories = false);
    }
  }

  Future<void> saveProfileAndContinue() async {
    final email = emailController.text.trim();
    final dealerName = dealerNameController.text.trim();
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (email.isEmpty || !emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid email")),
      );
      return;
    }

    if (selectedUserType == 'Corporate' && dealerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid Dealer Name")),
      );
      return;
    }

    if (selectedUserType == 'Individual' &&
        (firstName.isEmpty || lastName.isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter full name")));
      return;
    }

    if (selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a service category")),
      );
      return;
    }

    if (_selectedRole == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select a role")));
      return;
    }
    String? idToken;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        context.goNamed(Routes().register);
        return;
      }

      final idToken = await user.getIdToken(true);
      final fcmToken = await FirebaseMessaging.instance.getToken();
      final Map<String, dynamic> body = {
        'token': idToken,
        'role': _selectedRole!.index,
        'userType': selectedUserType,
        'email': email,
        'phoneNumber': user.phoneNumber ?? user.uid,
        'vehicleCategory': selectedCategory!.index,
        'fcmToken': fcmToken,
      };

      if (selectedUserType == 'Corporate') {
        body['dealerName'] = dealerName;
      } else {
        body['firstName'] = firstName;
        body['lastName'] = lastName;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/auth/firebase-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        throw Exception('Backend error: ${response.body}');
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': email,
        'phone': user.phoneNumber ?? '',
        'userType': selectedUserType,
        'role': _selectedRole!.index,
        'vehicleCategory': selectedCategory!.index,
        if (selectedUserType == 'Corporate') 'dealerName': dealerName,
        if (selectedUserType == 'Individual') ...{
          'firstName': firstName,
          'lastName': lastName,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      switch (_selectedRole) {
        case UserRole.driver:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => DriverOnboardingScreen(
                    role: UserRole.driver,
                    // category: selectedCategory!,
                  ),
            ),
          );
          break;

        case UserRole.owner:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => DriverOnboardingScreen(
                    role: UserRole.owner,
                    //category: selectedCategory!,
                  ),
            ),
          );
          break;

        case UserRole.driverOwner:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => DriverOnboardingScreen(
                    role: UserRole.driverOwner,
                    // category: selectedCategory!,
                  ),
            ),
          );
          break;

        case UserRole.admin:
        default:
          context.goNamed(Routes().navigationScreen);
          break;
      }
    } catch (e) {
      // 🔁 Rollback backend user if Firestore fails
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await http.delete(
            Uri.parse('$baseUrl/auth/delete-user/${user.uid}'),

            // headers: {
            //   HttpHeaders.authorizationHeader:
            //       'Bearer $idToken', // if protected
            // },
          );
        }
      } catch (rollbackError) {
        debugPrint("Rollback failed: $rollbackError");
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to save profile: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Set Up Profile")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Text("Enter Your Profile Information"),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedUserType,
                items:
                    userTypes.map((String type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedUserType = value!;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Register As',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              isLoadingCategories
                  ? const CircularProgressIndicator()
                  : DropdownButtonFormField<VehicleCategory>(
                    value: selectedCategory,
                    items:
                        VehicleCategory.values.map((category) {
                          return DropdownMenuItem<VehicleCategory>(
                            value: category,
                            child: Text(category.displayName),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setState(() => selectedCategory = value);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Select Service Category',
                      border: OutlineInputBorder(),
                    ),
                  ),

              const SizedBox(height: 20),

              if (selectedUserType == 'Individual') ...[
                TextField(
                  controller: firstNameController,
                  decoration: const InputDecoration(
                    hintText: "First Name",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: lastNameController,
                  decoration: const InputDecoration(
                    hintText: "Last Name",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              if (selectedUserType == 'Corporate') ...[
                TextField(
                  controller: dealerNameController,
                  decoration: const InputDecoration(
                    hintText: "Dealer Name",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              const SizedBox(height: 20),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: "Email",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),
              const Text(
                "Select Your Role",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),

              RadioListTile<UserRole>(
                title: const Text('Driver Only'),
                value: UserRole.driver,
                groupValue: _selectedRole,
                onChanged:
                    selectedUserType == 'Corporate'
                        ? null
                        : (val) => setState(() => _selectedRole = val),
              ),

              RadioListTile<UserRole>(
                title: const Text('Vehicle Owner Only'),
                value: UserRole.owner,
                groupValue: _selectedRole,
                onChanged: (val) => setState(() => _selectedRole = val),
              ),

              RadioListTile<UserRole>(
                title: const Text('Both Driver and Vehicle Owner'),
                value: UserRole.driverOwner,
                groupValue: _selectedRole,
                onChanged:
                    selectedUserType == 'Corporate'
                        ? null
                        : (val) => setState(() => _selectedRole = val),
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: saveProfileAndContinue,
                  child: const Text("Next"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
