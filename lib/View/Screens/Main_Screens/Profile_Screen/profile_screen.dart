// import 'package:flutter/material.dart';

// class ProfileScreen extends StatefulWidget {
//   const ProfileScreen({super.key});

//   @override
//   State<ProfileScreen> createState() => _ProfileScreenState();
// }

// class _ProfileScreenState extends State<ProfileScreen> {
//   @override
//   Widget build(BuildContext context) {
//       Size size = MediaQuery.sizeOf(context);
//     return Scaffold(
//       body: SafeArea(
//         child: SizedBox(
//          width:size.width,
//          height:size.height,
//           child:const Column(
//             children: [],
//         ),
//        )
//       ),
//     );
//   }
// }

import 'package:aminidriver/Onboarding/assign_driver.dart';
import 'package:aminidriver/View/Routes/routes.dart';
import 'package:aminidriver/View/Screens/Auth_Screens/Register_Screen/register_screen.dart';
import 'package:aminidriver/View/Screens/Main_Screens/Profile_Screen/driverdetailssubmission.dart';
import 'package:aminidriver/View/Screens/Other_Screens/driver_vehicle_screen.dart';
//import 'package:aminidriver/View/Screens/Other_Screens/driver_vehicle_screen.dart';
//import 'package:aminidriver/View/Screens/Other_Screens/driver_vehicle_screen';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:aminidriver/Container/utils/api_constant.dart';

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

  Future<void> fetchUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      final String userEmail = user.email!;
      final String firebaseUid = user.uid;

      setState(() => email = userEmail);

      final response = await http.get(
        Uri.parse('$baseUrl/driver-vehicles/driverprofile/$firebaseUid'),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _nameController.text = data['fullname'] ?? "";
        _phoneController.text = data['phone'] ?? "";
      } else {
        throw Exception("Failed to load profile");
      }
    } catch (e) {
      print("Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> updateUserProfile() async {
    try {
      setState(() => isLoading = true);

      final body = jsonEncode({
        "email": email,
        "fullName": _nameController.text.trim(),
        "phoneNumber": _phoneController.text.trim(),
      });

      final response = await http.put(
        Uri.parse("$baseUrl/auth/update-profile"),
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully")),
        );
        setState(() => isEditing = false);
      } else {
        throw Exception("Update failed");
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

  InputDecoration borderedDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    );
  }

  void logout() async {
    await _auth.signOut();
    if (mounted) {
      context.goNamed(Routes().login);
      //Navigator.of(context).rout(); // or redirect to login screen
    }
  }

  @override
  void initState() {
    super.initState();
    fetchUserProfile();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver Profile"),
        backgroundColor: Colors.blue, // changed from yellow to blue
        foregroundColor: Colors.white, // white font for AppBar
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.cancel : Icons.edit),
            color: Colors.yellow, // yellow icon on blue AppBar
            onPressed: () {
              setState(() => isEditing = !isEditing);
            },
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
                    const SizedBox(height: 20),

                    // Email (non-editable)
                    TextField(
                      controller: TextEditingController(text: email),
                      enabled: false,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(color: textColor),
                        border: const OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      enabled: isEditing,
                      decoration: borderedDecoration('Full Name'),
                      //validator: (val) => val!.isEmpty ? 'Required' : null,
                    ),

                    // const SizedBox(height: 20),

                    // // Name
                    // TextField(
                    //   controller: _nameController,
                    //   enabled: isEditing,
                    //   style: TextStyle(color: textColor),
                    //   decoration: InputDecoration(
                    //     labelText: 'Full Name',
                    //     labelStyle: TextStyle(color: textColor),
                    //     border: const OutlineInputBorder(),
                    //   ),
                    // ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      enabled: isEditing,
                      decoration: borderedDecoration('Phone Number'),
                      //validator: (val) => val!.isEmpty ? 'Required' : null,
                    ),
                    // const SizedBox(height: 20),

                    // // Phone
                    // TextFormField(
                    //   controller: _phoneController,
                    //   enabled: isEditing,
                    //   keyboardType: TextInputType.phone,
                    //   style: TextStyle(color: textColor),
                    //   decoration: InputDecoration(
                    //     labelText: 'Phone Number',
                    //     labelStyle: TextStyle(color: textColor),
                    //     border: const OutlineInputBorder(),
                    //   ),
                    // ),
                    const SizedBox(height: 30),
                    if (isEditing)
                      ElevatedButton.icon(
                        onPressed: updateUserProfile,
                        icon: const Icon(
                          Icons.save,
                          color: Colors.black,
                        ), // Icon font black
                        label: const Text(
                          "Save Profile",
                          style: TextStyle(color: Colors.black),
                        ),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.black,
                          backgroundColor: Colors.blue,
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
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => AssignDriverScreen(
                                  onCompleted: () {
                                    fetchUserProfile(); // Or any method you use to refresh the screen
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Driver assigned successfully',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.assignment_ind,
                        color: Colors.black,
                      ),
                      label: const Text(
                        "Assign Driver",
                        style: TextStyle(color: Colors.black),
                      ),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: Colors.blue,
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
                      onPressed: () {
                        Navigator.push(
                          context,

                          // MaterialPageRoute(
                          //   //onSubmit: (driverData) => handleDriverSubmit(driverData, context),
                          //   builder:
                          //       (context) => RegisterScreen(
                          //         onSubmit:
                          //             (driverData) => handleDriverSubmit(
                          //               driverData,
                          //               context,
                          //             ),
                          //       ),
                          // ),
                          MaterialPageRoute(
                            builder:
                                (context) => DriverVehiclesScreen(
                                  // driverName: 'John Doe',
                                  // vehicles: [
                                  //   {
                                  //     'model': 'Toyota Noah',
                                  //     'regNumber': 'KDJ 123A',
                                  //   },
                                  //   {
                                  //     'model': 'Mazda Bongo',
                                  //     'regNumber': 'KBV 456B',
                                  //   },
                                  // ],
                                ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.directions_car,
                        color: Colors.black,
                      ),
                      label: const Text(
                        "My Vehicles",
                        style: TextStyle(color: Colors.black),
                      ),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: Colors.blue,
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
                      icon: const Icon(
                        Icons.logout,
                        color: Colors.black,
                      ), // Icon font black
                      label: const Text(
                        "Logout",
                        style: TextStyle(color: Colors.black),
                      ),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: Colors.blue,
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
                ),
              ),
    );
  }
}
