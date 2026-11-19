import 'package:agriconnect/widgets/search_suggestions.dart';
import 'package:agriconnect/models/catalog_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _dropdown = ValueKey('search-suggestions-dropdown');

Future<void> _showSuggestions(WidgetTester tester,
    {int minimumLength = 1,
    bool loading = false,
    String? error,
    int count = 8,
    num price = 100,
    bool grouped = false,
    List<SearchSuggestion>? suggestions,
    ValueChanged<SearchSuggestion>? onSelected}) async {
  tester.view.physicalSize = const Size(320, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = TextEditingController();
  final focus = FocusNode();
  addTearDown(controller.dispose);
  addTearDown(focus.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
        child: Column(children: [
          SearchSuggestions(
            controller: controller,
            focusNode: focus,
            minimumLength: minimumLength,
            isLoading: loading,
            error: error,
            grouped: grouped,
            suggestions: suggestions ??
                List.generate(
                    count,
                    (index) => SearchSuggestion(
                          id: '$index',
                          title: 'Match $index',
                          data: {'id': index},
                          price: price,
                        )),
            onSelected: onSelected ?? (_) {},
            child: TextField(
              controller: controller,
              focusNode: focus,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => focus.unfocus(),
            ),
          ),
          const Expanded(child: Center(child: Text('Outside'))),
        ]),
      ),
    ),
  ));
}

void main() {
  testWidgets(
      'grouped dropdown allows six matches per type with independent IDs',
      (tester) async {
    await _showSuggestions(tester, grouped: true, suggestions: [
      for (final type in SearchResultType.values)
        for (var index = 0; index < 8; index++)
          SearchSuggestion(
              id: '$index',
              title: '${type.name} Match $index',
              type: type,
              data: {'id': index}),
    ]);
    await tester.enterText(find.byType(TextField), 'match');
    await tester.pumpAndSettle();
    final list = find.descendant(
        of: find.byKey(_dropdown), matching: find.byType(ListView));
    expect(
        tester.widget<ListView>(list).childrenDelegate.estimatedChildCount, 21);
    for (final type in SearchResultType.values) {
      final last = find.byKey(ValueKey('search-suggestion-${type.name}-5'));
      await tester.scrollUntilVisible(last, 150,
          scrollable: find
              .descendant(
                  of: find.byKey(_dropdown), matching: find.byType(Scrollable))
              .first);
      expect(last, findsOneWidget);
      expect(find.byKey(ValueKey('search-suggestion-${type.name}-6')),
          findsNothing);
    }
    await tester.enterText(find.byType(TextField), 'new match');
    await tester.pumpAndSettle();
    expect(tester.widget<ListView>(list).controller!.offset, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('suggestion prices group thousands and omit only zero cents',
      (tester) async {
    for (final price in [100, 1000, 1000.1]) {
      await tester.pumpWidget(const SizedBox());
      await _showSuggestions(tester, count: 1, price: price);
      await tester.enterText(find.byType(TextField), 'match');
      await tester.pumpAndSettle();
      final label = price == 100
          ? '₱100'
          : price == 1000
              ? '₱1,000'
              : '₱1,000.10';
      expect(
          find.descendant(
              of: find.byKey(_dropdown), matching: find.text(label)),
          findsOneWidget);
      expect(find.text('₱100.00'), findsNothing);
    }
  });

  testWidgets('focus, minimum length, six matches and touch selection',
      (tester) async {
    SearchSuggestion? selected;
    await _showSuggestions(tester,
        minimumLength: 2, onSelected: (value) => selected = value);
    expect(find.byKey(_dropdown), findsNothing);
    await tester.enterText(find.byType(TextField), 'a');
    await tester.pumpAndSettle();
    expect(find.byKey(_dropdown), findsNothing);
    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pumpAndSettle();
    expect(find.byKey(_dropdown), findsOneWidget);
    final list = tester.widget<ListView>(find.descendant(
        of: find.byKey(_dropdown), matching: find.byType(ListView)));
    expect(list.childrenDelegate.estimatedChildCount, 6);
    expect(find.text('Match 6'), findsNothing);
    final field = tester.getRect(find.byType(TextField));
    final dropdown = tester.getRect(find.byKey(_dropdown));
    expect(dropdown.left, field.left);
    expect(dropdown.width, field.width);
    expect(dropdown.top, field.bottom + 6);
    expect(dropdown.height, lessThanOrEqualTo(280));
    await tester.tap(find.byKey(const ValueKey('search-suggestion-product-0')));
    await tester.pumpAndSettle();
    expect(selected?.id, '0');
    expect(find.byKey(_dropdown), findsNothing);
  });

  testWidgets('outside tap, refocus, submit and clear dismiss the dropdown',
      (tester) async {
    await _showSuggestions(tester);
    await tester.enterText(find.byType(TextField), 'match');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Outside'));
    await tester.pumpAndSettle();
    expect(find.byKey(_dropdown), findsNothing);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(find.byKey(_dropdown), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.byKey(_dropdown), findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.byKey(_dropdown), findsNothing);
  });

  testWidgets('loading, online error, empty matches and keyboard bounds',
      (tester) async {
    await _showSuggestions(tester, loading: true, count: 0);
    await tester.enterText(find.byType(TextField), 'match');
    await tester.pump();
    await tester.pump();
    expect(find.text('Searching…'), findsOneWidget);
    expect(find.text('No matching products'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await _showSuggestions(tester, error: 'Online search failed', count: 1);
    await tester.enterText(find.byType(TextField), 'match');
    await tester.pumpAndSettle();
    expect(find.text('Online search failed'), findsOneWidget);
    expect(find.text('Match 0'), findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 450);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(
        tester.getRect(find.byKey(_dropdown)).bottom, lessThanOrEqualTo(250));
    await tester.pumpWidget(const SizedBox());
    tester.view.resetViewInsets();
    await _showSuggestions(tester, count: 0);
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pumpAndSettle();
    expect(find.text('No matching products'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
