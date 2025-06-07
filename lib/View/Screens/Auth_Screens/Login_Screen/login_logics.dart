import 'package:aminidriver/Container/Repositories/auth_repo.dart';
import 'package:aminidriver/View/Routes/routes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aminidriver/Container/utils/error_notification.dart';
import 'package:aminidriver/View/Screens/Auth_Screens/Login_Screen/login_providers.dart';
import 'package:go_router/go_router.dart';

class LoginLogics {
  Future<void> loginUser(
    BuildContext context,
    WidgetRef ref,
    TextEditingController emailController,
    TextEditingController passwordController,
  ) async {
    try {
      if (emailController.text.isEmpty || passwordController.text.isEmpty) {
        ErrorNotification().showError(
          context,
          "Please enter both email and password.",
        );
        return;
      }
      ref.read(loginIsLoadingProvider.notifier).state = true;

      // final loginSuccess = await ref.read(globalAuthRepoProvider).loginWithEmailPassword(
      //       emailController.text.trim(),
      //       passwordController.text.trim(),
      //       context,
      //     );

      // if (!loginSuccess) {
      //   ref.read(loginIsLoadingProvider.notifier).state = false;
      //   return;
      // }

      await _handlePostLoginRedirect(context);
      ref.read(loginIsLoadingProvider.notifier).state = false;
    } catch (e) {
      ref.read(loginIsLoadingProvider.notifier).state = false;
      ErrorNotification().showError(context, "Login failed: $e");
    }
  }

  Future<void> loginWithGoogle(BuildContext context, WidgetRef ref) async {
    try {
      ref.read(loginIsLoadingProvider.notifier).state = true;
      await ref.read(globalAuthRepoProvider).signInWithGoogle(context);
      await _handlePostLoginRedirect(context);
    } catch (e) {
      ErrorNotification().showError(context, "Google login failed: $e");
    } finally {
      ref.read(loginIsLoadingProvider.notifier).state = false;
    }
  }

  // Future<void> loginWithMicrosoft(BuildContext context, WidgetRef ref) async {
  //   try {
  //     ref.read(loginIsLoadingProvider.notifier).state = true;
  //     await ref.read(globalAuthRepoProvider).signInWithMicrosoft(context);
  //     await _handlePostLoginRedirect(context);
  //   } catch (e) {
  //     ErrorNotification().showError(context, "Microsoft login failed: $e");
  //   } finally {
  //     ref.read(loginIsLoadingProvider.notifier).state = false;
  //   }
  // }

  Future<void> _handlePostLoginRedirect(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc =
        await FirebaseFirestore.instance
            .collection("Drivers")
            .doc(user.email)
            .get();

    if (!doc.exists || doc.data()?["Car Name"] == null) {
      if (context.mounted) context.goNamed(Routes().driverConfig);
    } else {
      if (context.mounted) context.goNamed(Routes().navigationScreen);
    }
  }
}
