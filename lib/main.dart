//import 'package:aminidriver/View/Screens/Auth_Screens/Register_Screen/vehicle_registration_screen';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'View/Routes/app_routes.dart';
//import 'View/Themes/app_theme.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'aminidriver',
      //themeMode: ThemeMode.system,
      //theme: appTheme,
      //runApp(const MaterialApp(home: VehicleOnboardingScreen()));
      //darkTheme: appDarkTheme,
      routerConfig: router,
    );

    // return MaterialApp.router(
    //   debugShowCheckedModeBanner: false,
    //   title: 'aminidriver',
    //   theme: appTheme,
    //   routerConfig: router,
    // );
  }
}

// // import 'package:flutter/material.dart';

// // void main() {
// //   runApp(const MyApp());
// // }

// // class MyApp extends StatelessWidget {
// //   const MyApp({super.key});

// //   // This widget is the root of your application.
// //   @override
// //   Widget build(BuildContext context) {
// //     return MaterialApp(
// //       title: 'Flutter Demo',
// //       theme: ThemeData(
// //         // This is the theme of your application.
// //         //
// //         // TRY THIS: Try running your application with "flutter run". You'll see
// //         // the application has a purple toolbar. Then, without quitting the app,
// //         // try changing the seedColor in the colorScheme below to Colors.green
// //         // and then invoke "hot reload" (save your changes or press the "hot
// //         // reload" button in a Flutter-supported IDE, or press "r" if you used
// //         // the command line to start the app).
// //         //
// //         // Notice that the counter didn't reset back to zero; the application
// //         // state is not lost during the reload. To reset the state, use hot
// //         // restart instead.
// //         //
// //         // This works for code too, not just values: Most code changes can be
// //         // tested with just a hot reload.
// //         colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
// //       ),
// //       home: const MyHomePage(title: 'Flutter Demo Home Page'),
// //     );
// //   }
// // }

// // class MyHomePage extends StatefulWidget {
// //   const MyHomePage({super.key, required this.title});

// //   // This widget is the home page of your application. It is stateful, meaning
// //   // that it has a State object (defined below) that contains fields that affect
// //   // how it looks.

// //   // This class is the configuration for the state. It holds the values (in this
// //   // case the title) provided by the parent (in this case the App widget) and
// //   // used by the build method of the State. Fields in a Widget subclass are
// //   // always marked "final".

// //   final String title;

// //   @override
// //   State<MyHomePage> createState() => _MyHomePageState();
// // }

// // class _MyHomePageState extends State<MyHomePage> {
// //   int _counter = 0;

// //   void _incrementCounter() {
// //     setState(() {
// //       // This call to setState tells the Flutter framework that something has
// //       // changed in this State, which causes it to rerun the build method below
// //       // so that the display can reflect the updated values. If we changed
// //       // _counter without calling setState(), then the build method would not be
// //       // called again, and so nothing would appear to happen.
// //       _counter++;
// //     });
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     // This method is rerun every time setState is called, for instance as done
// //     // by the _incrementCounter method above.
// //     //
// //     // The Flutter framework has been optimized to make rerunning build methods
// //     // fast, so that you can just rebuild anything that needs updating rather
// //     // than having to individually change instances of widgets.
// //     return Scaffold(
// //       appBar: AppBar(
// //         // TRY THIS: Try changing the color here to a specific color (to
// //         // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
// //         // change color while the other colors stay the same.
// //         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
// //         // Here we take the value from the MyHomePage object that was created by
// //         // the App.build method, and use it to set our appbar title.
// //         title: Text(widget.title),
// //       ),
// //       body: Center(
// //         // Center is a layout widget. It takes a single child and positions it
// //         // in the middle of the parent.
// //         child: Column(
// //           // Column is also a layout widget. It takes a list of children and
// //           // arranges them vertically. By default, it sizes itself to fit its
// //           // children horizontally, and tries to be as tall as its parent.
// //           //
// //           // Column has various properties to control how it sizes itself and
// //           // how it positions its children. Here we use mainAxisAlignment to
// //           // center the children vertically; the main axis here is the vertical
// //           // axis because Columns are vertical (the cross axis would be
// //           // horizontal).
// //           //
// //           // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
// //           // action in the IDE, or press "p" in the console), to see the
// //           // wireframe for each widget.
// //           mainAxisAlignment: MainAxisAlignment.center,
// //           children: <Widget>[
// //             const Text('You have pushed the button this many times:'),
// //             Text(
// //               '$_counter',
// //               style: Theme.of(context).textTheme.headlineMedium,
// //             ),
// //           ],
// //         ),
// //       ),
// //       floatingActionButton: FloatingActionButton(
// //         onPressed: _incrementCounter,
// //         tooltip: 'Increment',
// //         child: const Icon(Icons.add),
// //       ), // This trailing comma makes auto-formatting nicer for build methods.
// //     );
// //   }
// // }
// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
//   runApp(const MaterialApp(home: RegisterDriverScreen()));
// }

// class RegisterDriverScreen extends StatelessWidget {
//   const RegisterDriverScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Register Driver")),
//       body: Center(
//         child: ElevatedButton(
//           onPressed: () {
//             registerDriver(
//               name: "Kevin Otieno",
//               email: "ibrahimomar@darkaez.co.ke",
//               password: "ba4nyibA,", // ensure this is valid
//               phone: "+254712345678",
//               category: "Matatu",
//             );
//           },
//           child: const Text("Register Driver"),
//         ),
//       ),
//     );
//   }
// }

// Future<void> registerDriver({
//   required String name,
//   required String email,
//   required String password,
//   required String phone,
//   required String category,
// }) async {
//   UserCredential userCredential;

//   // 🔐 Step 1: Create user in Firebase Auth
//   try {
//     userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
//       email: email,
//       password: password,
//     );
//     debugPrint("✅ FirebaseAuth: User created");
//   } on FirebaseAuthException catch (e) {
//     if (e.code == 'email-already-in-use') {
//       debugPrint("⚠️ User already exists, trying to sign in...");
//       userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
//         email: email,
//         password: password,
//       );
//     } else {
//       debugPrint("❌ FirebaseAuth error: ${e.message}");
//       return;
//     }
//   } catch (e) {
//     debugPrint("❌ Unexpected FirebaseAuth error: $e");
//     return;
//   }

//   final token = await userCredential.user?.getIdToken();

//   // 📦 Step 2: Prepare driver data
//   final driverData = {
//     "name": name,
//     "email": email,
//     "phone": phone,
//     "category": category,
//     "createdAt": FieldValue.serverTimestamp(),
//   };

//   // 📝 Step 3: Post to Firestore
//   try {
//     await FirebaseFirestore.instance.collection("drivers").add(driverData);
//     debugPrint("✅ Firestore: Driver data added");
//   } catch (e) {
//     debugPrint("❌ Firestore error: $e");
//   }

//   // 🌐 Step 4: Post to backend API
//   try {
//     final response = await http.post(
//       Uri.parse("http://192.168.27.145:7047/api/auth/firebase-login"),
//       headers: {
//         'Content-Type': 'application/json',
//         'Authorization': 'Bearer $token',
//       },
//       body: jsonEncode({
//         "fullname": name,
//         "email": email,
//         "phone": phone,
//         "role": category,
//         "token": token,
//       }),
//     );

//     if (response.statusCode == 200 || response.statusCode == 201) {
//       debugPrint("✅ Backend: Driver posted");
//     } else {
//       debugPrint("❌ Backend failed: ${response.statusCode} - ${response.body}");
//     }
//   } catch (e) {
//     debugPrint("❌ Backend error: $e");
//   }
// }
