import 'package:flutter/material.dart';

/// Only unresolved submissions live outside the regular merged order cards.
class FarmOrderRecoveryNotice extends StatelessWidget {
  const FarmOrderRecoveryNotice({super.key, required this.onContinue});
  final VoidCallback onContinue;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Material(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
            child: ListTile(
              title: const Text('Unresolved gamefowl order submission'),
              subtitle: const Text('Retry the original request safely'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onContinue,
            )),
      );
}
