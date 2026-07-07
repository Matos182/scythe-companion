// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import '../utils/strings.dart';

/// T3.5: confirm-before-leave dialogs.
///
/// Pages that own navigation from a live room (GamePage, WaitingLobby)
/// ask the user before tearing down their seat — auto-pause only fires
/// on the server side once the socket drops, but a deliberate "Leave"
/// from the AppBar is different from a back-gesture accident.
///
/// Returns true when the user confirms, false otherwise. Designed to be
/// called from `onPressed`, an `AppBar.leading`, or a `WillPopScope`.
Future<bool> confirmLeave(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(LeaveDialogStrings.cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(LeaveDialogStrings.confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
