import 'package:aminidriver/Container/utils/snackbar_utils.dart';
import 'package:aminidriver/Onboarding/role_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
//import 'package:aminidriver/Container/utils/api_constant.dart';

import '../../View/Routes/routes.dart';
import '../utils/error_notification.dart';

final globalAuthRepoProvider = Provider<AuthRepo>((ref) => AuthRepo());

class AuthRepo {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<bool> registerWithEmailPhonePassword({
    //required String fullName,
    required String email,
    required String phone,
    required String password,
    required BuildContext context,
  }) async {
    try {
      // Create user with Firebase
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        // Set display name
        // await user.updateDisplayName(fullName);

        // Send email verification
        await user.sendEmailVerification();

        return true; // ✅ Don't forget this!
      } else {
        showSnack(context, 'Firebase registration failed.');
        return false;
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        showSnack(context, 'Email already registered. Please log in.');
      } else {
        showSnack(context, 'Firebase error: ${e.message}');
      }
      return false;
    } catch (e) {
      showSnack(context, 'An unexpected error occurred: $e');
      return false;
    }
  }

  Future<void> loginWithEmailPassword({
    required String email,
    required String password,
    required BuildContext context,
    String? fullName, // Optional if syncing user
    String? phone, // Optional if syncing user
  }) async {
    try {
      // 🔐 Step 1: Sign in to Firebase
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      final firebaseId = user?.uid;

      if (user == null) {
        ErrorNotification().showError(context, "Login failed. Try again.");
        return;
      }

      await user.reload();

      if (!user.emailVerified) {
        ErrorNotification().showError(
          context,
          "Please verify your email before logging in.",
        );
        return;
      }
      context.goNamed(Routes().driverConfig);
      // Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(builder: (_) => ProfileScreen()),
      // );

      // 🔑 Step 2: Get Firebase ID token
      // final idToken = await user.getIdToken();

      // // 🌐 Step 3: Check if user exists in backend
      // final authResponse = await http.get(
      //   Uri.parse("$baseUrl/auth/check-user/${user.uid}"),
      //   headers: {HttpHeaders.authorizationHeader: 'Bearer $idToken'},
      // );

      // if (authResponse.statusCode == 200) {
      //   if (context.mounted) {
      //     context.goNamed(Routes().navigationScreen);
      //   }
      // } else if (authResponse.statusCode == 404) {
      //   // 👤 Not found in backend, create user
      //   fullName = user.displayName;
      //   phone = user.phoneNumber;
      //   // if (phone != null) {
      //   //   //fullName != null &&

      //   // } else {
      //   //   ErrorNotification().showError(context, 'Missing full name or phone.');
      //   // }
      //   final response = await http.post(
      //       Uri.parse('$baseUrl/auth/firebase-login'),
      //       headers: {
      //         HttpHeaders.contentTypeHeader: 'application/json',
      //         HttpHeaders.authorizationHeader: 'Bearer $idToken',
      //       },
      //       body: jsonEncode({
      //         "fullName": fullName,
      //         "email": email,
      //         "phoneNumber": phone,
      //         "role": "Driver",
      //         "token": idToken,
      //       }),
      //     );

      //     if (response.statusCode == 200 || response.statusCode == 201) {
      //       showSnack(context, 'login successful.');
      //     } else {
      //       showSnack(context, 'Failed to sync new user with backend.');
      //     }
      // } else {
      //   ErrorNotification().showError(
      //     context,
      //     'Backend login failed. (${authResponse.statusCode})',
      //   );
      // }
    } on FirebaseAuthException catch (e) {
      await _auth.signOut();
      ErrorNotification().showError(context, e.message ?? 'Login failed');
    } catch (e) {
      await _auth.signOut();
      ErrorNotification().showError(context, 'Unexpected error: $e');
    }
  }

  Future<void> sendPasswordResetEmail({
    required BuildContext context,
    required String email,
  }) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password reset email sent.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
    }
  }

  // Future<bool> loginWithEmailPassword({
  //   required String email,
  //   required String password,
  //   required BuildContext context,
  // }) async {
  //   try {
  //     final userCredential = await _auth.signInWithEmailAndPassword(
  //       email: email,
  //       password: password,
  //     );

  //     final user = userCredential.user;

  //     if (user == null) {
  //       ErrorNotification().showError(context, "Login failed. Try again.");
  //       return false;
  //     }

  //     await user.reload();

  //     if (!user.emailVerified) {
  //       ErrorNotification().showError(
  //         context,
  //         "Please verify your email before logging in.",
  //       );
  //       return false;
  //     }

  //     // ✅ Get Firebase ID token
  //     final idToken = await user.getIdToken();

  //     // ✅ Send token to your backend
  //     final response = await http.post(
  //       Uri.parse("http://192.168.100.160:7047/api/auth/firebase-login"),
  //       headers: {'Content-Type': 'application/json'},
  //       body: jsonEncode({"token": idToken}),
  //     );

  //     if (response.statusCode == 200) {
  //       // ✅ Now check if user has a vehicle
  //       final vehicleResponse = await http.get(
  //         Uri.parse(
  //           'http://192.168.100.160:7047/api/vehicle/has-vehicle?email=$email',
  //         ),
  //         headers: {'Content-Type': 'application/json'},
  //       );

  //       if (vehicleResponse.statusCode == 200) {
  //         final hasVehicle = jsonDecode(vehicleResponse.body)['hasVehicle'];

  //         if (hasVehicle == true) {
  //           // ✅ Navigate to main screen
  //           if (context.mounted) {
  //             context.go('/main-navigation');
  //           }
  //         } else {
  //           // 🚗 Navigate to vehicle onboarding
  //           if (context.mounted) {
  //             context.go('/vehicle-onboarding');
  //           }
  //         }
  //       } else {
  //         ErrorNotification().showError(
  //           context,
  //           'Failed to check vehicle status.',
  //         );
  //       }
  //     } else {
  //       ErrorNotification().showError(
  //         context,
  //         'Backend login failed. (${response.statusCode})',
  //       );
  //     }
  //   } on FirebaseAuthException catch (e) {
  //     await _auth.signOut();
  //     ErrorNotification().showError(context, e.message ?? 'Login failed');
  //   } catch (e) {
  //     await _auth.signOut();
  //     ErrorNotification().showError(context, 'Unexpected error: $e');
  //   }
  // }

  /// Login using email and password, only if email is verified
  // Future<void> loginWithEmailPassword({
  //   //required String fullame,
  //   required String email,
  //   required String password,
  //   required BuildContext context,
  // }) async {
  //   try {
  //     final userCredential = await _auth.signInWithEmailAndPassword(
  //       email: email,
  //       password: password,
  //     );

  //     final user = userCredential.user;

  //     if (user == null) {
  //       ErrorNotification().showError(
  //         context,
  //         "Login failed. Please try again.",
  //       );
  //       return;
  //     }
  //     await user.reload();
  //     if (!user.emailVerified) {
  //       //await user.sendEmailVerification();
  //       //await _auth.signOut();
  //       if (context.mounted) {
  //         ErrorNotification().showError(
  //           context,
  //           "Please verify your email before logging in.",
  //         );
  //       }
  //       return;
  //     }
  //   } on FirebaseAuthException catch (e) {
  //     await _auth.signOut();
  //     if (context.mounted) {
  //       ErrorNotification().showError(context, e.message ?? 'Login failed');
  //     }
  //   } catch (e) {
  //     await _auth.signOut();
  //     if (context.mounted) {
  //       ErrorNotification().showError(context, 'Unexpected error: $e');
  //     }
  //   }
  // }

  /// Sign in using Google account
  Future<void> signInWithGoogle(BuildContext context) async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final authResult = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final user = authResult.user;
      final idToken = await user?.getIdToken();
      (context) => RoleSelectionScreen();
      //context.goNamed(Routes().RoleConfig);

      // final response = await http.post(
      //   Uri.parse("$baseUrl/auth/firebase-login"),
      //   headers: {
      //     HttpHeaders.contentTypeHeader: 'application/json',
      //     HttpHeaders.authorizationHeader: 'Bearer $idToken',
      //   },
      //   body: jsonEncode({
      //     "email": user?.email,
      //     "phone": user?.phoneNumber ?? '',
      //     "category"
      //             "role":
      //         "Driver",
      //   }),
      // );
      // if (response.statusCode == 200 && context.mounted) {
      //   context.goNamed(Routes().driverConfig);
      // } else if (context.mounted) {
      //   ErrorNotification().showError(
      //     context,
      //     'Backend error: ${response.body}',
      //   );
      // }
    } catch (e) {
      if (context.mounted) {
        ErrorNotification().showError(context, "Google sign-in failed: $e");
      }
    }
  }

  // Future<void> signInWithApple(BuildContext context) async {
  //   try {
  //     final appleCredential = await SignInWithApple.getAppleIDCredential(
  //       scopes: [
  //         AppleIDAuthorizationScopes.email,
  //         AppleIDAuthorizationScopes.fullName,
  //       ],
  //     );

  //     final oauthCredential = OAuthProvider("apple.com").credential(
  //       idToken: appleCredential.identityToken,
  //       accessToken: appleCredential.authorizationCode,
  //     );

  //     final authResult = await _auth.signInWithCredential(oauthCredential);
  //     final user = authResult.user;
  //     final idToken = await user?.getIdToken();

  //     final response = await http.post(
  //       Uri.parse("$baseUrl/auth/firebase-login"),
  //       headers: {
  //         HttpHeaders.contentTypeHeader: 'application/json',
  //         HttpHeaders.authorizationHeader: 'Bearer $idToken',
  //       },
  //       body: jsonEncode({
  //         "email": user?.email,
  //         "phone": user?.phoneNumber ?? '',
  //         "role": "Driver",
  //       }),
  //     );

  //     if (response.statusCode == 200 && context.mounted) {
  //       context.goNamed(Routes().driverConfig);
  //     } else if (context.mounted) {
  //       ErrorNotification().showError(
  //         context,
  //         'Backend error: ${response.body}',
  //       );
  //     }
  //   } catch (e) {
  //     if (context.mounted) {
  //       ErrorNotification().showError(context, "Apple sign-in failed: $e");
  //     }
  //   }

  //Microsoft Sign-In
  // Future<void> signInWithMicrosoft(BuildContext context) async {
  //   try {
  //     PublicClientApplicationConfig(
  //       clientId: 'YOUR_MICROSOFT_CLIENT_ID',
  //       redirectUri: 'YOUR_REDIRECT_URI', // e.g., msalYOUR_CLIENT_ID://auth
  //       authority: 'https://login.microsoftonline.com/common',
  //     );

  //     final pca = PublicClientApplication(msalConfig);

  //     final result = await pca.acquireToken(scopes: ["User.Read"]);

  //     if (result.accessToken == null) {
  //       throw Exception('Microsoft sign-in failed: No access token.');
  //     }

  //     // You might want to create a custom Firebase Auth token or handle backend auth here.
  //     // For now, we just print and proceed with backend syncing

  //     final response = await http.post(
  //       Uri.parse("$baseUrl/auth/microsoft-login"),
  //       headers: {
  //         HttpHeaders.contentTypeHeader: 'application/json',
  //         HttpHeaders.authorizationHeader: 'Bearer ${result.accessToken}',
  //       },
  //       body: jsonEncode({"email": result.account.username, "role": "Driver"}),
  //     );

  //     if (response.statusCode == 200 && context.mounted) {
  //       context.goNamed(Routes().driverConfig);
  //     } else if (context.mounted) {
  //       ErrorNotification().showError(
  //         context,
  //         'Backend error: ${response.body}',
  //       );
  //     }
  //   } catch (e) {
  //     if (context.mounted) {
  //       ErrorNotification().showError(context, "Microsoft sign-in failed: $e");
  //     }
  //   }
  // }
}



