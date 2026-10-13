import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../utils/media_url.dart';

/// Renders the article editor's HTML while keeping it in the article scroll view.
class KlasrumRichBody extends StatelessWidget {
  const KlasrumRichBody({super.key, required this.html});

  final String html;

  static const _bodyStyle = TextStyle(
    fontSize: 15,
    height: 1.55,
    color: Color(0xff616161),
  );

  @override
  Widget build(BuildContext context) {
    final nodes = html_parser.parseFragment(html).nodes;
    final blocks = <Widget>[];
    for (final node in nodes) {
      blocks.addAll(_buildBlocks(node));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  List<Widget> _buildBlocks(dom.Node node) {
    if (node is dom.Text) {
      final content = _normalize(node.text);
      if (content.trim().isEmpty) return const [];
      return [
        _textBlock(
            [TextSpan(text: content)], null, const EdgeInsets.only(bottom: 14))
      ];
    }
    if (node is! dom.Element) return const [];
    final tag = node.localName?.toLowerCase() ?? '';
    if (tag == 'script' || tag == 'style') return const [];
    if (tag == 'img') {
      final url = resolveMediaUrl(node.attributes['src']);
      if (url == null) return const [];
      return [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ];
    }
    if (tag == 'ul' || tag == 'ol') {
      final items = node.children.where((child) => child.localName == 'li');
      return [
        for (final (index, item) in items.indexed)
          _textBlock(
            [
              TextSpan(text: tag == 'ol' ? '${index + 1}.  ' : '•  '),
              ..._inlineSpans(item.nodes, _bodyStyle),
            ],
            _alignment(item),
            const EdgeInsets.only(left: 16, bottom: 8),
          ),
        const SizedBox(height: 6),
      ];
    }
    if ((tag == 'div' || tag == 'section' || tag == 'article') &&
        node.children.any((child) => _isBlock(child.localName))) {
      return [for (final child in node.nodes) ..._buildBlocks(child)];
    }

    final isHeading = RegExp(r'^h[1-6]$').hasMatch(tag);
    final style = isHeading
        ? _bodyStyle.copyWith(
            fontSize: 23, height: 1.25, fontWeight: FontWeight.bold)
        : _bodyStyle;
    final spans = _inlineSpans(node.nodes, _styleFor(node, style));
    if (spans.isEmpty) return const [];
    return [
      _textBlock(
        spans,
        _alignment(node),
        EdgeInsets.only(top: isHeading ? 12 : 0, bottom: isHeading ? 10 : 16),
      ),
    ];
  }

  bool _isBlock(String? tag) => const {
        'p',
        'div',
        'section',
        'article',
        'ul',
        'ol',
        'blockquote',
        'h1',
        'h2',
        'h3',
        'h4',
        'h5',
        'h6',
      }.contains(tag);

  Widget _textBlock(
    List<InlineSpan> spans,
    TextAlign? alignment,
    EdgeInsets padding,
  ) =>
      Padding(
        padding: padding,
        child: Text.rich(
          TextSpan(style: _bodyStyle, children: spans),
          textAlign: alignment ?? TextAlign.start,
        ),
      );

  List<InlineSpan> _inlineSpans(List<dom.Node> nodes, TextStyle style) {
    final spans = <InlineSpan>[];
    for (final node in nodes) {
      if (node is dom.Text) {
        final text = _normalize(node.text);
        if (text.isNotEmpty) spans.add(TextSpan(text: text, style: style));
      } else if (node is dom.Element) {
        final tag = node.localName?.toLowerCase();
        if (tag == 'br') {
          spans.add(const TextSpan(text: '\n'));
        } else if (tag != 'script' && tag != 'style') {
          spans.add(TextSpan(
            style: _styleFor(node, style),
            children: _inlineSpans(node.nodes, _styleFor(node, style)),
          ));
        }
      }
    }
    return spans;
  }

  String _normalize(String value) => value.replaceAll(RegExp(r'\s+'), ' ');

  TextAlign? _alignment(dom.Element element) {
    final style = _css(element);
    switch (style['text-align']?.toLowerCase()) {
      case 'justify':
        return TextAlign.justify;
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      default:
        return null;
    }
  }

  TextStyle _styleFor(dom.Element element, TextStyle inherited) {
    final tag = element.localName?.toLowerCase();
    var style = inherited;
    if (tag == 'b' || tag == 'strong') {
      style = style.copyWith(fontWeight: FontWeight.bold);
    } else if (tag == 'i' || tag == 'em') {
      style = style.copyWith(fontStyle: FontStyle.italic);
    } else if (tag == 'u' || tag == 'a') {
      style = style.copyWith(decoration: TextDecoration.underline);
    }
    final css = _css(element);
    final size = _fontSize(css['font-size'], style.fontSize ?? 15);
    if (size != null) style = style.copyWith(fontSize: size);
    final weight = css['font-weight']?.toLowerCase();
    if (weight == 'bold' || (int.tryParse(weight ?? '') ?? 0) >= 600) {
      style = style.copyWith(fontWeight: FontWeight.bold);
    }
    if (css['font-style']?.toLowerCase() == 'italic') {
      style = style.copyWith(fontStyle: FontStyle.italic);
    }
    final color = _color(css['color']);
    if (color != null) style = style.copyWith(color: color);
    return style;
  }

  Map<String, String> _css(dom.Element element) {
    final values = <String, String>{};
    for (final declaration in (element.attributes['style'] ?? '').split(';')) {
      final separator = declaration.indexOf(':');
      if (separator < 0) continue;
      values[declaration.substring(0, separator).trim().toLowerCase()] =
          declaration.substring(separator + 1).trim();
    }
    return values;
  }

  double? _fontSize(String? raw, double inherited) {
    if (raw == null) return null;
    final value = raw.trim().toLowerCase();
    if (value.endsWith('pt')) {
      final points = double.tryParse(value.substring(0, value.length - 2));
      return points == null ? null : points * 4 / 3;
    }
    if (value.endsWith('px')) {
      return double.tryParse(value.substring(0, value.length - 2));
    }
    if (value.endsWith('em')) {
      final scale = double.tryParse(value.substring(0, value.length - 2));
      return scale == null ? null : inherited * scale;
    }
    return null;
  }

  Color? _color(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
      return Color(int.parse('ff${value.substring(1)}', radix: 16));
    }
    return null;
  }
}
