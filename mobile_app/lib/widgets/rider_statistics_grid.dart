import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class RiderStatisticsGrid extends StatelessWidget {
  final Map<String, dynamic> stats;
  final VoidCallback? onEarningsTap;

  const RiderStatisticsGrid({
    super.key,
    required this.stats,
    this.onEarningsTap,
  });

  static const _activeBg = Color(0xFFFFF1E6);
  static const _activeBorder = Color(0xFFE49800);
  static const _activeAccent = Color(0xFFE49800);
  static const _activeIconBg = Color(0xFFFFE7B8);

  static const _incomingBg = Color(0xFFE8F1FF);
  static const _incomingBorder = Color(0xFF007FFF);
  static const _incomingAccent = Color(0xFF007FFF);
  static const _incomingIconBg = Color(0xFFCFE7FF);

  static const _completeBg = Color(0xFFE8F8EE);
  static const _completeBorder = Color(0xFF34C759);
  static const _completeAccent = Color(0xFF34C759);
  static const _completeIconBg = Color(0xFFD4F4DC);

  static const _earningsBg = Color(0xFFFFFFFF);
  static const _earningsBorder = Color(0xFFE6E6E6);
  static const _earningsLabel = Color(0xFF54C26F);
  static const _earningsIconBg = Color(0xFFD9F3DF);

  String _earningsAmount(dynamic value) {
    final n = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    return n.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Today’s Summary',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Active',
                iconAsset: 'assets/icons/motor.svg',
                background: _activeBg,
                border: _activeBorder,
                iconBackground: _activeIconBg,
                labelColor: _activeAccent,
                value: Text(
                  '${stats['active'] ?? 0}',
                  style: const TextStyle(
                    fontSize: 36,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: _activeAccent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                label: 'Incoming',
                iconAsset: 'assets/icons/incoming.svg',
                background: _incomingBg,
                border: _incomingBorder,
                iconBackground: _incomingIconBg,
                labelColor: _incomingAccent,
                value: Text(
                  '${stats['incoming'] ?? stats['pending'] ?? 0}',
                  style: const TextStyle(
                    fontSize: 36,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: _incomingAccent,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Complete',
                iconAsset: 'assets/icons/complete.svg',
                background: _completeBg,
                border: _completeBorder,
                iconBackground: _completeIconBg,
                labelColor: _completeAccent,
                value: Text(
                  '${stats['completed'] ?? 0}',
                  style: const TextStyle(
                    fontSize: 36,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: _completeAccent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                label: 'Earnings',
                iconAsset: 'assets/icons/earn.svg',
                background: _earningsBg,
                border: _earningsBorder,
                iconBackground: _earningsIconBg,
                labelColor: _earningsLabel,
                onTap: onEarningsTap,
                value: RichText(
                  textAlign: TextAlign.right,
                  text: TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Php ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF6B6B6B),
                        ),
                      ),
                      TextSpan(
                        text: _earningsAmount(stats['earnings']),
                        style: const TextStyle(
                          fontSize: 28,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String iconAsset;
  final Color background;
  final Color border;
  final Color iconBackground;
  final Color labelColor;
  final Widget value;
  final VoidCallback? onTap;

  const _SummaryCard({
    required this.label,
    required this.iconAsset,
    required this.background,
    required this.border,
    required this.iconBackground,
    required this.labelColor,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      key: ValueKey('summary-card-$label'),
      height: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: SvgPicture.asset(
                    iconAsset,
                    key: ValueKey(iconAsset),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
            ],
          ),
          Expanded(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: value,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}
