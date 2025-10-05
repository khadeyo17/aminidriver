// Add this import
import 'dart:convert';

import 'package:aminidriver/Container/utils/api_constant.dart';
import 'package:aminidriver/Container/utils/keys.dart';
import 'package:aminidriver/Onboarding/assign_driver.dart';
import 'package:aminidriver/View/Routes/routes.dart';
import 'package:aminidriver/View/Screens/Main_Screens/Payment_Screen/payment_screen.dart';
import 'package:aminidriver/View/Screens/Main_Screens/Profile_Screen/driverdetailssubmission.dart';
import 'package:aminidriver/View/Screens/Other_Screens/driver_vehicle_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http; // Create if not already

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String email = "";
  bool isLoading = true;
  bool isEditing = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  List<VehicleModel> vehicles = [];
  List<String> paymentModes = [];
  String? selectedPaymentMode;
  int? selectedPaymentModeId;
  @override
  void initState() {
    super.initState();
    fetchUserProfile();
    fetchPaymentModes();
  }

  // Future<void> fetchPaymentModes() async {
  //   try {
  //     final user = FirebaseAuth.instance.currentUser;
  //     final idToken = await user?.getIdToken();

  //     final response = await http.get(
  //       Uri.parse('$baseUrl/payments/modes'), // Replace with your API endpoint
  //       headers: {
  //         //"Authorization": "Bearer $idToken",
  //         "Content-Type": "application/json",
  //       },
  //     );

  //     if (response.statusCode == 200) {
  //       final data = json.decode(response.body);
  //       setState(() {
  //         paymentModes = List<String>.from(data['paymentModes'] ?? []);
  //         if (paymentModes.isNotEmpty) {
  //           selectedPaymentMode = paymentModes[0];
  //           selectedPaymentModeId = paymentModes['id'];
  //           // default selection
  //         }
  //       });
  //     } else {
  //       print('Failed to fetch payment modes: ${response.body}');
  //     }
  //   } catch (e) {
  //     print('Error fetching payment modes: $e');
  //   }
  // }

  List<Map<String, dynamic>> paymentModesData = [];

  Future<void> fetchPaymentModes() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();

      final response = await http.get(
        Uri.parse('$baseUrl/payments/modes'),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Parse as list of maps
        paymentModesData = List<Map<String, dynamic>>.from(
          data['paymentModes'] ?? [],
        );

        setState(() {
          if (paymentModesData.isNotEmpty) {
            selectedPaymentMode = paymentModesData[0]['name'];
            selectedPaymentModeId = paymentModesData[0]['id'];
          }
        });
      } else {
        print('Failed to fetch payment modes: ${response.body}');
      }
    } catch (e) {
      print('Error fetching payment modes: $e');
    }
  }

  Future<void> fetchUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      final idToken = await user.getIdToken();
      //email = user.email ?? "";

      final profileRes = await http.get(
        Uri.parse('$baseUrl/auth/profile'),
        headers: {
          "Authorization": "Bearer $idToken",
          "Content-Type": "application/json",
        },
      );

      if (profileRes.statusCode == 200) {
        final data = json.decode(profileRes.body);

        _nameController.text = data['fullname'] ?? "";
        _phoneController.text = data['phone'] ?? "";
        _emailController.text = data['email'] ?? "";
        // selectedPaymentModeId = data['paymentModeId'];

        selectedPaymentModeId =
            (data['paymentModeId'] != null)
                ? data['paymentModeId']
                : (paymentModesData.isNotEmpty
                    ? paymentModesData[0]['id']
                    : null);
        // selectedPaymentModeId =
        //     data['paymentModeId'] ?? paymentModesData.isNotEmpty
        //         ? paymentModesData[0]['id']
        //         : null;
      } else {
        throw Exception("Failed to load profile: ${profileRes.body}");
      }

      // Fetch both owned and driven vehicles
      //await fetchVehicles();
    } catch (e) {
      print("Error fetching profile: $e");
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // Future<void> fetchUserProfile() async {
  //   try {
  //     final user = _auth.currentUser;
  //     if (user == null) throw Exception("User not logged in");

  //     final String firebaseUid = user.uid;
  //     email = user.email ?? "";

  //     final profileRes = await http.get(
  //       Uri.parse('$baseUrl/driver-vehicles/driverprofile/$firebaseUid'),
  //       headers: {"Content-Type": "application/json"},
  //     );

  //     if (profileRes.statusCode == 200) {
  //       final data = json.decode(profileRes.body);
  //       _nameController.text = data['fullname'] ?? "";
  //       _phoneController.text = data['phone'] ?? "";
  //     } else {
  //       throw Exception("Failed to load profile");
  //     }

  //     await fetchVehicles(firebaseUid);
  //   } catch (e) {
  //     print("Error fetching profile: $e");
  //   } finally {
  //     setState(() => isLoading = false);
  //   }
  // }

  // Future<void> fetchVehicles(String uid) async {
  //   try {
  //     final response = await http.get(
  //       Uri.parse('$baseUrl/driver-vehicles/vehicles/$uid'),
  //       headers: {"Content-Type": "application/json"},
  //     );

  //     if (response.statusCode == 200) {
  //       final List data = json.decode(response.body);
  //       vehicles = data.map((json) => VehicleModel.fromJson(json)).toList();
  //     } else {
  //       throw Exception("Failed to fetch vehicles");
  //     }
  //   } catch (e) {
  //     print("Error fetching vehicles: $e");
  //   }
  // }
  Future<void> fetchVehicles() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();

      final response = await http.get(
        Uri.parse('$baseUrl/vehicles/my-vehicles'),
        headers: {
          "Authorization": "Bearer $idToken",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        final List ownedData = data['ownedVehicles'] ?? [];
        final List drivenData = data['drivenVehicles'] ?? [];

        // Combine both lists or use them separately based on your logic
        vehicles = [
          ...ownedData.map((json) => VehicleModel.fromJson(json)),
          ...drivenData.map((json) => VehicleModel.fromJson(json)),
        ];
      } else {
        throw Exception("Failed to fetch vehicles: ${response.body}");
      }
    } catch (e) {
      print("Error fetching vehicles: $e");
    }
  }

  // Future<void> updateUserProfile() async {
  //   try {
  //     final user = FirebaseAuth.instance.currentUser;
  //     final idToken = await user?.getIdToken();

  //     setState(() => isLoading = true);

  //     final body = jsonEncode({
  //       "email": _emailController,
  //       "firebaseId": user!.uid,
  //       // "phoneNumber": _phoneController.text.trim(),
  //     });

  //     final response = await http.put(
  //       Uri.parse("$baseUrl/auth/update-profile"),
  //       headers: {"Content-Type": "application/json"},
  //       body: body,
  //     );

  //     if (response.statusCode == 200) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text("Profile updated successfully")),
  //       );
  //       setState(() => isEditing = false);
  //     } else {
  //       throw Exception("Update failed");
  //     }
  //   } catch (e) {
  //     print("Update error: $e");
  //     ScaffoldMessenger.of(
  //       context,
  //     ).showSnackBar(const SnackBar(content: Text("Error updating profile")));
  //   } finally {
  //     setState(() => isLoading = false);
  //   }
  // }
  Future<void> updateUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();

      setState(() => isLoading = true);

      final body = jsonEncode({
        "email": _emailController.text.trim(),
        "firebaseId": user!.uid,
        "paymentMode": selectedPaymentModeId,
      });

      final response = await http.post(
        Uri.parse("$baseUrl/auth/update-profile"),
        headers: {
          // "Authorization": "Bearer $idToken", // ✅ Add token if needed
          "Content-Type": "application/json",
        },
        body: body,
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully")),
        );
        setState(() => isEditing = false);
      } else {
        throw Exception("Update failed: ${response.body}");
      }
    } catch (e) {
      print("Update error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Error updating profile")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  void logout() async {
    await _auth.signOut();
    if (mounted) {
      context.goNamed(Routes().register);
    }
  }

  // void goToVehicles() {
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (context) => DriverVehiclesScreen(vehicles: vehicles),
  //     ),
  //   );
  // }
  void goToVehicles() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PaymentScreen()),
    );
  }

  void onDriverAssigned() {
    fetchUserProfile();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Driver assigned successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Driver Profile"),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        // title: const Text("Driver Profile"),
        // // backgroundColor: Colors.blue,
        // foregroundColor: Colors.grey[700],
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.cancel : Icons.edit),
            color: Colors.yellow,
            onPressed: () => setState(() => isEditing = !isEditing),
          ),
        ],
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(20.0),
                child: ListView(
                  children: [
                    const SizedBox(height: 20),
                    const CircleAvatar(
                      radius: 50,
                      backgroundImage: NetworkImage(
                        'https://www.example.com/user-profile-image.jpg',
                      ),
                    ),

                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      enabled: false, // 🔒 Disable editing
                      style: const TextStyle(color: Colors.grey), // Text color
                      decoration: InputDecoration(
                        labelText: "Phone (Username)",
                        labelStyle: const TextStyle(color: Colors.grey),
                        disabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        filled: true,
                        fillColor:
                            Colors.grey.shade100, // Light grey background
                      ),
                    ),

                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      enabled: false, // 🔒 Disable editing
                      style: const TextStyle(color: Colors.grey), // Text color
                      decoration: InputDecoration(
                        labelText: "Name",
                        labelStyle: const TextStyle(color: Colors.grey),
                        disabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        filled: true,
                        fillColor:
                            Colors.grey.shade100, // Light grey background
                      ),
                    ),

                    // const SizedBox(height: 16),
                    // TextFormField(
                    //   controller: _nameController,
                    //   enabled: isEditing,
                    //   decoration: borderedDecoration('Full Name'),
                    // ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      enabled: isEditing,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: "Email",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    // const SizedBox(height: 16),
                    // DropdownButtonFormField<String>(
                    //   value: selectedPaymentMode,
                    //   items:
                    //       paymentModes.map((mode) {
                    //         return DropdownMenuItem<String>(
                    //           value: mode,
                    //           child: Text(mode),
                    //         );
                    //       }).toList(),
                    //   onChanged:
                    //       isEditing
                    //           ? (value) {
                    //             setState(() => selectedPaymentMode = value);
                    //           }
                    //           : null,
                    //   decoration: InputDecoration(
                    //     labelText: "Preferred Payment Mode",
                    //     border: OutlineInputBorder(),
                    //   ),
                    // ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: selectedPaymentModeId,
                      items:
                          paymentModesData.map((mode) {
                            return DropdownMenuItem<int>(
                              value: mode['id'],
                              child: Text(mode['name']),
                            );
                          }).toList(),
                      onChanged:
                          isEditing
                              ? (value) =>
                                  setState(() => selectedPaymentModeId = value)
                              : null,
                      decoration: InputDecoration(
                        labelText: "Preferred Payment Mode",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            8,
                          ), // rounded corners
                          borderSide: BorderSide(
                            color: Colors.grey.shade400, // border color
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.grey.shade400,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Colors.grey, // color when focused
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor:
                            Colors.grey.shade100, // light grey background
                      ),
                    ),

                    // const SizedBox(height: 16),
                    // DropdownButtonFormField<int>(
                    //   value: selectedPaymentModeId,
                    //   items:
                    //       paymentModesData.map((mode) {
                    //         return DropdownMenuItem<int>(
                    //           value: mode['id'],
                    //           child: Text(mode['name']),
                    //         );
                    //       }).toList(),
                    //   onChanged:
                    //       isEditing
                    //           ? (value) =>
                    //               setState(() => selectedPaymentModeId = value)
                    //           : null,
                    //   decoration: InputDecoration(
                    //     labelText: "Preferred Payment Mode",
                    //   ),
                    // ),
                    const SizedBox(height: 30),
                    if (isEditing)
                      ElevatedButton.icon(
                        onPressed: updateUserProfile,
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: const Text(
                          "Save Profile",
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[700],
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 30,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                    // const SizedBox(height: 20),
                    // ElevatedButton.icon(
                    //   onPressed: () {
                    //     Navigator.push(
                    //       context,
                    //       MaterialPageRoute(
                    //         builder:
                    //             (context) => AssignDriverScreen(
                    //               onCompleted: onDriverAssigned,
                    //             ),
                    //       ),
                    //     );
                    //   },
                    //   icon: const Icon(
                    //     Icons.assignment_ind,
                    //     color: Colors.white,
                    //   ),
                    //   label: const Text(
                    //     "Assign Driver",
                    //     style: TextStyle(color: Colors.white),
                    //   ),
                    //   style: ElevatedButton.styleFrom(
                    //     backgroundColor: Colors.grey[700],
                    //     padding: const EdgeInsets.symmetric(
                    //       vertical: 14,
                    //       horizontal: 30,
                    //     ),
                    //     shape: RoundedRectangleBorder(
                    //       borderRadius: BorderRadius.circular(12),
                    //     ),
                    //   ),
                    // ),
                    // const SizedBox(height: 20),
                    // ElevatedButton.icon(
                    //   onPressed: goToVehicles,
                    //   icon: const Icon(
                    //     Icons.directions_car,
                    //     color: Colors.white,
                    //   ),
                    //   label: const Text(
                    //     "My Vehicles",
                    //     style: TextStyle(color: Colors.white),
                    //   ),
                    //   style: ElevatedButton.styleFrom(
                    //     backgroundColor: Colors.grey[700],
                    //     padding: const EdgeInsets.symmetric(
                    //       vertical: 14,
                    //       horizontal: 30,
                    //     ),
                    //     shape: RoundedRectangleBorder(
                    //       borderRadius: BorderRadius.circular(12),
                    //     ),
                    //   ),
                    // ),
                    // const SizedBox(height: 20),
                    // ElevatedButton.icon(
                    //   onPressed: logout,
                    //   icon: const Icon(Icons.logout, color: Colors.white),
                    //   label: const Text(
                    //     "Logout",
                    //     style: TextStyle(color: Colors.white),
                    //   ),
                    //   style: ElevatedButton.styleFrom(
                    //     backgroundColor: Colors.grey[700],
                    //     padding: const EdgeInsets.symmetric(
                    //       vertical: 14,
                    //       horizontal: 30,
                    //     ),
                    //     shape: RoundedRectangleBorder(
                    //       borderRadius: BorderRadius.circular(12),
                    //     ),
                    //   ),
                    // ),
                    if (!isEditing) ...[
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: goToVehicles,
                        icon: const Icon(
                          Icons.directions_car,
                          color: Colors.white,
                        ),
                        label: const Text(
                          "Wallet",
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[700],
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 30,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: logout,
                        icon: const Icon(Icons.logout, color: Colors.white),
                        label: const Text(
                          "Logout",
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[700],
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 30,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
    );
  }

  InputDecoration borderedDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    );
  }
}
