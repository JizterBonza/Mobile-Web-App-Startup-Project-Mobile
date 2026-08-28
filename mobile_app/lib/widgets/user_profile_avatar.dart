import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../utils/media_url.dart';

/// Circular user avatar that shows a stored profile image when available.
class UserProfileAvatar extends StatelessWidget {
  final double size;
  final String? imageUrl;
  final Uint8List? imageBytes;
  final Color backgroundColor;
  final Color iconColor;
  final double iconSize;
  final Border? border;

  const UserProfileAvatar({
    super.key,
    required this.size,
    this.imageUrl,
    this.imageBytes,
    required this.backgroundColor,
    required this.iconColor,
    required this.iconSize,
    this.border,
  });

  Widget _placeholder() {
    return Icon(
      Icons.person,
      size: iconSize,
      color: iconColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final resolved = resolveMediaUrl(imageUrl);
    final localImage = imageBytes;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: border,
      ),
      clipBehavior: Clip.antiAlias,
      child: localImage != null
          ? Image.memory(
              localImage,
              fit: BoxFit.cover,
              width: size,
              height: size,
              errorBuilder: (context, error, stackTrace) => _placeholder(),
            )
          : resolved == null
              ? _placeholder()
              : Image.network(
                  resolved,
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  errorBuilder: (context, error, stackTrace) => _placeholder(),
                ),
    );
  }
}
