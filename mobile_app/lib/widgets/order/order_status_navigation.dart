import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../constants/constants.dart';

@immutable
class OrderStatusNavigationItem {
  const OrderStatusNavigationItem({
    required this.label,
    required this.iconPath,
  });

  final String label;
  final String iconPath;
}

/// A scrollable filter bar. Scrolling the bar never selects an order filter.
class OrderStatusNavigation extends StatefulWidget {
  const OrderStatusNavigation({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  }) : assert(selectedIndex >= 0 && selectedIndex < items.length);

  final List<OrderStatusNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _labelStyle = TextStyle(
    fontSize: 12,
    height: 1.25,
    fontWeight: FontWeight.w600,
  );

  static TextStyle _labelStyleFor(BuildContext context) =>
      (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
          .merge(_labelStyle);

  static Size _labelSize(
    BuildContext context,
    List<OrderStatusNavigationItem> items,
  ) {
    var width = 0.0;
    var height = 0.0;
    final painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    );
    for (final item in items) {
      painter.text = TextSpan(text: item.label, style: _labelStyleFor(context));
      painter.layout();
      width = math.max(width, painter.width);
      height = math.max(height, painter.height);
    }
    painter.dispose();
    return Size(width.ceilToDouble(), height.ceilToDouble());
  }

  /// Includes the outer padding so the AppBar can reserve the correct space.
  static double heightFor(
    BuildContext context,
    List<OrderStatusNavigationItem> items,
  ) {
    return 8 +
        28 +
        math.max(48, 24 + 8 + _labelSize(context, items).height) +
        10 +
        4 +
        11 +
        12;
  }

  @override
  State<OrderStatusNavigation> createState() => _OrderStatusNavigationState();
}

class _OrderStatusNavigationState extends State<OrderStatusNavigation> {
  static const _inactive = Color(0xFF6B7280);
  final _scrollController = ScrollController();
  double _itemWidth = 0;
  double _viewportWidth = 0;
  bool _hasOverflow = false;
  bool _layoutUpdateScheduled = false;
  bool _revealAfterLayout = false;

  @override
  void didUpdateWidget(covariant OrderStatusNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _scheduleLayoutUpdate(revealSelected: true);
    }
  }

  void _scheduleLayoutUpdate({bool revealSelected = false}) {
    _revealAfterLayout |= revealSelected;
    if (_layoutUpdateScheduled) return;
    _layoutUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _layoutUpdateScheduled = false;
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (!position.hasContentDimensions) return;
      final hasOverflow = position.maxScrollExtent > 0;
      if (hasOverflow != _hasOverflow) {
        setState(() => _hasOverflow = hasOverflow);
      }
      if (_revealAfterLayout) {
        _revealAfterLayout = false;
        _revealSelected();
      }
    });
  }

  void _revealSelected() {
    final position = _scrollController.position;
    final itemStart = widget.selectedIndex * _itemWidth;
    final itemEnd = itemStart + _itemWidth;
    var target = position.pixels;
    if (itemStart < target) {
      target = itemStart;
    } else if (itemEnd > target + _viewportWidth) {
      target = itemEnd - _viewportWidth;
    }
    target = target.clamp(0.0, position.maxScrollExtent).toDouble();
    if ((target - position.pixels).abs() > 0.5) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labelSize = OrderStatusNavigation._labelSize(context, widget.items);
    final itemHeight = math.max(48.0, 24 + 8 + labelSize.height);
    return Container(
      color: AppColors.surfaceLight,
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 28, 0, 11),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = math.max(
                      constraints.maxWidth / 5,
                      math.max(64.0, labelSize.width + 8),
                    );
                    if (_viewportWidth != constraints.maxWidth ||
                        _itemWidth != itemWidth) {
                      _viewportWidth = constraints.maxWidth;
                      _itemWidth = itemWidth;
                      _scheduleLayoutUpdate(revealSelected: true);
                    }
                    return NotificationListener<ScrollMetricsNotification>(
                      onNotification: (_) {
                        _scheduleLayoutUpdate();
                        return false;
                      },
                      child: SingleChildScrollView(
                        key: const ValueKey('order-status-scroll'),
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(widget.items.length, (index) {
                            final item = widget.items[index];
                            final selected = index == widget.selectedIndex;
                            final color =
                                selected ? AppColors.brandPrimary : _inactive;
                            return Semantics(
                              key: ValueKey('order-status-item-$index'),
                              label: item.label,
                              button: true,
                              selected: selected,
                              onTap: () => widget.onSelected(index),
                              child: SizedBox(
                                width: itemWidth,
                                height: itemHeight,
                                child: InkWell(
                                  onTap: () => widget.onSelected(index),
                                  borderRadius: BorderRadius.circular(12),
                                  excludeFromSemantics: true,
                                  child: ExcludeSemantics(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SvgPicture.asset(
                                          item.iconPath,
                                          width: 24,
                                          height: 24,
                                          fit: BoxFit.contain,
                                          colorFilter: ColorFilter.mode(
                                            color,
                                            BlendMode.srcIn,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          item.label,
                                          maxLines: 1,
                                          textAlign: TextAlign.center,
                                          style: OrderStatusNavigation
                                                  ._labelStyleFor(context)
                                              .copyWith(
                                            color: color,
                                            fontWeight: selected
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 4,
                child: _hasOverflow
                    ? AnimatedBuilder(
                        animation: _scrollController,
                        builder: (context, _) {
                          final position = _scrollController.position;
                          final progress = position.maxScrollExtent > 0
                              ? (position.pixels / position.maxScrollExtent)
                                  .clamp(0.0, 1.0)
                              : 0.0;
                          return Container(
                            key: const ValueKey('order-status-indicator'),
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD9D9D9),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Align(
                              alignment: AlignmentDirectional(
                                -1 + 2 * progress,
                                0,
                              ),
                              child: Container(
                                key: const ValueKey('order-status-thumb'),
                                width: 14,
                                height: 2,
                                decoration: BoxDecoration(
                                  color: _inactive,
                                  borderRadius: BorderRadius.circular(1.5),
                                ),
                              ),
                            ),
                          );
                        },
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
