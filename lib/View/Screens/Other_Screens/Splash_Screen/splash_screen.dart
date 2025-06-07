import 'package:flutter/material.dart';
import 'package:aminidriver/View/Screens/Other_Screens/Splash_Screen/splash_logics.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    SplashLogics().checkPermissions(context);
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.sizeOf(context);
    return Scaffold(
      body: SafeArea(
        child: Container(
          width: size.width,
          height: size.height,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 👇 Replace with your actual logo if needed
              Image.asset('assets/images/logo.png', width: 120, height: 120),
              const SizedBox(height: 20),
              Text(
                "Amini Driver",
                style: TextStyle(
                  fontSize: 48,
                  fontFamily: "bold",
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:aminidriver/View/Screens/Other_Screens/Splash_Screen/splash_logics.dart';

// class SplashScreen extends StatefulWidget {
//   const SplashScreen({super.key});

//   @override
//   State<SplashScreen> createState() => _SplashScreenState();
// }

// class _SplashScreenState extends State<SplashScreen> {
//   @override
//   void initState() {
//     super.initState();
//     SplashLogics().checkPermissions(context);
//   }

//   @override
//   Widget build(BuildContext context) {
//     Size size = MediaQuery.sizeOf(context);
//     return Scaffold(
//       body: SafeArea(
//         child: SizedBox(
//           width: size.width,
//           height: size.height,
//           child: Center(
//             child: Text(
//               "Amini Driver",
//               style: Theme.of(
//                 context,
//               ).textTheme.bodySmall!.copyWith(fontFamily: "bold", fontSize: 54),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
