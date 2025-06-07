import 'package:aminidriver/Container/Repositories/auth_repo.dart';
import 'package:aminidriver/View/Routes/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
//import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({
    super.key,
    required void Function(dynamic driverData) onSubmit,
  });

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  //final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLoading = false;

  Future<void> register(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      setState(() => isLoading = true);

      final success = await ref
          .read(globalAuthRepoProvider)
          .registerWithEmailPhonePassword(
            email: emailController.text.trim(),
            phone: phoneController.text.trim(),
            password: passwordController.text.trim(),
            context: context,
          );

      setState(() => isLoading = false);

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Registration successful. Please verify your email."),
          ),
        );
        context.goNamed(Routes().login);
      }
    }
  }

  Future<void> signInWithGoogle() async {
    await ref.read(globalAuthRepoProvider).signInWithGoogle(context);
  }

  // Future<void> signInWithMicrosoft() async {
  //   await ref.read(globalAuthRepoProvider).signInWithMicrosoft(context);
  // }

  // Future<void> signInWithApple() async {
  //   await ref.read(globalAuthRepoProvider).signInWithApple(context);
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: const Text("Register"),
        centerTitle: true,
      ),
      backgroundColor: Colors.blue[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Icon(Icons.person_add_alt_1, size: 100, color: Colors.blue),
              const SizedBox(height: 10),
              const Text(
                "Create Account",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),

              /// === Registration Form ===
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // TextFormField(
                    //   controller: fullNameController,
                    //   decoration: const InputDecoration(
                    //     labelText: 'Full Name',
                    //     prefixIcon: Icon(Icons.person, color: Colors.blue),
                    //   ),
                    //   validator:
                    //       (val) =>
                    //           val == null || val.isEmpty
                    //               ? "Enter full name"
                    //               : null,
                    // ),
                    // const SizedBox(height: 12),
                    // TextFormField(
                    //   controller: emailController,
                    //   decoration: const InputDecoration(
                    //     labelText: 'Email',
                    //     foregroundColor: Colors.black,
                    //     prefixIcon: Icon(Icons.email, color: Colors.blue),

                    //   ),
                    //   validator:
                    //       (val) =>
                    //           val == null || !val.contains('@')
                    //               ? "Enter valid email"
                    //               : null,
                    // ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(
                          color: Colors.black,
                        ), // Correct way to set label text color
                        prefixIcon: Icon(Icons.email, color: Colors.blue),
                      ),
                      style: TextStyle(color: Colors.black), // Input text color
                      validator:
                          (val) =>
                              val == null || !val.contains('@')
                                  ? "Enter valid email"
                                  : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        labelStyle: TextStyle(color: Colors.black),
                        prefixIcon: Icon(Icons.phone, color: Colors.blue),
                      ),
                      style: TextStyle(color: Colors.black),
                      validator:
                          (val) =>
                              val == null || val.length < 10
                                  ? "Enter valid phone"
                                  : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        labelStyle: TextStyle(color: Colors.black),
                        prefixIcon: Icon(Icons.lock, color: Colors.blue),
                      ),
                      style: TextStyle(color: Colors.black),
                      validator:
                          (val) =>
                              val == null || val.length < 6
                                  ? "Password must be 6+ chars"
                                  : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm Password',
                        labelStyle: TextStyle(color: Colors.black),
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: Colors.blue,
                        ),
                      ),
                      style: TextStyle(color: Colors.black),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return "Confirm your password";
                        }
                        if (val != passwordController.text) {
                          return "Passwords do not match";
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              /// === Email Register Button ===
              ElevatedButton.icon(
                onPressed: isLoading ? null : () => register(context),
                icon: const Icon(Icons.app_registration, color: Colors.white),
                label:
                    isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                          "Register",
                          style: TextStyle(color: Colors.white),
                        ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),

              const SizedBox(height: 20),
              const Divider(),
              const Text("OR", style: TextStyle(color: Colors.black)),
              const SizedBox(height: 16),

              /// === Social Login Buttons ===
              ///
              const SizedBox(height: 20),
              SignInButton(
                Buttons.Google,
                text: "Continue with Google",
                onPressed: signInWithGoogle,
              ),
              //const SizedBox(height: 16),

              // SignInButton(
              //   Buttons.Microsoft,
              //   text: "Continue with Microsoft",
              //   onPressed: signInWithMicrosoft,
              // ),
              //const SizedBox(height: 16),

              // if (SignInWithApple.isAvailable())
              //   SignInButton(
              //     Buttons.Apple,
              //     text: "Continue with Apple",
              //     onPressed: signInWithApple,
              //   ),
              // SignInButton(
              //   Buttons.Apple,
              //   text: "Continue with Apple",
              //   onPressed: signInWithApple,
              // ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => context.goNamed(Routes().login),
                child: const Text(
                  "Back to Login",
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



// import 'package:aminidriver/Container/Repositories/auth_repo.dart';
// import 'package:aminidriver/View/Routes/routes.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:go_router/go_router.dart';

// class RegisterScreen extends ConsumerStatefulWidget {
//   const RegisterScreen({
//     super.key,
//     required void Function(dynamic driverData) onSubmit,
//   });

//   @override
//   ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
// }

// class _RegisterScreenState extends ConsumerState<RegisterScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final fullNameController = TextEditingController();
//   final emailController = TextEditingController();
//   final phoneController = TextEditingController();
//   final passwordController = TextEditingController();

//   bool isLoading = false;

//   Future<void> register(BuildContext context) async {
//     if (_formKey.currentState!.validate()) {
//       setState(() => isLoading = true);

//       final success = await ref
//           .read(globalAuthRepoProvider)
//           .registerWithEmailPhonePassword(
//             //fullName: fullNameController.text.trim(),
//             email: emailController.text.trim(),
//             phone: phoneController.text.trim(),
//             password: passwordController.text.trim(),
//             context: context,
//           );

//       setState(() => isLoading = false);
//       if (success && context.mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text("Registration successful. Please verify your email."),
//           ),
//         );
//         context.goNamed(Routes().login);
//       }
//     }
//   }

//   Future<void> signInWithGoogle() async {
//     await ref.read(globalAuthRepoProvider).signInWithGoogle(context);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.blue,
//         foregroundColor: Colors.white,
//         title: const Text("Register"),
//         centerTitle: true,
//       ),
//       backgroundColor: Colors.blue[50],
//       body: SafeArea(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(24.0),
//           child: Column(
//             children: [
//               const Icon(Icons.person_add_alt_1, size: 100, color: Colors.blue),
//               const SizedBox(height: 10),
//               const Text(
//                 "Create Account",
//                 style: TextStyle(
//                   fontSize: 26,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.black,
//                 ),
//               ),
//               const SizedBox(height: 20),
//               Form(
//                 key: _formKey,
//                 child: Column(
//                   children: [
//                     TextFormField(
//                       controller: fullNameController,
//                       decoration: const InputDecoration(
//                         labelText: 'Full Name',
//                         labelStyle: TextStyle(color: Colors.black),
//                         prefixIcon: Icon(Icons.person, color: Colors.blue),
//                       ),
//                       validator:
//                           (val) =>
//                               val == null || val.isEmpty
//                                   ? "Enter full name"
//                                   : null,
//                     ),
//                     const SizedBox(height: 12),
//                     TextFormField(
//                       controller: emailController,
//                       decoration: const InputDecoration(
//                         labelText: 'Email',
//                         labelStyle: TextStyle(color: Colors.black),
//                         prefixIcon: Icon(Icons.email, color: Colors.blue),
//                       ),
//                       validator:
//                           (val) =>
//                               val == null || !val.contains('@')
//                                   ? "Enter valid email"
//                                   : null,
//                     ),
//                     const SizedBox(height: 12),
//                     TextFormField(
//                       controller: phoneController,
//                       decoration: const InputDecoration(
//                         labelText: 'Phone',
//                         labelStyle: TextStyle(color: Colors.black),
//                         prefixIcon: Icon(Icons.phone, color: Colors.blue),
//                       ),
//                       validator:
//                           (val) =>
//                               val == null || val.length < 10
//                                   ? "Enter valid phone"
//                                   : null,
//                     ),
//                     const SizedBox(height: 12),
//                     TextFormField(
//                       controller: passwordController,
//                       obscureText: true,
//                       decoration: const InputDecoration(
//                         labelText: 'Password',
//                         labelStyle: TextStyle(color: Colors.black),
//                         prefixIcon: Icon(Icons.lock, color: Colors.blue),
//                       ),
//                       validator:
//                           (val) =>
//                               val == null || val.length < 6
//                                   ? "Password must be 6+ chars"
//                                   : null,
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 20),
//               ElevatedButton.icon(
//                 onPressed: isLoading ? null : () => register(context),
//                 icon: const Icon(Icons.app_registration, color: Colors.white),
//                 label:
//                     isLoading
//                         ? const CircularProgressIndicator(color: Colors.white)
//                         : const Text(
//                           "Register",
//                           style: TextStyle(color: Colors.white),
//                         ),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.yellow, //[800],
//                   minimumSize: const Size(double.infinity, 50),
//                 ),
//               ),
//               const SizedBox(height: 10),
//               const Divider(),
//               const Text("OR", style: TextStyle(color: Colors.black)),
//               const SizedBox(height: 10),
//               OutlinedButton.icon(
//                 onPressed: signInWithGoogle,
//                 icon: const Icon(Icons.g_mobiledata, color: Colors.red),
//                 label: const Text("Continue with Google"),
//                 style: OutlinedButton.styleFrom(
//                   foregroundColor: Colors.blue,
//                   minimumSize: const Size(double.infinity, 50),
//                   side: const BorderSide(color: Colors.blue),
//                 ),
//               ),
//               const SizedBox(height: 20),
//               TextButton(
//                 onPressed: () => context.goNamed(Routes().login),
//                 child: const Text(
//                   "Back to Login",
//                   style: TextStyle(color: Colors.blue),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

