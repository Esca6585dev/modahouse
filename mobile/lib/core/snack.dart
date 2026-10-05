import 'package:flutter/material.dart';

import 'api_exception.dart';
import 'theme.dart';

/// Root messenger so SnackBars can be shown from anywhere (also after a pop).
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showSnack(String message, {bool error = false}) {
  final m = rootMessengerKey.currentState;
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(message, style: error ? const TextStyle(color: Colors.white, fontWeight: FontWeight.w600) : null),
    backgroundColor: error ? AppPalette.errorToast : null,
    duration: const Duration(milliseconds: 3500),
  ));
}

/// Shows the Turkmen message of an API error.
void showError(Object error) => showSnack(errorMessage(error), error: true);
