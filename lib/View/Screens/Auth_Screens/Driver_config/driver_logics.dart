import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aminidriver/Container/utils/error_notification.dart';
import 'package:aminidriver/View/Routes/routes.dart';
import 'package:aminidriver/View/Screens/Auth_Screens/Driver_config/driver_providers.dart';

class DriverLogics {
  get globalFirestoreRepoProvider => null;

  void sendDataToFirestore(
    BuildContext context,
    ref,
    TextEditingController carNameController,
    TextEditingController plateNumController,
  ) async {
    try {
      // Input validation
      if (carNameController.text.isEmpty || plateNumController.text.isEmpty) {
        ErrorNotification().showError(
          context,
          "Please Enter Car Name and Plate Number",
        );
        return;
      }

      // Set loading state to true before making Firestore request
      ref.watch(driverConfigIsLoadingProvider.notifier).update((state) => true);

      // Safely get the driver category, fallback to "SUV" if null
      String driverCategory = ref.watch(driverConfigDropDownProvider) ?? "SUV";

      // Make the Firestore call
      await ref
          .watch(globalFirestoreRepoProvider)
          .addDriversDataToFirestore(
            context,
            carNameController.text.trim(),
            plateNumController.text.trim(),
            driverCategory, // Pass the driver category
          );

      // If the context is still mounted, navigate to the next screen
      if (context.mounted) {
        context.goNamed(Routes().navigationScreen);
      }
    } catch (e) {
      // Set loading state to false in case of error
      ref
          .watch(driverConfigIsLoadingProvider.notifier)
          .update((state) => false);

      // Show an error notification
      ErrorNotification().showError(context, "An Error Occurred: $e");
    } finally {
      // Ensure the loading state is reset if there was no error
      if (context.mounted) {
        ref
            .watch(driverConfigIsLoadingProvider.notifier)
            .update((state) => false);
      }
    }
  }
}
