import 'package:agriconnect/widgets/klasrum_rich_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TextStyle? _styleForText(InlineSpan span, String text) {
  if (span is! TextSpan) return null;
  if (span.text?.contains(text) == true) return span.style;
  for (final child in span.children ?? const <InlineSpan>[]) {
    final style = _styleForText(child, text);
    if (style != null) return style;
  }
  return null;
}

void main() {
  testWidgets('preserves editor headings, bold text, alignment, and entities',
      (tester) async {
    const body = '''
      <p class="MsoNormal" style="text-align:justify">
        <span>Isang kakaibang <b>Bulik</b> ang napansin nila.</span>
      </p>
      <b><span style="font-size:17.0pt;line-height:115%">
        From One Unusual Chick to the Airwolf Dom
      </span></b>
      <p>Next<br>line &amp; more.</p>
    ''';
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: KlasrumRichBody(html: body)),
      ),
    ));

    final articleBlocks = tester.widgetList<Text>(find.byType(Text)).toList();
    expect(articleBlocks, hasLength(3));
    expect(articleBlocks.first.textAlign, TextAlign.justify);
    expect(articleBlocks.first.textSpan!.toPlainText(), contains('Bulik'));
    expect(_styleForText(articleBlocks.first.textSpan!, 'Bulik')?.fontWeight,
        FontWeight.bold);

    final heading = articleBlocks[1].textSpan!;
    expect(heading.toPlainText(), contains('From One Unusual Chick'));
    expect(_styleForText(heading, 'From One Unusual Chick')?.fontSize,
        closeTo(22.67, 0.01));
    expect(_styleForText(heading, 'From One Unusual Chick')?.fontWeight,
        FontWeight.bold);
    expect(articleBlocks.last.textSpan!.toPlainText(),
        contains('Next\nline & more.'));
  });
}