// import 'dart:convert';
// import 'dart:io';

// import 'package:aminidriver/Container/utils/snackbar_utils.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:go_router/go_router.dart';
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:http/http.dart' as http;

// import '../../View/Routes/routes.dart';
// import '../utils/error_notification.dart';
// import '../utils/api_constant.dart';

// final globalAuthRepoProvider = Provider<AuthRepo>((ref) => AuthRepo());

// class AuthRepo {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   //late final PublicClientApplication msal;
  
//   get msalConfig => null;

//   /// Email/Password registration
//   Future<bool> registerWithEmailPhonePassword({
//     required String email,
//     required String phone,
//     required String password,
//     required BuildContext context,
//   }) async {
//     try {
//       UserCredential credential = await _auth.createUserWithEmailAndPassword(
//         email: email,
//         password: password,
//       );
//       final user = credential.user;
//       if (user != null) {
//         await user.sendEmailVerification();
//         return true;
//       } else {
//         showSnack(context, 'Firebase registration failed.');
//         return false;
//       }
//     } on FirebaseAuthException catch (e) {
//       if (e.code == 'email-already-in-use') {
//         showSnack(context, 'Email already registered. Please log in.');
//       } else {
//         showSnack(context, 'Firebase error: ${e.message}');
//       }
//       return false;
//     } catch (e) {
//       showSnack(context, 'An unexpected error occurred: $e');
//       return false;
//     }
//   }

