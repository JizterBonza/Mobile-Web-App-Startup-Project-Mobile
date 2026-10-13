import 'dart:async';

import 'package:agriconnect/models/klasrum_content.dart';
import 'package:agriconnect/widgets/klasrum_media_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class FakeVideoPlatform extends VideoPlayerPlatform {
  final events = <int, StreamController<VideoEvent>>{};
  final played = <int>[];
  final paused = <int>[];
  final disposed = <int>[];
  final volumes = <double>[];
  int _nextId = 1;

  @override
  Future<void> init() async {}

  @override
  Future<int> create(DataSource dataSource) async {
    final id = _nextId++;
    late StreamController<VideoEvent> controller;
    controller = StreamController<VideoEvent>.broadcast(onListen: () {
      scheduleMicrotask(() => controller.add(VideoEvent(
            eventType: VideoEventType.initialized,
            duration: const Duration(seconds: 2),
            size: const Size(160, 90),
          )));
    });
    events[id] = controller;
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events[playerId]!.stream;

  @override
  Future<void> dispose(int playerId) async {
    disposed.add(playerId);
    await events[playerId]?.close();
  }

  @override
  Future<void> play(int playerId) async => played.add(playerId);

  @override
  Future<void> pause(int playerId) async => paused.add(playerId);

  @override
  Future<void> setVolume(int playerId, double volume) async {
    volumes.add(volume);
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Widget buildView(int playerId) => const SizedBox();
}

void main() {
  final originalPlatform = VideoPlayerPlatform.instance;
  late FakeVideoPlatform videoPlatform;

  setUp(() {
    videoPlatform = FakeVideoPlatform();
    VideoPlayerPlatform.instance = videoPlatform;
  });
  tearDown(() => VideoPlayerPlatform.instance = originalPlatform);

  testWidgets('images advance after five seconds, wrap, and reset on swipe',
      (tester) async {
    const items = [
      KlasrumMediaItem(url: 'https://example.test/one.jpg', type: 'image'),
      KlasrumMediaItem(url: 'https://example.test/two.jpg', type: 'image'),
    ];
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: KlasrumMediaCarousel(items: items)),
    ));
    final pager = tester.widget<PageView>(find.byType(PageView));
    expect(pager.controller!.page, 0);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 300));
    expect(pager.controller!.page, 1);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(pager.controller!.page, 0);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(pager.controller!.page, 1);
    await tester.pump(const Duration(seconds: 3));
    expect(pager.controller!.page, 1);
  });

  testWidgets('visible video autoplays muted and advances on completion',
      (tester) async {
    const items = [
      KlasrumMediaItem(url: 'https://example.test/one.jpg', type: 'image'),
      KlasrumMediaItem(url: 'https://example.test/two.mp4', type: 'video'),
    ];
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: KlasrumMediaCarousel(items: items)),
    ));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(videoPlatform.events, contains(1));
    await tester.pump();
    await tester.pump();
    expect(videoPlatform.volumes, contains(0));
    expect(videoPlatform.played, contains(1));

    await tester.tap(find.byTooltip('Unmute'));
    await tester.pump();
    expect(videoPlatform.volumes.last, 1);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(videoPlatform.paused, contains(1));
    await tester.tap(find.byTooltip('Play'));
    await tester.pump();

    videoPlatform.events[1]!
        .add(VideoEvent(eventType: VideoEventType.completed));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 0);
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    expect(videoPlatform.disposed, contains(1));
  });

  testWidgets('backgrounding and closing stop the active video',
      (tester) async {
    const items = [
      KlasrumMediaItem(url: 'https://example.test/one.mp4', type: 'video'),
    ];
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: KlasrumMediaCarousel(items: items)),
    ));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(videoPlatform.paused, contains(1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    expect(videoPlatform.disposed, contains(1));
  });

  testWidgets('covering the article route pauses and returning resumes video',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    const items = [
      KlasrumMediaItem(url: 'https://example.test/one.mp4', type: 'video'),
    ];
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: KlasrumMediaCarousel(items: items)),
    ));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(videoPlatform.played, contains(1));

    navigatorKey.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('Other page')),
    ));
    await tester.pumpAndSettle();
    expect(videoPlatform.paused, contains(1));

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(videoPlatform.played.length, greaterThan(1));
  });
}
