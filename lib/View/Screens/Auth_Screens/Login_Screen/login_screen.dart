import 'package:aminidriver/Container/Repositories/auth_repo.dart';
import 'package:aminidriver/View/Screens/Auth_Screens/Login_Screen/forgot_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;

  void login(BuildContext context) async {
    setState(() => isLoading = true);
    try {
      await ref
          .read(globalAuthRepoProvider)
          .loginWithEmailPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
            context: context,
          );
    } catch (e) {
      // handled in auth_repo
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue, // Bar in blue
        foregroundColor: Colors.white,
        title: const Text("Login", style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text(
                "Welcome Back!",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(color: Colors.black),
                        prefixIcon: Icon(Icons.email, color: Colors.blue),
                      ),
                      style: TextStyle(color: Colors.black),
                      validator:
                          (val) =>
                              val == null || !val.contains('@')
                                  ? "Enter valid email"
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
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isLoading ? null : () => login(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, //[700], // Button in yellow
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child:
                    isLoading
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text(
                          "Login",
                          style: TextStyle(color: Colors.black),
                        ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed:
                    () => ref
                        .read(globalAuthRepoProvider)
                        .signInWithGoogle(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.blue, //[700], // Google Button in yellow
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 48),
                  side: const BorderSide(color: Colors.blue, width: 1),
                ),
                icon: const Icon(Icons.login, color: Colors.blue),
                label: const Text(
                  "Login with Google",
                  style: TextStyle(color: Colors.black),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => context.go('/register'),
                child: const Text(
                  "Don't have an account? Register",
                  style: TextStyle(color: Colors.blue),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ForgotPasswordScreen(),
                    ),
                    //backgroundColor: Colors.yellow, //[700], // Button in yellow
                    //foregroundColor: Colors.black,
                    //minimumSize: const Size(double.infinity, 48),
                  );
                },
                child: const Text(
                  "Forgot Password?",
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
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:go_router/go_router.dart';

// class LoginScreen extends ConsumerStatefulWidget {
//   const LoginScreen({super.key});

//   @override
//   ConsumerState<LoginScreen> createState() => _LoginScreenState();
// }

// class _LoginScreenState extends ConsumerState<LoginScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final emailController = TextEditingController();
//   final passwordController = TextEditingController();

//   bool isLoading = false;
//   void login(BuildContext context) async {
//     setState(() => isLoading = true);
//     try {
//       // Call auth_repo to handle Firebase login & validation
//       await ref
//           .read(globalAuthRepoProvider)
//           .loginWithEmailPassword(
//             //fullame: emailController.text.trim(),
//             email: emailController.text.trim(),
//             password: passwordController.text.trim(),
//             context: context,
//           );
//     } catch (e) {
//       // Errors are already handled in auth_repo, so we can ignore here
//     }

//     setState(() => isLoading = false);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.yellow[800],
//         foregroundColor: Colors.blue,
//         title: const Text("Login"),
//         centerTitle: true,
//       ),
//       backgroundColor: Colors.blue[50],
//       body: SafeArea(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(24.0),
//           child: Column(
//             children: [
//               const SizedBox(height: 40),
//               const Text(
//                 "Welcome Back!",
//                 style: TextStyle(
//                   fontSize: 28,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.yellow,
//                 ),
//               ),
//               const SizedBox(height: 20),
//               Form(
//                 key: _formKey,
//                 child: Column(
//                   children: [
//                     TextFormField(
//                       controller: emailController,
//                       decoration: const InputDecoration(
//                         labelText: 'Email',
//                         prefixIcon: Icon(Icons.email, color: Colors.yellow),
//                       ),
//                       validator:
//                           (val) =>
//                               val == null || !val.contains('@')
//                                   ? "Enter valid email"
//                                   : null,
//                     ),
//                     const SizedBox(height: 12),
//                     TextFormField(
//                       controller: passwordController,
//                       obscureText: true,
//                       decoration: const InputDecoration(
//                         labelText: 'Password',
//                         prefixIcon: Icon(Icons.lock, color: Colors.yellow),
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
//               ElevatedButton(
//                 onPressed: isLoading ? null : () => login(context),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.yellow[800],
//                   foregroundColor: Colors.blue,
//                   minimumSize: const Size(double.infinity, 48),
//                 ),
//                 child:
//                     isLoading
//                         ? const CircularProgressIndicator(color: Colors.blue)
//                         : const Text("Login"),
//               ),
//               const SizedBox(height: 16),
//               ElevatedButton.icon(
//                 onPressed:
//                     () => ref
//                         .read(globalAuthRepoProvider)
//                         .signInWithGoogle(context),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.white,
//                   foregroundColor: Colors.black,
//                   minimumSize: const Size(double.infinity, 48),
//                   side: const BorderSide(color: Colors.yellow, width: 1),
//                 ),
//                 icon: const Icon(Icons.login, color: Colors.yellow),
//                 label: const Text("Login with Google"),
//               ),
//               const SizedBox(height: 20),
//               TextButton(
//                 onPressed: () => context.go('/register'),
//                 child: const Text(
//                   "Don't have an account? Register",
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

// import 'package:aminidriver/Container/Repositories/auth_repo.dart';
// import 'package:aminidriver/View/Screens/Auth_Screens/Register_Screen/register_screen.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:lottie/lottie.dart';

// class LoginScreen extends ConsumerStatefulWidget {
//   const LoginScreen({super.key});

//   @override
//   ConsumerState<LoginScreen> createState() => _LoginScreenState();
// }

// class _LoginScreenState extends ConsumerState<LoginScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final emailController = TextEditingController();
//   final passwordController = TextEditingController();

//   bool isLoading = false;

//   void login(BuildContext context) async {
//     if (_formKey.currentState!.validate()) {
//       setState(() => isLoading = true);

//       await ref
//           .read(globalAuthRepoProvider)
//           .loginWithEmailPassword(
//             email: emailController.text.trim(),
//             password: passwordController.text.trim(),
//             context: context,
//           );

//       setState(() => isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.blue,
//         foregroundColor: Colors.yellow,
//         title: const Text("Login"),
//         centerTitle: true,
//       ),
//       backgroundColor: Colors.yellow[50],
//       body: SafeArea(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(24.0),
//           child: Column(
//             children: [
//               Lottie.asset('assets/animations/login.json', height: 200),
//               const SizedBox(height: 20),
//               const Text(
//                 "Welcome Back!",
//                 style: TextStyle(
//                   fontSize: 28,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.blue,
//                 ),
//               ),
//               const SizedBox(height: 20),
//               Form(
//                 key: _formKey,
//                 child: Column(
//                   children: [
//                     TextFormField(
//                       controller: emailController,
//                       decoration: const InputDecoration(
//                         labelText: 'Email',
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
//                       controller: passwordController,
//                       obscureText: true,
//                       decoration: const InputDecoration(
//                         labelText: 'Password',
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
//               Align(
//                 alignment: Alignment.centerRight,
//                 child: TextButton(
//                   onPressed: () {
//                     // Add Forgot Password logic
//                   },
//                   child: const Text(
//                     "Forgot Password?",
//                     style: TextStyle(color: Colors.orange),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 20),
//               ElevatedButton(
//                 onPressed: isLoading ? null : () => login(context),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.blue,
//                   foregroundColor: Colors.yellow,
//                   minimumSize: const Size(double.infinity, 48),
//                 ),
//                 child:
//                     isLoading
//                         ? const CircularProgressIndicator(color: Colors.yellow)
//                         : const Text("Login"),
//               ),
//               const SizedBox(height: 12),
//               OutlinedButton.icon(
//                 icon: const Icon(Icons.login, color: Colors.blue),
//                 label: const Text(
//                   "Continue with Google",
//                   style: TextStyle(color: Colors.blue),
//                 ),
//                 style: OutlinedButton.styleFrom(
//                   side: const BorderSide(color: Colors.blue),
//                   minimumSize: const Size(double.infinity, 48),
//                 ),
//                 onPressed:
//                     () => ref
//                         .read(globalAuthRepoProvider)
//                         .signInWithGoogle(context),
//               ),
//               const SizedBox(height: 20),
//               TextButton(
//                 onPressed: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(builder: (_) => const RegisterScreen()),
//                   );
//                 },
//                 child: const Text(
//                   "Don't have an account? Register",
//                   style: TextStyle(color: Colors.deepOrange),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';
// import 'package:aminidriver/View/Components/all_components.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:aminidriver/View/Routes/routes.dart';
// import 'package:aminidriver/View/Screens/Auth_Screens/Login_Screen/login_logics.dart';
// import 'package:aminidriver/View/Screens/Auth_Screens/Login_Screen/login_providers.dart';

// class LoginScreen extends StatefulWidget {
//   const LoginScreen({super.key});

//   @override
//   State<LoginScreen> createState() => _LoginScreenState();
// }

// class _LoginScreenState extends State<LoginScreen> {
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController passwordController = TextEditingController();

//   @override
//   Widget build(BuildContext context) {
//     Size size = MediaQuery.sizeOf(context);
//     return Scaffold(
//       body: SafeArea(
//         child: InkWell(
//           onTap: () {
//             FocusScope.of(context).unfocus();
//           },
//           child: SizedBox(
//             width: size.width,
//             height: size.height,
//             child: Stack(
//               children: [
//                 Opacity(
//                   opacity: 0.2,
//                   child: Container(
//                     width: size.width,
//                     height: size.height,
//                     decoration: const BoxDecoration(
//                       image: DecorationImage(
//                         fit: BoxFit.cover,
//                         image: AssetImage("assets/imgs/main.jpg"),
//                       ),
//                     ),
//                   ),
//                 ),
//                 Column(
//                   mainAxisAlignment: MainAxisAlignment.start,
//                   crossAxisAlignment: CrossAxisAlignment.center,
//                   children: [
//                     Padding(
//                       padding: const EdgeInsets.only(top: 20.0),
//                       child: Text(
//                         "Login",
//                         style: Theme.of(context).textTheme.bodySmall!.copyWith(
//                           fontFamily: "bold",
//                           fontSize: 20,
//                         ),
//                       ),
//                     ),
//                     Expanded(
//                       child: Padding(
//                         padding: const EdgeInsets.only(
//                           top: 20.0,
//                           left: 20,
//                           right: 20,
//                         ),
//                         child: Form(
//                           child: Column(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             crossAxisAlignment: CrossAxisAlignment.center,
//                             children: [
//                               Components().returnTextField(
//                                 emailController,
//                                 context,
//                                 false,
//                                 "Enter Email",
//                               ),
//                               Padding(
//                                 padding: const EdgeInsets.only(top: 20.0),
//                                 child: Components().returnTextField(
//                                   passwordController,
//                                   context,
//                                   true,
//                                   "Enter Password",
//                                 ),
//                               ),
//                               Padding(
//                                 padding: const EdgeInsets.only(top: 20.0),
//                                 child: Consumer(
//                                   builder: (context, ref, child) {
//                                     return InkWell(
//                                       onTap:
//                                           ref.watch(loginIsLoadingProvider)
//                                               ? null
//                                               : () => LoginLogics().loginUser(
//                                                 context,
//                                                 ref,
//                                                 emailController,
//                                                 passwordController,
//                                               ),
//                                       child: Components().mainButton(
//                                         size,
//                                         ref.watch(loginIsLoadingProvider)
//                                             ? "Loading ..."
//                                             : "Login",
//                                         context,
//                                         ref.watch(loginIsLoadingProvider)
//                                             ? Colors.grey
//                                             : Colors.blue,
//                                       ),
//                                     );
//                                   },
//                                 ),
//                               ),
//                               TextButton(
//                                 onPressed: () {
//                                   context.goNamed(Routes().register);
//                                 },
//                                 child: Text(
//                                   "Don't have an account? Sign Up.",
//                                   style: Theme.of(
//                                     context,
//                                   ).textTheme.bodySmall!.copyWith(
//                                     fontFamily: "bold",
//                                     fontSize: 12,
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