//   /// Email/Password login with email verification check
//   Future<bool> loginWithEmailPassword({
//     required String email,
//     required String password,
//     required BuildContext context,
//   }) async {
//     try {
//       final userCredential = await _auth.signInWithEmailAndPassword(
//         email: email,
//         password: password,
//       );
//       final user = userCredential.user;
//       if (user == null) {
//         ErrorNotification().showError(context, "Login failed. Try again.");
//         return;
//       }
//       await user.reload();
//       if (!user.emailVerified) {
//         ErrorNotification().showError(
//           context,
//           "Please verify your email before logging in.",
//         );
//         return;
//       }
//       context.goNamed(Routes().driverConfig);
//     } on FirebaseAuthException catch (e) {
//       await _auth.signOut();
//       ErrorNotification().showError(context, e.message ?? 'Login failed');
//     } catch (e) {
//       await _auth.signOut();
//       ErrorNotification().showError(context, 'Unexpected error: $e');
//     }
//   }

//   /// Google Sign-In
//   Future<void> signInWithGoogle(BuildContext context) async {
//     try {
//       final googleUser = await GoogleSignIn().signIn();
//       if (googleUser == null) return;

//       final googleAuth = await googleUser.authentication;
//       final credential = GoogleAuthProvider.credential(
//         accessToken: googleAuth.accessToken,
//         idToken: googleAuth.idToken,
//       );

