import 'dart:convert';
import 'dart:io';
import 'package:aminidriver/Container/utils/api_constant.dart';
import 'package:aminidriver/Container/utils/keys.dart';
import 'package:aminidriver/Onboarding/driveronboardingscreen.dart';
import 'package:aminidriver/Onboarding/user_role.dart';
import 'package:aminidriver/Onboarding/vehicle_category.dart';
import 'package:aminidriver/Onboarding/vehicleonboardingscreen.dart';
import 'package:aminidriver/View/Routes/routes.dart';
import 'package:aminidriver/View/Screens/Auth_Screens/Register_Screen/hub.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:signalr_core/signalr_core.dart';

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
  bool isSaving = false;

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

  // Future<void> initSignalR() async {
  //   hubConnection =
  //       HubConnectionBuilder()
  //           .withUrl('$baseUrldoc/hubs/location')
  //           .withAutomaticReconnect()
  //           .build();

  //   // 1️⃣ Listen for ride requests
  //   hubConnection.on('NewRideRequest', (arguments) {
  //     if (arguments != null && arguments.isNotEmpty) {
  //       final rideData = arguments[0] as Map<String, dynamic>;
  //       print("New ride request: ${rideData['rideId']}");
  //       // Show ride overlay or alert
  //       // _currentRide = rideData;
  //       // _rideRemaining = 30;
  //       // _startRideAlert(rideData);
  //     }
  //   });

  //   // 2️⃣ Start the connection
  //   await hubConnection.start();

  //   // 3️⃣ Join driver group
  //   await hubConnection.invoke('JoinDriverGroup');
  // }

  // Future<void> saveProfileAndContinue() async {

  //   setState(() => isSaving = true);
  //   try{
  //   final email = emailController.text.trim();
  //   final dealerName = dealerNameController.text.trim();
  //   final firstName = firstNameController.text.trim();
  //   final lastName = lastNameController.text.trim();

  //   final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  //   if (email.isEmpty || !emailRegex.hasMatch(email)) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text("Please enter a valid email")),
  //     );
  //     return;
  //   }

  //   if (selectedUserType == 'Corporate' && dealerName.isEmpty) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text("Please enter a valid Dealer Name")),
  //     );
  //     return;
  //   }

  //   if (selectedUserType == 'Individual' &&
  //       (firstName.isEmpty || lastName.isEmpty)) {
  //     ScaffoldMessenger.of(
  //       context,
  //     ).showSnackBar(const SnackBar(content: Text("Please enter full name")));
  //     return;
  //   }

  //   if (selectedCategory == null) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text("Please select a service category")),
  //     );
  //     return;
  //   }

  //   if (_selectedRole == null) {
  //     ScaffoldMessenger.of(
  //       context,
  //     ).showSnackBar(const SnackBar(content: Text("Please select a role")));
  //     return;
  //   }
  //   String? idToken;
  //   try {
  //     final user = FirebaseAuth.instance.currentUser;
  //     if (user == null) {
  //       context.goNamed(Routes().register);
  //       return;
  //     }

  //     final idToken = await user.getIdToken(true);
  //     final fcmToken = await FirebaseMessaging.instance.getToken();
  //     final Map<String, dynamic> body = {
  //       'token': idToken,
  //       'role': _selectedRole!.index,
  //       'userType': selectedUserType,
  //       'email': email,
  //       'phoneNumber': user.phoneNumber ?? user.uid,
  //       'vehicleCategory': selectedCategory!.index,
  //       'fcmToken': fcmToken,
  //     };

  //     if (selectedUserType == 'Corporate') {
  //       body['dealerName'] = dealerName;
  //     } else {
  //       body['firstName'] = firstName;
  //       body['lastName'] = lastName;
  //     }

  //     final response = await http.post(
  //       Uri.parse('$baseUrl/auth/firebase-login'),
  //       headers: {'Content-Type': 'application/json'},
  //       body: jsonEncode(body),
  //     );

  //     if (response.statusCode != 200) {
  //       throw Exception('Backend error: ${response.body}');
  //     }
  //     // After Firebase login and fetching driver info
  //     // await initSignalR();

  //     // await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
  //     //   'email': email,
  //     //   'phone': user.phoneNumber ?? '',
  //     //   'userType': selectedUserType,
  //     //   'role': _selectedRole!.index,
  //     //   'vehicleCategory': selectedCategory!.index,
  //     //   if (selectedUserType == 'Corporate') 'dealerName': dealerName,
  //     //   if (selectedUserType == 'Individual') ...{
  //     //     'firstName': firstName,
  //     //     'lastName': lastName,
  //     //   },
  //     //   'updatedAt': FieldValue.serverTimestamp(),
  //     // }, SetOptions(merge: true));

  //     switch (_selectedRole) {
  //       case UserRole.driver:
  //         Navigator.push(
  //           context,
  //           MaterialPageRoute(
  //             builder:
  //                 (_) => DriverOnboardingScreen(
  //                   role: UserRole.driver,
  //                   // category: selectedCategory!,
  //                 ),
  //           ),
  //         );
  //         break;

  //       case UserRole.owner:
  //         Navigator.push(
  //           context,
  //           MaterialPageRoute(
  //             builder:
  //                 (_) => DriverOnboardingScreen(
  //                   role: UserRole.owner,
  //                   //category: selectedCategory!,
  //                 ),
  //           ),
  //         );
  //         break;

  //       case UserRole.driverOwner:
  //         Navigator.push(
  //           context,
  //           MaterialPageRoute(
  //             builder:
  //                 (_) => DriverOnboardingScreen(
  //                   role: UserRole.driverOwner,
  //                   // category: selectedCategory!,
  //                 ),
  //           ),
  //         );
  //         break;

  //       case UserRole.admin:
  //       default:
  //         context.goNamed(Routes().navigationScreen);
  //         break;
  //     }
  //   } catch (e) {
  //     // 🔁 Rollback backend user if Firestore fails
  //     try {
  //       final user = FirebaseAuth.instance.currentUser;
  //       if (user != null) {
  //         await http.delete(
  //           Uri.parse('$baseUrl/auth/delete-user/${user.uid}'),

  //           // headers: {
  //           //   HttpHeaders.authorizationHeader:
  //           //       'Bearer $idToken', // if protected
  //           // },
  //         );
  //       }
  //     } catch (rollbackError) {
  //       debugPrint("Rollback failed: $rollbackError");
  //     }

  //     ScaffoldMessenger.of(
  //       context,
  //     ).showSnackBar(SnackBar(content: Text("Failed to save profile: $e")));
  //   }

  //   }
  // }

  Future<void> saveProfileAndContinue() async {
    setState(() => isSaving = true); // 🔹 Start loading

    try {
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

      // Navigate based on role
      switch (_selectedRole) {
        case UserRole.driver:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DriverOnboardingScreen(role: UserRole.driver),
            ),
          );
          break;

        case UserRole.owner:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DriverOnboardingScreen(role: UserRole.owner),
            ),
          );
          break;

        case UserRole.driverOwner:
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => DriverOnboardingScreen(role: UserRole.driverOwner),
            ),
          );
          break;

        case UserRole.admin:
        default:
          context.goNamed(Routes().navigationScreen);
          break;
      }
    } catch (e) {
      // 🔁 Rollback backend user if Firebase fails
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await http.delete(Uri.parse('$baseUrl/auth/delete-user/${user.uid}'));
        }
      } catch (rollbackError) {
        debugPrint("Rollback failed: $rollbackError");
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to save profile: $e")));
    } finally {
      setState(() => isSaving = false); // 🔹 Stop loading
    }
  }

  // 🚀 ProfileSetupScreen.dart (Improved UI)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text(
          "Profile Setup",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Complete your profile",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              "Let’s get you ready to start",
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 25),

            // 🔹 USER TYPE
            _buildCard(
              child: DropdownButtonFormField<String>(
                value: selectedUserType,
                items:
                    userTypes
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(
                              type,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => selectedUserType = value!),
                decoration: _inputDecoration("Register As"),
              ),
            ),
            const SizedBox(height: 15),

            // 🔹 CATEGORY
            _buildCard(
              child:
                  isLoadingCategories
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<VehicleCategory>(
                        value: selectedCategory,
                        items:
                            VehicleCategory.values
                                .map(
                                  (category) => DropdownMenuItem(
                                    value: category,
                                    child: Text(
                                      category.displayName,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (value) => setState(() => selectedCategory = value),
                        decoration: _inputDecoration("Select Service Category"),
                      ),
            ),
            const SizedBox(height: 15),

            // 🔹 NAME / DEALER
            _buildCard(
              child: Column(
                children: [
                  if (selectedUserType == 'Individual') ...[
                    TextField(
                      controller: firstNameController,
                      style: const TextStyle(fontSize: 16),
                      decoration: _inputDecoration("First Name"),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: lastNameController,
                      style: const TextStyle(fontSize: 16),
                      decoration: _inputDecoration("Last Name"),
                    ),
                  ],
                  if (selectedUserType == 'Corporate')
                    TextField(
                      controller: dealerNameController,
                      style: const TextStyle(fontSize: 16),
                      decoration: _inputDecoration("Dealer Name"),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 15),

            // 🔹 EMAIL
            _buildCard(
              child: TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontSize: 16),
                decoration: _inputDecoration("Email"),
              ),
            ),
            const SizedBox(height: 20),

            // 🔹 ROLE SELECTION
            const Text(
              "Select Your Role",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children:
                  UserRole.values
                      .where(
                        (role) =>
                            role != UserRole.admin &&
                            role != UserRole.passenger,
                      ) // Remove Admin
                      .map((role) {
                        final isSelected = _selectedRole == role;
                        return ChoiceChip(
                          label: Text(
                            role.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 14,
                              color: isSelected ? Colors.white : Colors.black,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: Colors.black,
                          onSelected: (val) {
                            if (selectedUserType == 'Corporate' &&
                                role != UserRole.owner)
                              return;
                            setState(() => _selectedRole = role);
                          },
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Colors.grey),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        );
                      })
                      .toList(),
            ),

            const SizedBox(height: 30),

            // 🔹 CONTINUE BUTTON
            // SizedBox(
            //   width: double.infinity,
            //   child: ElevatedButton(
            //     style: ElevatedButton.styleFrom(
            //       backgroundColor: Colors.black,
            //       foregroundColor: Colors.white,
            //       elevation: 4,
            //       padding: const EdgeInsets.symmetric(vertical: 18),
            //       shape: RoundedRectangleBorder(
            //         borderRadius: BorderRadius.circular(14),
            //       ),
            //       textStyle: const TextStyle(
            //         fontSize: 18,
            //         fontWeight: FontWeight.bold,
            //       ),
            //     ),
            //     onPressed: saveProfileAndContinue,
            //     child: const Text("Continue"),
            //   ),
            // ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: isSaving ? null : saveProfileAndContinue,
                child:
                    isSaving
                        ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                        : const Text("Next Step"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 CARD WITH SHADOW & BORDER
  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  // 🔹 INPUT DECORATION
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 16),
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey),
      ),
    );
  }
}
