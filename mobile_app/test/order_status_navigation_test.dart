import 'package:agriconnect/constants/constants.dart';
import 'package:agriconnect/widgets/order/order_status_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

const _items = [
  OrderStatusNavigationItem(label: 'All', iconPath: 'assets/icons/orders.svg'),
  OrderStatusNavigationItem(
      label: 'Pending', iconPath: 'assets/icons/Pending.svg'),
  OrderStatusNavigationItem(
    label: 'Preparing',
    iconPath: 'assets/icons/Preparing.svg',
  ),
  OrderStatusNavigationItem(
      label: 'To Pickup', iconPath: 'assets/icons/box.svg'),
  OrderStatusNavigationItem(
    label: 'To Deliver',
    iconPath: 'assets/icons/Deliver.svg',
  ),
  OrderStatusNavigationItem(
    label: 'Delivered',
    iconPath: 'assets/icons/Delivered.svg',
  ),
  OrderStatusNavigationItem(
    label: 'Cancelled',
    iconPath: 'assets/icons/Cancelled.svg',
  ),
];

class _NavigationHarness extends StatefulWidget {
  const _NavigationHarness();

  @override
  State<_NavigationHarness> createState() => _NavigationHarnessState();
}

class _NavigationHarnessState extends State<_NavigationHarness>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _items.length, vsync: this)
      ..addListener(_onTabChanged);
  }

  void _onTabChanged() => setState(() {});

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(
            OrderStatusNavigation.heightFor(context, _items),
          ),
          child: OrderStatusNavigation(
            items: _items,
            selectedIndex: _tabs.index,
            onSelected: _tabs.animateTo,
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: List.generate(
          _items.length,
          (index) => Center(child: Text('view-$index')),
        ),
      ),
    );
  }
}

void main() {
  Future<void> pumpNavigation(
    WidgetTester tester, {
    double width = 390,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: const _NavigationHarness(),
    ));
    await tester.pumpAndSettle();
  }

  ScrollController scrollController(WidgetTester tester) => tester
      .widget<SingleChildScrollView>(
        find.byKey(const ValueKey('order-status-scroll')),
      )
      .controller!;

  TabController tabController(WidgetTester tester) =>
      tester.widget<TabBarView>(find.byType(TabBarView)).controller!;

  testWidgets('starts on All and tapping selects the corresponding view',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpNavigation(tester);

    expect(find.text('view-0'), findsOneWidget);
    expect(tester.widget<Text>(find.text('All')).style?.color,
        AppColors.brandPrimary);
    final all = tester.getSemantics(
      find.byKey(const ValueKey('order-status-item-0')),
    );
    expect(all.hasFlag(SemanticsFlag.isSelected), isTrue);
    expect(all.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    await tester.tap(find.text('Pending'));
    await tester.pumpAndSettle();
    expect(find.text('view-1'), findsOneWidget);
    expect(tester.widget<Text>(find.text('Pending')).style?.color,
        AppColors.brandPrimary);
    expect(tester.widget<Text>(find.text('All')).style?.color,
        const Color(0xFF6B7280));
    semantics.dispose();
  });

  testWidgets(
      'dragging freely changes the indicator without changing selection',
      (tester) async {
    await pumpNavigation(tester);
    final controller = scrollController(tester);
    final track = find.byKey(const ValueKey('order-status-indicator'));
    final thumb = find.byKey(const ValueKey('order-status-thumb'));
    final trackRect = tester.getRect(track);
    expect(tester.getRect(thumb).left, closeTo(trackRect.left, 0.01));
    expect(tester.getSize(track), const Size(64, 6));
    expect(tester.getSize(thumb), const Size(20, 3));

    await tester.drag(
      find.byKey(const ValueKey('order-status-scroll')),
      const Offset(-100, 0),
    );
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
    expect(tabController(tester).index, 0);
    expect(find.text('view-0'), findsOneWidget);

    controller.jumpTo(controller.position.maxScrollExtent / 2);
    await tester.pump();
    expect(tester.getRect(thumb).center.dx, closeTo(trackRect.center.dx, 0.01));
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    expect(tester.getRect(thumb).right, closeTo(trackRect.right, 0.01));
    expect(tabController(tester).index, 0);
  });

  testWidgets(
      'page swipes select and reveal hidden filters with minimal movement',
      (tester) async {
    await pumpNavigation(tester);
    final controller = scrollController(tester);
    final viewport = find.byKey(const ValueKey('order-status-scroll'));
    final item = find.byKey(const ValueKey('order-status-item-0'));
    final itemWidth = tester.getSize(item).width;
    final viewportWidth = tester.getSize(viewport).width;

    for (var index = 1; index < _items.length; index++) {
      await tester.drag(find.byType(TabBarView), const Offset(-350, 0));
      await tester.pumpAndSettle();
      expect(tabController(tester).index, index);
      expect(find.text('view-$index'), findsOneWidget);
      final selected = tester.getRect(
        find.byKey(ValueKey('order-status-item-$index')),
      );
      final visible = tester.getRect(viewport);
      expect(selected.left, greaterThanOrEqualTo(visible.left - 0.5));
      expect(selected.right, lessThanOrEqualTo(visible.right + 0.5));
      final expectedOffset = ((index + 1) * itemWidth - viewportWidth)
          .clamp(0.0, controller.position.maxScrollExtent);
      expect(controller.offset, closeTo(expectedOffset, 0.5));
    }

    tabController(tester).animateTo(0);
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(0, 0.5));
  });

  for (final width in [320.0, 390.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('fits ${width.toInt()}px with ${scale}x text',
          (tester) async {
        await pumpNavigation(tester, width: width, textScale: scale);
        final navigationRect =
            tester.getRect(find.byType(OrderStatusNavigation));
        for (var index = 0; index < _items.length; index++) {
          tabController(tester).animateTo(index);
          await tester.pumpAndSettle();
          final itemRect = tester.getRect(
            find.byKey(ValueKey('order-status-item-$index')),
          );
          final labelRect = tester.getRect(find.text(_items[index].label));
          expect(itemRect.width, greaterThanOrEqualTo(64));
          expect(itemRect.height, greaterThanOrEqualTo(48));
          expect(labelRect.width, lessThanOrEqualTo(itemRect.width));
          expect(labelRect.bottom, lessThan(navigationRect.bottom));
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets('hides the indicator when all items fit and handles resizing',
      (tester) async {
    final items = _items.take(3).toList();
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OrderStatusNavigation(
          items: items,
          selectedIndex: 2,
          onSelected: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(1000, 900);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('order-status-indicator')), findsNothing);
    expect(scrollController(tester).offset, 0);
    expect(tester.takeException(), isNull);
  });
}
