import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ConversationAvatar extends StatelessWidget {
  const ConversationAvatar({
    super.key,
    required this.avatarUrl,
    required this.isFarm,
    this.size = 52,
  });

  final String? avatarUrl;
  final bool isFarm;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = isFarm
        ? CircleAvatar(
            radius: size / 2,
            child: Icon(Icons.agriculture, size: size * 0.52),
          )
        : SvgPicture.asset(
            'assets/icons/Store.svg',
            width: size,
            height: size,
          );
    final url = avatarUrl;
    if (url == null || url.isEmpty) return fallback;
    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}
