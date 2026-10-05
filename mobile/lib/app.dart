import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/snack.dart';
import 'core/theme.dart';
import 'l10n/material_tk.dart';
import 'l10n/strings.dart';
import 'router.dart';
import 'state/auth.dart';
import 'widgets/states.dart';

class ModaHouseApp extends ConsumerWidget {
  const ModaHouseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        children: [LogoMark(size: 64), SizedBox(height: 24), Spinner()],
      ),
    ),
  );
}
