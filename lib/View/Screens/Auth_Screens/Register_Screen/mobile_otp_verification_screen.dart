import 'dart:convert';
import 'package:aminidriver/Container/utils/api_constant.dart';
import 'package:aminidriver/Container/utils/keys.dart';
import 'package:aminidriver/Onboarding/driveronboardingscreen.dart';
import 'package:aminidriver/Onboarding/user_role.dart';
import 'package:aminidriver/View/Routes/routes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:sms_autofill/sms_autofill.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final String method;

  const OTPVerificationScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    required this.method,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen>
    with CodeAutoFill {
  String otpCode = '';
  bool isLoading = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    listenForCode();
  }

  @override
  void dispose() {
    cancel();
    super.dispose();
  }

  @override
  void codeUpdated() {
    final incomingCode = code;
    if (incomingCode != null && incomingCode.length == 6) {
      setState(() => otpCode = incomingCode);
      verifyOTP();
    }
  }

  Future<void> handlePostLogin(User? user) async {
    if (user == null) return;

    final uid = user.uid;
    final phone = user.phoneNumber ?? '';
    final email = user.email ?? '';
    final token = await user.getIdToken();
    final fcmToken = await FirebaseMessaging.instance.getToken();

    bool hasBackendData = false;
    bool hasFirestoreData = false;

    try {
      // 1️⃣ Check Backend
      final response = await http.get(
        Uri.parse('http://192.168.100.160:7047/api/auth/check-user/$uid'),
        headers: {
          'Content-Type': 'application/json',
          //'Authorization': 'Bearer $token',
        },
      );

      //String? fullNameFromBackend;
      String? phoneFromBackend;

      if (response.statusCode == 200) {
        final backendData = jsonDecode(response.body);
        phoneFromBackend = backendData['phone'];
        hasBackendData =
            phoneFromBackend != null && phoneFromBackend.trim().isNotEmpty;

        final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
        final userDoc = await userRef.get();

        if (!userDoc.exists) {
          await userRef.set({
            'uid': uid,
            'phone': phone,
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        final firestoreData = (await userRef.get()).data();
        hasFirestoreData =
            firestoreData != null &&
            firestoreData['firstName'] != null &&
            firestoreData['lastName'] != null &&
            firestoreData['email'] != null;

        if (hasBackendData) {
          final int roleIndex = backendData['role'] ?? 0;
          final UserRole role = UserRole.values[roleIndex];

          final bool isApproved = backendData['isApproved'] ?? false;

          final response = await http.post(
            Uri.parse('$baseUrl/auth/update-fcm-token'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'token': token, // Firebase ID token
              'fcmToken': fcmToken, // Device's FCM token
            }),
          );
          if (response.statusCode == 200) {
            if (isApproved) {
              context.goNamed(Routes().navigationScreen);
              return;
            }

            if (role == UserRole.passenger) {
              // do something
              return;
            }

            switch (role) {
              case UserRole.driver:
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => DriverOnboardingScreen(role: UserRole.driver),
                  ),
                );
                break;

              case UserRole.owner:
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => DriverOnboardingScreen(role: UserRole.owner),
                  ),
                );
                break;
              case UserRole.driverOwner:
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) =>
                            DriverOnboardingScreen(role: UserRole.driverOwner),
                  ),
                );
                break;

              case UserRole.passenger:
              default:
                context.goNamed(Routes().navigationScreen);
                break;
            }

            // context.goNamed(Routes().home);
          } else {
            debugPrint("Failed to validate token, contact amini support");
          }
        } else {
          context.goNamed(Routes().profilesetupscreen);
          // debugPrint("Failed to validate user, contact amini support");
        }
      } else {
        context.goNamed(Routes().profilesetupscreen);
      }
    } catch (e) {
      debugPrint("Backend or Firestore check failed: $e");
      // Optionally: navigate to error screen or retry
    }
  }

  // Future<void> handlePostLogin(User? user) async {
  //   if (user == null) return;

  //   final uid = user.uid;
  //   final phone = user.phoneNumber ?? '';
  //   final email = user.email ?? '';
  //   final token = await user.getIdToken();
  //   final fcmToken = await FirebaseMessaging.instance.getToken();

  //   try {
  //     final response = await http.get(
  //       Uri.parse('$baseUrl/auth/check-user/$uid'),
  //       headers: {
  //         'Content-Type': 'application/json',
  //         'Authorization': 'Bearer $token',
  //       },
  //     );

  //     if (response.statusCode == 200) {
  //       final backendData = jsonDecode(response.body);
  //       final phoneFromBackend = backendData['phone'];

  //       final hasBackendData =
  //           phoneFromBackend != null && phoneFromBackend.trim().isNotEmpty;

  //       final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
  //       if (!(await userRef.get()).exists) {
  //         await userRef.set({
  //           'uid': uid,
  //           'phone': phone,
  //           'email': email,
  //           'createdAt': FieldValue.serverTimestamp(),
  //         });
  //       }

  //       if (hasBackendData) {
  //         await http.post(
  //           Uri.parse('$baseUrl/auth/update-fcm-token'),
  //           headers: {
  //             'Content-Type': 'application/json',
  //             'Authorization': 'Bearer $token',
  //           },
  //           body: jsonEncode({'token': token, 'fcmToken': fcmToken}),
  //         );
  //         context.goNamed(Routes().home);
  //       } else {
  //         context.goNamed(Routes().profilesetupscreen);
  //       }
  //     } else {
  //       context.goNamed(Routes().profilesetupscreen);
  //     }
  //   } catch (e) {
  //     debugPrint("Backend or Firestore check failed: $e");
  //   }
  // }

  Future<void> verifyOTP() async {
    if (_isVerifying) return;
    if (otpCode.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid 6-digit OTP")),
      );
      return;
    }

    setState(() => isLoading = true);
    _isVerifying = true;

    try {
      if (widget.method == 'sms') {
        final credential = PhoneAuthProvider.credential(
          verificationId: widget.verificationId,
          smsCode: otpCode,
        );
        final userCredential = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );
        await handlePostLogin(userCredential.user);
      } else if (widget.method == 'whatsapp') {
        final response = await http.post(
          Uri.parse("$baseUrl/auth/VerifyWhatsappOTP"),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'phone': widget.phoneNumber, 'otp': otpCode}),
        );

        final body = jsonDecode(response.body);
        if (body['verified'] != true || body['firebaseToken'] == null) {
          throw Exception(body['error'] ?? 'Verification failed');
        }

        final userCredential = await FirebaseAuth.instance
            .signInWithCustomToken(body['firebaseToken'] as String);
        await handlePostLogin(userCredential.user);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Verification failed: $e")));
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          _isVerifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        // width: size.width,
        // height: size.height,
        // decoration: const BoxDecoration(
        //   gradient: LinearGradient(
        //     colors: [Colors.., Color(0xFF2575FC)],
        //     begin: Alignment.topLeft,
        //     end: Alignment.bottomRight,
        //   ),
        // ),
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple, Colors.grey.shade900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.goNamed(Routes().register),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Center(
                    child: Container(
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 20),
                          const Icon(
                            Icons.lock_outline,
                            size: 60,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Verify OTP",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Enter the 6-digit code sent to",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.phoneNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 32),
                          PinFieldAutoFill(
                            codeLength: 6,
                            decoration: UnderlineDecoration(
                              textStyle: const TextStyle(
                                fontSize: 22,
                                color: Colors.white,
                              ),
                              colorBuilder: FixedColorBuilder(
                                Colors.white.withOpacity(0.8),
                              ),
                            ),
                            currentCode: otpCode,
                            onCodeChanged: (code) {
                              if (code != null && code.length == 6) {
                                setState(() => otpCode = code);
                                verifyOTP();
                              }
                            },
                          ),
                          const SizedBox(height: 30),
                          GestureDetector(
                            onTap: isLoading ? null : verifyOTP,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                // gradient: const LinearGradient(
                                //   colors: [
                                //     Color(0xFFFF512F),
                                //     Color(0xFFF09819),
                                //   ],
                                // ),
                                color: Colors.grey[700],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child:
                                    isLoading
                                        ? const CircularProgressIndicator(
                                          color: Colors.white,
                                        )
                                        : const Text(
                                          "Verify",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              // resend OTP logic
                            },
                            child: const Text(
                              "Send OTP Again",
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// import 'dart:convert';

// import 'package:aminidriver/Container/utils/api_constant.dart';
// import 'package:aminidriver/Onboarding/driveronboardingscreen.dart';
// import 'package:aminidriver/Onboarding/user_role.dart';
// import 'package:aminidriver/View/Routes/routes.dart';
// import 'package:aminidriver/View/Screens/Auth_Screens/Driver_config/driver_config.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:go_router/go_router.dart';
// import 'package:http/http.dart' as http;
// import 'package:sms_autofill/sms_autofill.dart';

// class OTPVerificationScreen extends StatefulWidget {
//   final String verificationId;
//   final String phoneNumber;
//   final String method;

//   const OTPVerificationScreen({
//     super.key,
//     required this.verificationId,
//     required this.phoneNumber,
//     required this.method,
//   });

//   @override
//   State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
// }

// class _OTPVerificationScreenState extends State<OTPVerificationScreen>
//     with CodeAutoFill {
//   String otpCode = '';
//   bool isLoading = false;
//   bool _isVerifying = false;

//   @override
//   void initState() {
//     super.initState();
//     listenForCode(); // Start listening for SMS autofill
//   }

//   @override
//   void dispose() {
//     cancel(); // Stop listening when screen closes
//     super.dispose();
//   }

//   @override
//   void codeUpdated() {
//     final incomingCode = code;
//     if (incomingCode != null && incomingCode.length == 6) {
//       setState(() {
//         otpCode = incomingCode;
//       });
//       verifyOTP();
//     }
//   }

//   Future<void> handlePostLogin(User? user) async {
//     if (user == null) return;

//     final uid = user.uid;
//     final phone = user.phoneNumber ?? '';
//     final email = user.email ?? '';
//     final token = await user.getIdToken();
//     final fcmToken = await FirebaseMessaging.instance.getToken();

//     bool hasBackendData = false;
//     bool hasFirestoreData = false;

//     try {
//       // 1️⃣ Check Backend
//       final response = await http.get(
//         Uri.parse('$baseUrl/auth/check-user/$uid'),
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $token',
//         },
//       );

//       //String? fullNameFromBackend;
//       String? phoneFromBackend;

//       if (response.statusCode == 200) {
//         final backendData = jsonDecode(response.body);
//         phoneFromBackend = backendData['phone'];
//         hasBackendData =
//             phoneFromBackend != null && phoneFromBackend.trim().isNotEmpty;

//         final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
//         final userDoc = await userRef.get();

//         if (!userDoc.exists) {
//           await userRef.set({
//             'uid': uid,
//             'phone': phone,
//             'email': email,
//             'createdAt': FieldValue.serverTimestamp(),
//           });
//         }

//         final firestoreData = (await userRef.get()).data();
//         hasFirestoreData =
//             firestoreData != null &&
//             firestoreData['firstName'] != null &&
//             firestoreData['lastName'] != null &&
//             firestoreData['email'] != null;

//         if (hasBackendData) {
//           final int roleIndex = backendData['role'] ?? 0;
//           final UserRole role = UserRole.values[roleIndex];

//           final bool isApproved = backendData['isApproved'] ?? false;

//           final response = await http.post(
//             Uri.parse('$baseUrl/auth/update-fcm-token'),
//             headers: {
//               'Content-Type': 'application/json',
//               'Authorization': 'Bearer $token',
//             },
//             body: jsonEncode({
//               'token': token, // Firebase ID token
//               'fcmToken': fcmToken, // Device's FCM token
//             }),
//           );
//           if (response.statusCode == 200) {
//             if (isApproved) {
//               context.goNamed(Routes().navigationScreen);
//               return;
//             }

//             if (role == UserRole.passenger) {
//               // do something
//               return;
//             }

//             switch (role) {
//               case UserRole.driver:
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder:
//                         (_) => DriverOnboardingScreen(role: UserRole.driver),
//                   ),
//                 );
//                 break;

//               case UserRole.owner:
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder:
//                         (_) => DriverOnboardingScreen(role: UserRole.owner),
//                   ),
//                 );
//                 break;
//               case UserRole.driverOwner:
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder:
//                         (_) =>
//                             DriverOnboardingScreen(role: UserRole.driverOwner),
//                   ),
//                 );
//                 break;

//               case UserRole.passenger:
//               default:
//                 context.goNamed(Routes().navigationScreen);
//                 break;
//             }

//             // context.goNamed(Routes().home);
//           } else {
//             debugPrint("Failed to validate token, contact amini support");
//           }
//         } else {
//           context.goNamed(Routes().profilesetupscreen);
//           // debugPrint("Failed to validate user, contact amini support");
//         }
//       } else {
//         context.goNamed(Routes().profilesetupscreen);
//       }
//     } catch (e) {
//       debugPrint("Backend or Firestore check failed: $e");
//       // Optionally: navigate to error screen or retry
//     }
//   }

//   // Future<void> handlePostLogin(User? user) async {
//   //   if (user == null) return;

//   //   final uid = user.uid;
//   //   final phone = user.phoneNumber ?? '';
//   //   final email = user.email ?? '';
//   //   //final firstName = user.displayName ?? '';
//   //   final token = await user.getIdToken();

//   //   // 1️⃣ Check backend
//   //   bool hasBackendData = false;
//   //   String? fullNameFromBackend;
//   //   String? phoneFromBackend;

//   //   try {
//   //     // 1️⃣ Check Backend
//   //     final response = await http.get(
//   //       Uri.parse('$baseUrl/auth/check-user/$uid'),
//   //     );

//   //     String? fullName;
//   //     String? email;

//   //     if (response.statusCode == 200) {
//   //       final backendData = jsonDecode(response.body);
//   //       fullName = backendData['fullName'];
//   //       email = backendData['email'];
//   //     }

//   //     final hasBackendData =
//   //         fullName != null &&
//   //         fullName.trim().isNotEmpty &&
//   //         email != null &&
//   //         email.trim().isNotEmpty;

//   //     // 2️⃣ Check Firestore
//   //     final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
//   //     final userDoc = await userRef.get();

//   //     if (!userDoc.exists) {
//   //       await userRef.set({
//   //         'uid': uid,
//   //         'phone': phone, // make sure 'phone' is passed in
//   //         'email': email,
//   //         'createdAt': FieldValue.serverTimestamp(),
//   //       });
//   //     }

//   //     final firestoreData = (await userRef.get()).data();
//   //     final hasFirestoreData =
//   //         firestoreData != null &&
//   //         firestoreData['firstName'] != null &&
//   //         firestoreData['lastName'] != null &&
//   //         firestoreData['email'] != null;

//   //     // 3️⃣ Route Based on Results
//   //     if (hasBackendData && hasFirestoreData) {
//   //       context.goNamed(Routes().home);
//   //     } else {
//   //       context.goNamed(Routes().profilesetupscreen);
//   //     }
//   //   } catch (e) {
//   //     debugPrint("Backend or Firestore check failed: $e");
//   //     // Optionally route to an error page or fallback
//   //   }

//   //   // 2️⃣ Check Firestore
//   //   final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
//   //   final userDoc = await userRef.get();

//   //   if (!userDoc.exists) {
//   //     await userRef.set({
//   //       'uid': uid,
//   //       'phone': phone,
//   //       'email': email,
//   //       'createdAt': FieldValue.serverTimestamp(),
//   //     });
//   //   }

//   //   final data = (await userRef.get()).data();
//   //   final hasFirestoreData =
//   //       data != null &&
//   //       data['firstName'] != null &&
//   //       data['lastName'] != null &&
//   //       data['email'] != null;

//   //   // 3️⃣ Route based on both checks
//   //   if (hasBackendData && hasFirestoreData) {
//   //     context.goNamed(Routes().home);
//   //   } else {
//   //     context.goNamed(Routes().profilesetupscreen);
//   //   }
//   // }

//   // Future<void> handlePostLogin(User? user) async {
//   //   if (user == null) return;

//   //   final userRef = FirebaseFirestore.instance
//   //       .collection('users')
//   //       .doc(user.uid);
//   //   final userDoc = await userRef.get();

//   //   if (!userDoc.exists) {
//   //     await userRef.set({
//   //       'uid': user.uid,
//   //       'phone': user.phoneNumber ?? widget.phoneNumber,
//   //       'isAnonymous': user.isAnonymous,
//   //       'createdAt': FieldValue.serverTimestamp(),
//   //     });
//   //   }

//   //   final data = (await userRef.get()).data();
//   //   if (!mounted) return;

//   //   if (data != null &&
//   //       data['firstName'] != null &&
//   //       data['lastName'] != null &&
//   //       data['email'] != null) {
//   //     context.goNamed(Routes().home);
//   //   } else {
//   //     context.goNamed(Routes().profilesetupscreen);
//   //   }
//   // }

//   // Future<void> verifyOTP() async {
//   //   if (_isVerifying) return;

//   //   if (otpCode.length < 6) {
//   //     ScaffoldMessenger.of(context).showSnackBar(
//   //       const SnackBar(content: Text("Enter a valid 6-digit OTP")),
//   //     );
//   //     return;
//   //   }

//   //   setState(() => isLoading = true);
//   //   _isVerifying = true;

//   //   try {
//   //     if (widget.method == 'sms') {
//   //       // Firebase SMS verification
//   //       if (widget.verificationId.isEmpty) {
//   //         throw Exception("Verification ID is missing.");
//   //       }

//   //       final credential = PhoneAuthProvider.credential(
//   //         verificationId: widget.verificationId,
//   //         smsCode: otpCode,
//   //       );

//   //       final userCredential = await FirebaseAuth.instance.signInWithCredential(
//   //         credential,
//   //       );

//   //       await handlePostLogin(userCredential.user);
//   //     } else if (widget.method == 'whatsapp') {
//   //       // Backend WhatsApp verification
//   //       final response = await http.post(
//   //         Uri.parse("$baseUrl/auth/VerifyWhatsappOTP"),
//   //         headers: {'Content-Type': 'application/json'},
//   //         body: jsonEncode({'phone': widget.phoneNumber, 'otp': otpCode}),
//   //       );

//   //       final data = jsonDecode(response.body);
//   //       if (response.statusCode == 200 && data['verified'] == true) {
//   //         final data = jsonDecode(response.body);
//   //         final customToken = data['firebaseToken']; // Issued by your backend
//   //         final userCredential = await FirebaseAuth.instance
//   //             .signInWithCustomToken(customToken);
//   //         await handlePostLogin(userCredential.user);
//   //         final user = userCredential.user;

//   //         if (user != null) {
//   //           await handlePostLogin(user);
//   //         } else {
//   //           throw Exception("Firebase anonymous login failed.");
//   //         }
//   //       } else {
//   //         throw Exception(data['error'] ?? 'Verification failed');
//   //       }
//   //     }
//   //   } catch (e) {
//   //     setState(() => isLoading = false);
//   //     _isVerifying = false;
//   //     ScaffoldMessenger.of(
//   //       context,
//   //     ).showSnackBar(SnackBar(content: Text("Verification failed: $e")));
//   //   }
//   // }

//   Future<void> verifyOTP() async {
//     if (_isVerifying) return;
//     if (otpCode.length < 6) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Enter a valid 6-digit OTP")),
//       );
//       return;
//     }

//     setState(() => isLoading = true);
//     _isVerifying = true;

//     try {
//       if (widget.method == 'sms') {
//         // Firebase SMS verification
//         if (widget.verificationId.isEmpty) {
//           throw Exception("Verification ID is missing.");
//         }
//         final credential = PhoneAuthProvider.credential(
//           verificationId: widget.verificationId,
//           smsCode: otpCode,
//         );
//         final userCredential = await FirebaseAuth.instance.signInWithCredential(
//           credential,
//         );
//         await handlePostLogin(userCredential.user);
//       } else if (widget.method == 'whatsapp') {
//         // Backend WhatsApp verification → returns firebaseCustomToken
//         final response = await http.post(
//           Uri.parse("$baseUrl/auth/VerifyWhatsappOTP"),
//           headers: {'Content-Type': 'application/json'},
//           body: jsonEncode({'phone': widget.phoneNumber, 'otp': otpCode}),
//         );

//         if (response.statusCode != 200) {
//           final err =
//               jsonDecode(response.body)['error'] ?? 'Verification failed';
//           throw Exception(err);
//         }

//         final body = jsonDecode(response.body);
//         if (body['verified'] != true || body['firebaseToken'] == null) {
//           throw Exception(body['error'] ?? 'Verification failed');
//         }

//         // Sign in with the custom token
//         final userCredential = await FirebaseAuth.instance
//             .signInWithCustomToken(body['firebaseToken'] as String);

//         await handlePostLogin(userCredential.user);
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text("Verification failed: $e")));
//     } finally {
//       if (mounted) {
//         setState(() {
//           isLoading = false;
//           _isVerifying = false;
//         });
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final height = MediaQuery.of(context).size.height;

//     return Scaffold(
//       backgroundColor: Colors.white, //backgroundColor: Colors.grey[100]
//       body: Stack(
//         children: [
//           // White Panel covering fullscreen
//           Container(
//             height: height,
//             width: double.infinity,
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: const BorderRadius.vertical(
//                 top: Radius.circular(30),
//               ),
//             ),
//             margin: const EdgeInsets.only(top: 120),
//           ),
//           // AppBar-style back and title
//           SafeArea(
//             child: IconButton(
//               icon: const Icon(Icons.arrow_back, color: Colors.grey),
//               onPressed: () => context.goNamed(Routes().register),
//             ),
//           ),
//           // Main Content
//           Align(
//             alignment: Alignment.center,
//             child: SingleChildScrollView(
//               padding: const EdgeInsets.symmetric(horizontal: 24),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   const SizedBox(height: 120),
//                   Text(
//                     "Verify OTP",
//                     style: Theme.of(context).textTheme.headlineSmall?.copyWith(
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const SizedBox(height: 12),
//                   Text(
//                     "Enter the 6-digit code sent to",
//                     style: Theme.of(context).textTheme.bodyMedium,
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     widget.phoneNumber,
//                     style: const TextStyle(
//                       fontWeight: FontWeight.bold,
//                       fontSize: 16,
//                       color: Colors.blue,
//                     ),
//                   ),
//                   const SizedBox(height: 32),
//                   PinFieldAutoFill(
//                     codeLength: 6,
//                     decoration: BoxLooseDecoration(
//                       gapSpace: 10,
//                       strokeWidth: 2,
//                       textStyle: const TextStyle(
//                         fontSize: 20,
//                         color: Colors.black,
//                       ),
//                       bgColorBuilder: FixedColorBuilder(Colors.grey.shade200),
//                       strokeColorBuilder: FixedColorBuilder(Colors.blue),
//                       radius: const Radius.circular(8),
//                     ),
//                     currentCode: otpCode,
//                     onCodeChanged: (code) {
//                       if (code != null && code.length == 6) {
//                         setState(() => otpCode = code);
//                         verifyOTP();
//                       }
//                     },
//                   ),
//                   const SizedBox(height: 16),
//                   ElevatedButton(
//                     onPressed: isLoading ? null : verifyOTP,
//                     style: ElevatedButton.styleFrom(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 40,
//                         vertical: 12,
//                       ),
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ),
//                     child:
//                         isLoading
//                             ? const CircularProgressIndicator(
//                               color: Colors.white,
//                             )
//                             : const Text("Verify"),
//                   ),
//                   const SizedBox(height: 12),
//                   TextButton(
//                     onPressed: () {
//                       // Optionally re-send OTP logic here
//                     },
//                     child: const Text(
//                       "Send OTP Again",
//                       style: TextStyle(color: Colors.blue),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // @override
//   // Widget build(BuildContext context) {
//   //   return Scaffold(
//   //     appBar: AppBar(
//   //       title: const Text("Verify OTP"),
//   //       leading: IconButton(
//   //         icon: const Icon(Icons.arrow_back),
//   //         onPressed: () => context.goNamed(Routes().register),
//   //       ),
//   //     ),
//   //     body: Padding(
//   //       padding: const EdgeInsets.all(20),
//   //       child: Column(
//   //         mainAxisAlignment: MainAxisAlignment.center,
//   //         children: [
//   //           Text("Enter the 6-digit code sent to ${widget.phoneNumber}."),
//   //           const SizedBox(height: 20),

//   //           // PinFieldAutoFill(
//   //           //   codeLength: 6,
//   //           //   decoration: UnderlineDecoration(
//   //           //     textStyle: const TextStyle(fontSize: 20, color: Colors.black),
//   //           //     colorBuilder: FixedColorBuilder(Colors.blue),
//   //           //   ),
//   //           //   currentCode: otpCode,
//   //           //   onCodeChanged: (code) {
//   //           //     if (code != null && code.length == 6) {
//   //           //       setState(() => otpCode = code);
//   //           //       verifyOTP();
//   //           //     }
//   //           //   },
//   //           // ),
//   //           PinFieldAutoFill(
//   //             codeLength: 6,
//   //             decoration: BoxLooseDecoration(
//   //               gapSpace: 10,
//   //               strokeWidth: 2,
//   //               textStyle: const TextStyle(fontSize: 20, color: Colors.black),
//   //               bgColorBuilder: FixedColorBuilder(Colors.grey.shade200),
//   //               strokeColorBuilder: FixedColorBuilder(Colors.blue),
//   //               radius: const Radius.circular(8),
//   //             ),
//   //             currentCode: otpCode,
//   //             onCodeChanged: (code) {
//   //               if (code != null && code.length == 6) {
//   //                 setState(() => otpCode = code);
//   //                 verifyOTP();
//   //               }
//   //             },
//   //           ),

//   //           const SizedBox(height: 20),
//   //           ElevatedButton(
//   //             onPressed: isLoading ? null : verifyOTP,
//   //             child:
//   //                 isLoading
//   //                     ? const CircularProgressIndicator(color: Colors.white)
//   //                     : const Text("Verify"),
//   //           ),
//   //         ],
//   //       ),
//   //     ),
//   //   );
//   // }
// }
// // import 'dart:async';
// // import 'package:cloud_firestore/cloud_firestore.dart';
// // import 'package:flutter/material.dart';
// // import 'package:firebase_auth/firebase_auth.dart';
// // import 'package:go_router/go_router.dart';
// // import 'package:niceapp/View/Routes/routes.dart';
// // import 'package:sms_autofill/sms_autofill.dart';
// // //import 'profile_setup_screen.dart';

// // class OTPVerificationScreen extends StatefulWidget {
// //   final String verificationId;
// //   final String phoneNumber;

// //   const OTPVerificationScreen({
// //     super.key,
// //     required this.verificationId,
// //     required this.phoneNumber,
// //   });

// //   @override
// //   State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
// // }

// // class _OTPVerificationScreenState extends State<OTPVerificationScreen>
// //     with CodeAutoFill {
// //   String otpCode = '';
// //   bool isLoading = false;
// //   bool _isVerifying = false;

// //   // Resend OTP fields
// //   late String currentVerificationId;
// //   int _resendToken = 0;
// //   bool canResend = false;
// //   int resendCooldown = 60;
// //   Timer? _resendTimer;

// //   // void registerSmsListener() {
// //   //   listenForCode(); // From CodeAutoFill
// //   //   unregisterListener(); // This will work only if you import correctly
// //   // }

// //   @override
// //   void initState() {
// //     super.initState();
// //     currentVerificationId = widget.verificationId;
// //     listenForCode();
// //     //unregisterListener(this);
// //     startResendCooldown();
// //   }

// //   @override
// //   void dispose() {
// //     cancel();
// //     _resendTimer?.cancel();
// //     super.dispose();
// //   }

// //   void startResendCooldown() {
// //     setState(() {
// //       canResend = false;
// //       resendCooldown = 60;
// //     });

// //     _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
// //       if (resendCooldown <= 1) {
// //         timer.cancel();
// //         setState(() => canResend = true);
// //       } else {
// //         setState(() => resendCooldown--);
// //       }
// //     });
// //   }

// //   void codeUpdated() {
// //     final incomingCode = code;
// //     if (incomingCode != null && incomingCode.length == 6) {
// //       setState(() => otpCode = incomingCode);
// //       verifyOTP();
// //     }
// //   }

// //   Future<void> resendOTP() async {
// //     setState(() => isLoading = true);

// //     await FirebaseAuth.instance.verifyPhoneNumber(
// //       phoneNumber: widget.phoneNumber,
// //       forceResendingToken: _resendToken,
// //       timeout: const Duration(seconds: 60),
// //       verificationCompleted: (PhoneAuthCredential credential) {},
// //       verificationFailed: (FirebaseAuthException e) {
// //         ScaffoldMessenger.of(
// //           context,
// //         ).showSnackBar(SnackBar(content: Text("Resend failed: ${e.message}")));
// //         setState(() => isLoading = false);
// //       },
// //       codeSent: (String newVerificationId, int? resendToken) {
// //         setState(() {
// //           currentVerificationId = newVerificationId;
// //           _resendToken = resendToken ?? 0;
// //           isLoading = false;
// //         });
// //         startResendCooldown();
// //         ScaffoldMessenger.of(context).showSnackBar(
// //           const SnackBar(content: Text("OTP resent successfully.")),
// //         );
// //       },
// //       codeAutoRetrievalTimeout: (String verificationId) {},
// //     );
// //   }

// //   Future<void> verifyOTP() async {
// //     if (_isVerifying) return;
// //     if (currentVerificationId.isEmpty) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         const SnackBar(content: Text("Verification ID is missing.")),
// //       );
// //       return;
// //     }

// //     if (otpCode.length < 6) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         const SnackBar(content: Text("Enter a valid 6-digit OTP")),
// //       );
// //       return;
// //     }

// //     setState(() => isLoading = true);
// //     _isVerifying = true;

// //     try {
// //       final credential = PhoneAuthProvider.credential(
// //         verificationId: currentVerificationId,
// //         smsCode: otpCode,
// //       );

// //       final userCredential = await FirebaseAuth.instance.signInWithCredential(
// //         credential,
// //       );
// //       final user = userCredential.user;

// //       if (user != null) {
// //         final userDoc =
// //             await FirebaseFirestore.instance
// //                 .collection('users')
// //                 .doc(user.uid)
// //                 .get();

// //         final data = userDoc.data();

// //         if (!mounted) return;

// //         if (data != null &&
// //             data['firstName'] != null &&
// //             data['lastName'] != null &&
// //             data['email'] != null) {
// //           context.goNamed(Routes().home);
// //         } else {
// //           context.goNamed(Routes().profilesetupscreen);
// //         }
// //       }
// //     } on FirebaseAuthException catch (e) {
// //       setState(() => isLoading = false);
// //       _isVerifying = false;
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         SnackBar(content: Text("Verification failed: ${e.message}")),
// //       );
// //     } catch (e) {
// //       setState(() => isLoading = false);
// //       _isVerifying = false;
// //       ScaffoldMessenger.of(
// //         context,
// //       ).showSnackBar(SnackBar(content: Text("Unexpected error: $e")));
// //     }
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Scaffold(
// //       appBar: AppBar(
// //         title: const Text("Verify OTP"),
// //         leading: IconButton(
// //           icon: const Icon(Icons.arrow_back),
// //           onPressed: () => Navigator.pop(context),
// //         ),
// //       ),
// //       body: Padding(
// //         padding: const EdgeInsets.all(20),
// //         child: Column(
// //           mainAxisAlignment: MainAxisAlignment.center,
// //           children: [
// //             Text("Enter the 6-digit code sent to ${widget.phoneNumber}."),
// //             const SizedBox(height: 20),
// //             // PinFieldAutoFill(
// //             //   codeLength: 6,
// //             //   decoration: UnderlineDecoration(
// //             //     textStyle: const TextStyle(fontSize: 20, color: Colors.black),
// //             //     colorBuilder: FixedColorBuilder(Colors.blue),
// //             //   ),
// //             //   onCodeChanged: (code) {
// //             //     if (code != null && code.length == 6) {
// //             //       otpCode = code;
// //             //       verifyOTP(); // auto-submit when complete
// //             //     }
// //             //   },
// //             // ),
// //             PinFieldAutoFill(
// //               codeLength: 6,
// //               decoration: UnderlineDecoration(
// //                 textStyle: const TextStyle(fontSize: 20, color: Colors.black),
// //                 colorBuilder: FixedColorBuilder(Colors.blue),
// //               ),
// //               currentCode: otpCode,
// //               onCodeChanged: (code) {
// //                 if (code != null && code.length == 6) {
// //                   setState(() => otpCode = code);
// //                   verifyOTP();
// //                 }
// //               },
// //             ),

// //             const SizedBox(height: 20),
// //             ElevatedButton(
// //               onPressed: isLoading ? null : verifyOTP,
// //               child:
// //                   isLoading
// //                       ? const CircularProgressIndicator(color: Colors.white)
// //                       : const Text("Verify"),
// //             ),
// //             const SizedBox(height: 20),
// //             TextButton(
// //               onPressed: canResend ? resendOTP : null,
// //               child: Text(
// //                 canResend ? "Resend OTP" : "Resend OTP in $resendCooldown sec",
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// // }
