import 'package:flutter/material.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final String message;
  final String? subtitle;
  final Widget? action;

  const EmptyStateWidget({
    super.key,
    this.icon,
    this.iconWidget,
    required this.message,
    this.subtitle,
    this.action,
  }) : assert(icon != null || iconWidget != null);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          iconWidget ??
              Icon(
                icon,
                size: 64,
                color: Colors.grey[400],
              ),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 8),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[
            SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}
