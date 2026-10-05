import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import 'app_image.dart';

/// Board tile with a 3-image collage cover and a lock on private boards.
class BoardCard extends StatelessWidget {
  const BoardCard({super.key, required this.board, required this.onTap});

  final Board board;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    Widget cover(int i) => i < board.covers.length
        ? AppImage(board.covers[i], placeholder: p.surface2)
        : ColoredBox(color: p.surface2);

    return Semantics(
      button: true,
      label: board.name,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppPalette.radius),
              child: AspectRatio(
                aspectRatio: 3 / 2,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: p.surface,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 2, child: cover(0)),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: cover(1)),
                                const SizedBox(height: 2),
                                Expanded(child: cover(2)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (board.isPrivate)
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.lock_rounded, size: 15, color: Color(0xFF111111)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: Text(
                board.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
            Text(S.pinsCount('${board.pinsCount}'), style: TextStyle(color: p.muted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
