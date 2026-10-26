import 'package:agriconnect/widgets/conversation_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('conversation avatar uses its URL for farm and shop tiles',
      (tester) async {
    for (final farm in [true, false]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ConversationAvatar(
            isFarm: farm,
            avatarUrl: 'https://example.test/avatar.png',
          ),
        ),
      ));
      final image = tester.widget<Image>(find.byType(Image));
      expect(
          (image.image as NetworkImage).url, 'https://example.test/avatar.png');
      expect(find.byType(ClipOval), findsOneWidget);
    }
  });

  testWidgets('missing avatar uses the existing farm or store icon',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ConversationAvatar(isFarm: true, avatarUrl: null),
      ),
    ));
    expect(find.byIcon(Icons.agriculture), findsOneWidget);
    expect(find.byType(Image), findsNothing);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ConversationAvatar(isFarm: false, avatarUrl: null),
      ),
    ));
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
