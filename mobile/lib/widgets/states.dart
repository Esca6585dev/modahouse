import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api_exception.dart';
import '../core/theme.dart';
import '../l10n/strings.dart';

class Spinner extends StatelessWidget {
  const Spinner({super.key, this.size = 22, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CircularProgressIndicator(
          strokeWidth: size < 20 ? 2 : 3,
          color: color ?? AppPalette.accent,
          backgroundColor: color == null ? AppPalette.of(context).surface2 : null,
        ),
      );
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(padding: EdgeInsets.all(32), child: Spinner(size: 28)),
      );
}

/// Centered icon + title + text + optional action. Used for empty states.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    this.text,
    this.icon,
    this.action,
    this.compact = false,
  });

  final String title;
  final String? text;
  final IconData? icon;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: compact ? 24 : 64),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: p.surface, shape: BoxShape.circle),
                child: Icon(icon, size: 30, color: p.muted),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            if (text != null) ...[
              const SizedBox(height: 8),
              Text(text!, textAlign: TextAlign.center, style: TextStyle(color: p.muted, height: 1.4)),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Error message with a retry button.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry, this.compact = false});

  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) => EmptyView(
        icon: Icons.cloud_off_rounded,
        title: errorMessage(error),
        compact: compact,
        action: onRetry == null
            ? null
            : FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text(S.retry),
              ),
      );
}

/// Shown on tabs that need an account (create, notifications, profile).
class LoginPrompt extends StatelessWidget {
  const LoginPrompt({super.key, required this.text, required this.from, this.icon});

  final String text;
  final String from;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => EmptyView(
        icon: icon ?? Icons.lock_outline_rounded,
        title: S.loginPromptTitle,
        text: text,
        action: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: () => context.push('/login?from=${Uri.encodeComponent(from)}'),
              child: const Text(S.loginAction),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.push('/register?from=${Uri.encodeComponent(from)}'),
              child: const Text(S.createAccount),
            ),
          ],
        ),
      );
}

/// Shimmering placeholder block.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height, this.width, this.radius = AppPalette.radius});

  final double? height;
  final double? width;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) _c.stop();
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value * 3 - 1; // -1 .. 2
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(t - 1, 0),
              end: Alignment(t + 1, 0),
              colors: [p.surface, p.surface2, p.surface],
            ),
          ),
        );
      },
    );
  }
}

/// Accent logo mark ("M" in a circle).
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: AppPalette.accent, shape: BoxShape.circle),
        child: Text(
          'M',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.52,
            height: 1,
          ),
        ),
      );
}

/// Yes/no dialog. Returns true when confirmed.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  String? text,
  String confirm = S.delete,
  bool danger = true,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: text == null ? null : Text(text),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          style: TextButton.styleFrom(foregroundColor: AppPalette.of(ctx).text),
          child: const Text(S.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: danger ? FilledButton.styleFrom(backgroundColor: AppPalette.danger) : null,
          child: Text(confirm),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Round button used over images (back, menu).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.size = 40,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final double size;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.white.withValues(alpha: 0.92),
          shape: const CircleBorder(),
          elevation: 1,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox.square(
              dimension: size,
              child: Icon(icon, color: const Color(0xFF111111), size: size * 0.55),
            ),
          ),
        ),
      );
}
