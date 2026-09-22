import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/constants.dart';

/// Notification bell and count badge shared by customer and rider surfaces.
class NotificationBellIcon extends StatelessWidget {
  const NotificationBellIcon({
    super.key,
    required this.color,
    this.badgeCount,
  });

  final Color color;
  final String? badgeCount;

  @override
  Widget build(BuildContext context) {
    final bell = SizedBox(
      key: const ValueKey('notification-bell'),
      width: 24,
      height: 24,
      child: SvgPicture.asset(
        'assets/icons/notif.svg',
        height: 24,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );

    if (badgeCount == null) return bell;

    return SizedBox(
      key: const ValueKey('notification-bell-with-badge'),
      width: 32,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(child: bell),
          Positioned(
            right: 0,
            top: -2,
            child: Container(
              key: const ValueKey('notification-count-badge'),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accentAmber,
                borderRadius: BorderRadius.circular(4),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                badgeCount!,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
