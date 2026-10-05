import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/format.dart';

/// `--dart-define=SEMANTICS=true` forces the accessibility tree on (used by
/// browser-driven end-to-end tests of the web build).
const _forceSemantics = bool.fromEnvironment('SEMANTICS');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  registerTimeagoLocale();
  if (_forceSemantics) SemanticsBinding.instance.ensureSemantics();
  runApp(
    ProviderScope(
      // Screens show their own retry buttons; don't retry failed providers silently.
      retry: (_, _) => null,
      child: const ModaHouseApp(),
    ),
  );
}
