import 'dart:async';

import 'package:flutter/material.dart';

class DeliveryAcceptedDialog extends StatefulWidget {
  const DeliveryAcceptedDialog({
    super.key,
    this.autoDismissAfter = const Duration(seconds: 2),
  });

  final Duration autoDismissAfter;

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0xA6000000),
      builder: (_) => const DeliveryAcceptedDialog(),
    );
  }

  @override
  State<DeliveryAcceptedDialog> createState() => _DeliveryAcceptedDialogState();
}

class _DeliveryAcceptedDialogState extends State<DeliveryAcceptedDialog> {
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _dismissTimer = Timer(widget.autoDismissAfter, () {
      if (!mounted) return;
      final navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: 300,
        child: Material(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: const Padding(
            padding: EdgeInsets.fromLTRB(18, 20, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AcceptedCheckmark(),
                SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Delivery Accepted',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'You\u2019ve accepted this delivery. Please proceed to the pickup point.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF4A4A4A),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AcceptedCheckmark extends StatelessWidget {
  const _AcceptedCheckmark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFF27A867),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.check_rounded,
        color: Colors.white,
        size: 30,
      ),
    );
  }
}