//       final authResult = await _auth.signInWithCredential(credential);
//       final user = authResult.user;
//       final idToken = await user?.getIdToken();

//       final response = await http.post(
//         Uri.parse("$baseUrl/auth/firebase-login"),
//         headers: {
//           HttpHeaders.contentTypeHeader: 'application/json',
//           HttpHeaders.authorizationHeader: 'Bearer $idToken',
//         },
//         body: jsonEncode({
//           "email": user?.email,
//           "phone": user?.phoneNumber ?? '',
//           "role": "Driver",
//         }),
//       );

//       if (response.statusCode == 200 && context.mounted) {
//         context.goNamed(Routes().driverConfig);
//       } else if (context.mounted) {
//         ErrorNotification().showError(
//           context,
//           'Backend error: ${response.body}',
//         );
//       }
//     } catch (e) {
//       if (context.mounted) {
//         ErrorNotification().showError(context, "Google sign-in failed: $e");
//       }
//     }
//   }

//   /// Apple Sign-In
//   Future<void> signInWithApple(BuildContext context) async {
//     try {
//       final appleCredential = await SignInWithApple.getAppleIDCredential(
//         scopes: [
//           AppleIDAuthorizationScopes.email,
//           AppleIDAuthorizationScopes.fullName,
//         ],
//       );

//       final oauthCredential = OAuthProvider("apple.com").credential(
//         idToken: appleCredential.identityToken,
//         accessToken: appleCredential.authorizationCode,
//       );

//       final authResult = await _auth.signInWithCredential(oauthCredential);
//       final user = authResult.user;
//       final idToken = await user?.getIdToken();

//       final response = await http.post(
//         Uri.parse("$baseUrl/auth/firebase-login"),
//         headers: {
//           HttpHeaders.contentTypeHeader: 'application/json',
//           HttpHeaders.authorizationHeader: 'Bearer $idToken',
//         },
//         body: jsonEncode({
//           "email": user?.email,
//           "phone": user?.phoneNumber ?? '',
//           "role": "Driver",
//         }),
//       );

//       if (response.statusCode == 200 && context.mounted) {
//         context.goNamed(Routes().driverConfig);
//       } else if (context.mounted) {
//         ErrorNotification().showError(
//           context,
//           'Backend error: ${response.body}',
//         );
//       }
//     } catch (e) {
//       if (context.mounted) {
//         ErrorNotification().showError(context, "Apple sign-in failed: $e");
//       }
//     }
//   }

//   /// Microsoft Sign-In
//   // Future<void> signInWithMicrosoft(BuildContext context) async {
//   //   try {
//   //     final msal = PublicClientApplicationConfig(
//   //       clientId: 'YOUR_MICROSOFT_CLIENT_ID',
//   //       redirectUri: 'YOUR_REDIRECT_URI', // e.g., msalYOUR_CLIENT_ID://auth
//   //       authority: 'https://login.microsoftonline.com/common',
//   //     );

//   //     final pca = PublicClientApplication(msalConfig);

//   //     final result = await pca.acquireToken(scopes: ["User.Read"]);

//   //     if (result.accessToken == null) {
//   //       throw Exception('Microsoft sign-in failed: No access token.');
//   //     }

//   //     // You might want to create a custom Firebase Auth token or handle backend auth here.
//   //     // For now, we just print and proceed with backend syncing

//   //     final response = await http.post(
//   //       Uri.parse("$baseUrl/auth/microsoft-login"),
//   //       headers: {
//   //         HttpHeaders.contentTypeHeader: 'application/json',
//   //         HttpHeaders.authorizationHeader: 'Bearer ${result.accessToken}',
//   //       },
//   //       body: jsonEncode({"email": result.account.username, "role": "Driver"}),
//   //     );

//   //     if (response.statusCode == 200 && context.mounted) {
//   //       context.goNamed(Routes().driverConfig);
//   //     } else if (context.mounted) {
//   //       ErrorNotification().showError(
//   //         context,
//   //         'Backend error: ${response.body}',
//   //       );
//   //     }
//   //   } catch (e) {
//   //     if (context.mounted) {
//   //       ErrorNotification().showError(context, "Microsoft sign-in failed: $e");
//   //     }
//   //   }
//   // }
// }




