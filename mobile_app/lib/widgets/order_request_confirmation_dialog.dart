import 'package:flutter/material.dart';

import '../constants/constants.dart';

class OrderRequestConfirmationDialog extends StatelessWidget {
  const OrderRequestConfirmationDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          barrierColor: Colors.black54,
          builder: (_) => const OrderRequestConfirmationDialog(),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = AppColors.brandPrimaryLight.withOpacity(0.4);
    return Dialog(
      backgroundColor: AppColors.surfaceMuted,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Stack(children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: iconColor),
                  ),
                  child: Icon(Icons.receipt_long, size: 32, color: iconColor),
                ),
                const SizedBox(height: 12),
                const Text('Ready to Order?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                const Text(
                  'Have you already inquired with the seller and confirmed the details of your chosen gamefowl?',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: _button(context, 'No', false)),
                  const SizedBox(width: 12),
                  Expanded(child: _button(context, 'Yes', true)),
                ]),
              ]),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                tooltip: 'Close',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                visualDensity: VisualDensity.standard,
                onPressed: () => Navigator.pop(context, false),
                icon: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: AppColors.borderDefault),
                  child: const Icon(Icons.close, size: 24, color: Colors.white),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _button(BuildContext context, String label, bool confirmed) =>
      ElevatedButton(
        onPressed: () => Navigator.pop(context, confirmed),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              confirmed ? AppColors.brandPrimary : AppColors.borderDefault,
          foregroundColor: confirmed ? Colors.white : AppColors.textSecondary,
          elevation: 0,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      );
}
