import 'package:flutter/material.dart';

import '../core/format.dart';
import '../models/models.dart';
import 'app_image.dart';

/// The user's photo, or a colored circle with the first letter of the name.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.size = 32, this.onTap});

  final UserBrief user;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final letterSource = user.name.isNotEmpty ? user.name : user.username;
    final letter = letterSource.isEmpty
        ? '?'
        : letterSource.characters.first.toUpperCase();
    final Widget circle = user.avatarUrl.isNotEmpty
        ? ClipOval(
            child: SizedBox.square(
              dimension: size,
              child: AppImage(user.avatarUrl),
            ),
          )
        : Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorFor(
                user.username.isNotEmpty ? user.username : user.name,
              ),
              shape: BoxShape.circle,
            ),
            child: Text(
              letter,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: size * 0.42,
                height: 1,
              ),
            ),
          );
    final avatar = Semantics(
      image: true,
      label: user.displayName,
      child: ExcludeSemantics(child: circle),
    );
    if (onTap == null) return avatar;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: avatar,
    );
  }
}
