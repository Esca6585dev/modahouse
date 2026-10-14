import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/snack.dart';
import 'core/theme.dart';
import 'l10n/material_tk.dart';
import 'l10n/strings.dart';
import 'router.dart';
import 'state/auth.dart';
import 'state/server.dart';
import 'widgets/states.dart';

class ModaHouseApp extends ConsumerStatefulWidget {
  const ModaHouseApp({super.key});

  @override
  ConsumerState<ModaHouseApp> createState() => _ModaHouseAppState();
}

class _ModaHouseAppState extends ConsumerState<ModaHouseApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Ask the server whether the admin moved the API (in the background).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(serverProvider.notifier).refresh());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // At most every ServerNotifier.resumeInterval.
      unawaited(ref.read(serverProvider.notifier).refresh(force: false));
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final ready = ref.watch(authProvider.select((s) => s.ready));
    return MaterialApp.router(
      title: S.appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      scaffoldMessengerKey: rootMessengerKey,
      localizationsDelegates: const [TkMaterialLocalizations.delegate],
      routerConfig: router,
      builder: (context, child) =>
          ready ? child ?? const SizedBox.shrink() : const SplashView(),
    );
  }
}

/// Shown while the saved token is checked at startup.
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppPalette.of(context).bg,
    child: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [LogoWordmark(height: 110), SizedBox(height: 28), Spinner()],
      ),
    ),
  );
}
