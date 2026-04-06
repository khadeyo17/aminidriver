// import 'dart:convert';

// import 'package:aminidriver/Container/utils/api_constant.dart';
// import 'package:aminidriver/Onboarding/driveronboardingscreen.dart';
// import 'package:aminidriver/Onboarding/user_role.dart';
// import 'package:aminidriver/Onboarding/vehicleonboardingscreen.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// // for baseUrl

// //enum UserRole { ownerOnly, driverOnly, ownerAndDriver }

// class RoleSelectionScreen extends StatefulWidget {
//   final bool isCorporate;
//   const RoleSelectionScreen({Key? key, required this.isCorporate})
//     : super(key: key);

//   @override
//   State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
// }

// class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
//   late final UserRole _selectedRole;

//   InputDecoration borderedDecoration(String label) {
//     return InputDecoration(
//       labelText: label,
//       border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
//       contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
//     );
//   }

//   @override
//   void initState() {
//     super.initState();
//     if (widget.isCorporate) {
//       _selectedRole = UserRole.owner;
//     }
//   }

//   void _continue() async {
//     if (_selectedRole.toString() == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please select a role to continue')),
//       );
//       return;
//     }

//     try {
//       final user = FirebaseAuth.instance.currentUser;
//       if (user == null) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(const SnackBar(content: Text("User not authenticated")));
//         return;
//       }

//       final idToken = await user.getIdToken(true);

//       // Convert enum to string
//       final roleString = _selectedRole.toString().split('.').last;

//       // 🔁 Send role to backend
//       final response = await http.post(
//         Uri.parse('$baseUrl/auth/update-role'),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({
//           'token': idToken,
//           'role': roleString, // e.g. "driverOnly"
//         }),
//       );

//       if (response.statusCode != 200) {
//         throw Exception("Backend error: ${response.body}");
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text("Failed to update role: $e")));
//       return;
//     }

//     // ➡️ Then continue to navigation
//     // switch (_selectedRole) {
//     //   case UserRole.driver:
//     //     Navigator.push(
//     //       context,
//     //       MaterialPageRoute(
//     //         builder:
//     //             (_) => DriverOnboardingScreen(
//     //               onCompleted: () {},
//     //               skipVehicleOnboarding: true,
//     //             ),
//     //       ),
//     //     );
//     //     break;

//     //   case UserRole.owner:
//     //     Navigator.push(
//     //       context,
//     //       MaterialPageRoute(
//     //         builder:
//     //             (_) => VehicleOnboardingScreen(
//     //               skipDriverOnboarding: true,
//     //               hasownerOnboarding: true,
//     //             ),
//     //       ),
//     //     );
//     //     break;

//     //   case UserRole.driverOwner:
//     //     Navigator.push(
//     //       context,
//     //       MaterialPageRoute(
//     //         builder:
//     //             (_) => DriverOnboardingScreen(
//     //               onCompleted: () {
//     //                 Navigator.pushReplacement(
//     //                   context,
//     //                   MaterialPageRoute(
//     //                     builder:
//     //                         (_) => VehicleOnboardingScreen(
//     //                           skipDriverOnboarding: true,
//     //                         ),
//     //                   ),
//     //                 );
//     //               },
//     //               skipVehicleOnboarding: false,
//     //             ),
//     //       ),
//     //     );
//     //     break;
//     //   case UserRole.passenger:
//     //     // TODO: Handle this case.
//     //     throw UnimplementedError();
//     //   case UserRole.admin:
//     //     // TODO: Handle this case.
//     //     throw UnimplementedError();
//     // }

//     switch (_selectedRole) {
//       case UserRole.driver:
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (_) => DriverOnboardingScreen(role: UserRole.driver),
//           ),
//         );
//         break;
//       case UserRole.owner:
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (_) => DriverOnboardingScreen(role: UserRole.owner),
//           ),
//         );
//         break;

//       case UserRole.driverOwner:
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (_) => DriverOnboardingScreen(role: UserRole.driverOwner),
//           ),
//         );
//         break;
//       case UserRole.passenger:
//         // TODO: Handle this case.
//         throw UnimplementedError();
//       case UserRole.admin:
//         // TODO: Handle this case.
//         throw UnimplementedError();
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Select Your Role')),
//       body: Padding(
//         padding: const EdgeInsets.all(20.0),
//         child: Column(
//           children: [
//             Container(
//               decoration: borderedBoxDecoration(),
//               margin: const EdgeInsets.only(bottom: 12),
//               padding: const EdgeInsets.symmetric(horizontal: 12),
//               child:
//               // RadioListTile<UserRole>(
//               //   title: const Text('Register as Driver Only'),
//               //   value: UserRole.driverOnly,
//               //   groupValue: _selectedRole,
//               //   onChanged: (val) {
//               //     setState(() {
//               //       _selectedRole = val;
//               //     });
//               //   },
//               // ),
//               RadioListTile<UserRole>(
//                 title: const Text('Register as Driver Only'),
//                 value: UserRole.driver,
//                 groupValue: _selectedRole,
//                 onChanged:
//                     widget.isCorporate
//                         ? null
//                         : (val) {
//                           setState(() {
//                             _selectedRole = val!;
//                           });
//                         },
//                 activeColor: widget.isCorporate ? Colors.grey : Colors.blue,
//               ),
//             ),
//             Container(
//               decoration: borderedBoxDecoration(),
//               margin: const EdgeInsets.only(bottom: 12),
//               padding: const EdgeInsets.symmetric(horizontal: 12),
//               child:
//               // RadioListTile<UserRole>(
//               //   title: const Text('Register as Vehicle Owner Only'),
//               //   value: UserRole.ownerOnly,
//               //   groupValue: _selectedRole,
//               //   onChanged: (val) {
//               //     setState(() {
//               //       _selectedRole = val;
//               //     });
//               //   },
//               // ),
//               RadioListTile<UserRole>(
//                 title: const Text('Register as Vehicle Owner Only'),
//                 value: UserRole.owner,
//                 groupValue: _selectedRole,
//                 onChanged: (val) {
//                   setState(() {
//                     _selectedRole = val!;
//                   });
//                 },
//               ),
//             ),
//             Container(
//               decoration: borderedBoxDecoration(),
//               margin: const EdgeInsets.only(bottom: 12),
//               padding: const EdgeInsets.symmetric(horizontal: 12),
//               child:
//               // RadioListTile<UserRole>(
//               //   title: const Text('Register as Both Driver and Vehicle Owner'),
//               //   value: UserRole.ownerAndDriver,
//               //   groupValue: _selectedRole,
//               //   onChanged: (val) {
//               //     setState(() {
//               //       _selectedRole = val;
//               //     });
//               //   },
//               // ),
//               RadioListTile<UserRole>(
//                 title: const Text('Register as Both Driver and Vehicle Owner'),
//                 value: UserRole.driverOwner,
//                 groupValue: _selectedRole,
//                 onChanged:
//                     widget.isCorporate
//                         ? null
//                         : (val) {
//                           setState(() {
//                             _selectedRole = val!;
//                           });
//                         },
//                 activeColor: widget.isCorporate ? Colors.grey : Colors.blue,
//               ),
//             ),
//             const SizedBox(height: 16),
//             ElevatedButton(
//               onPressed: _continue,
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.blue,
//                 foregroundColor: Colors.black,
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 40,
//                   vertical: 16,
//                 ),
//                 textStyle: const TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               child: const Text('Continue'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   BoxDecoration borderedBoxDecoration() {
//     return BoxDecoration(
//       border: Border.all(color: Colors.grey.shade400),
//       borderRadius: BorderRadius.circular(8),
//     );
//   }
// }
