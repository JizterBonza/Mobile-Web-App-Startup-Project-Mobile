import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/klasrum_content.dart';

class KlasrumMediaCarousel extends StatefulWidget {
  const KlasrumMediaCarousel({super.key, required this.items});

  final List<KlasrumMediaItem> items;

  @override
  State<KlasrumMediaCarousel> createState() => _KlasrumMediaCarouselState();
}

class _KlasrumMediaCarouselState extends State<KlasrumMediaCarousel>
    with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  Timer? _advanceTimer;
  VideoPlayerController? _video;
  int _index = 0;
  int _videoGeneration = 0;
  bool _foreground = true;
  bool _routeVisible = true;
  bool _loadingVideo = false;
  bool _videoError = false;
  bool _completionHandled = false;
  bool _userPaused = false;
  bool _muted = true;

  bool get _canPlay => _foreground && _routeVisible;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.items.isNotEmpty) _activateSlide(0);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasPlayable = _canPlay;
    _foreground = state == AppLifecycleState.resumed;
    _updatePlayback(wasPlayable);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wasPlayable = _canPlay;
    _routeVisible = ModalRoute.isCurrentOf(context) ?? true;
    if (wasPlayable != _canPlay) {
      scheduleMicrotask(() {
        if (mounted) _updatePlayback(wasPlayable);
      });
    }
  }

  void _updatePlayback(bool wasPlayable) {
    if (_canPlay == wasPlayable) return;
    if (!_canPlay) {
      _advanceTimer?.cancel();
      final controller = _video;
      if (controller != null) unawaited(controller.pause());
      return;
    }
    if (widget.items.isEmpty) return;
    if (widget.items[_index].isVideo) {
      final controller = _video;
      if (controller != null &&
          controller.value.isInitialized &&
          !_userPaused &&
          !_videoError) {
        if (controller.value.isCompleted && widget.items.length > 1) {
          _advance();
        } else {
          unawaited(controller.play());
        }
      }
    } else {
      _scheduleImageAdvance();
    }
  }

  void _stopVideo() {
    _videoGeneration++;
    final controller = _video;
    _video = null;
    if (controller != null) {
      controller.removeListener(_onVideoChanged);
      unawaited(controller.dispose());
    }
  }

  void _activateSlide(int index) {
    _advanceTimer?.cancel();
    _stopVideo();
    setState(() {
      _index = index;
      _loadingVideo = false;
      _videoError = false;
      _completionHandled = false;
      _userPaused = false;
      _muted = true;
    });
    final item = widget.items[index];
    if (item.isVideo) {
      _startVideo(item);
    } else {
      _scheduleImageAdvance();
    }
  }

  void _scheduleImageAdvance() {
    _advanceTimer?.cancel();
    if (!_canPlay || widget.items.length < 2) return;
    _advanceTimer = Timer(const Duration(seconds: 5), _advance);
  }

  void _advance() {
    if (!mounted ||
        !_canPlay ||
        widget.items.length < 2 ||
        !_pageController.hasClients) return;
    final next = (_index + 1) % widget.items.length;
    if (next == 0) {
      _pageController.jumpToPage(0);
    } else {
      unawaited(_pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      ));
    }
  }

  Future<void> _startVideo(KlasrumMediaItem item) async {
    final generation = _videoGeneration;
    final controller = VideoPlayerController.networkUrl(Uri.parse(item.url));
    _video = controller;
    controller.addListener(_onVideoChanged);
    setState(() => _loadingVideo = true);
    try {
      await controller.initialize();
      if (!mounted || generation != _videoGeneration) return;
      await controller.setVolume(0);
      await controller.setLooping(widget.items.length == 1);
      if (!mounted || generation != _videoGeneration) return;
      setState(() => _loadingVideo = false);
      if (_canPlay) await controller.play();
    } catch (_) {
      if (!mounted || generation != _videoGeneration) return;
      setState(() {
        _loadingVideo = false;
        _videoError = true;
      });
    }
  }

  void _onVideoChanged() {
    final controller = _video;
    if (!mounted || controller == null) return;
    final value = controller.value;
    if (value.hasError && !_videoError) {
      setState(() {
        _loadingVideo = false;
        _videoError = true;
      });
      return;
    }
    if (value.isCompleted && !_completionHandled && widget.items.length > 1) {
      _completionHandled = true;
      scheduleMicrotask(_advance);
    }
    setState(() {});
  }

  Future<void> _togglePlay() async {
    final controller = _video;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      _userPaused = true;
      await controller.pause();
    } else {
      _userPaused = false;
      if (controller.value.isCompleted) await controller.seekTo(Duration.zero);
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleMute() async {
    final controller = _video;
    if (controller == null || !controller.value.isInitialized) return;
    _muted = !_muted;
    await controller.setVolume(_muted ? 0 : 1);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _advanceTimer?.cancel();
    _stopVideo();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.items.length,
              onPageChanged: _activateSlide,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                if (item.isImage) {
                  return Image.network(
                    item.url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined, size: 40),
                    ),
                  );
                }
                if (!item.isVideo) {
                  return const Center(child: Icon(Icons.attach_file, size: 40));
                }
                final controller = index == _index ? _video : null;
                return ColoredBox(
                  color: Colors.black,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (controller != null &&
                          controller.value.isInitialized &&
                          !_videoError)
                        LayoutBuilder(builder: (context, _) {
                          final size = controller.value.size;
                          return FittedBox(
                            fit: BoxFit.contain,
                            child: SizedBox(
                              width: size.width,
                              height: size.height,
                              child: VideoPlayer(controller),
                            ),
                          );
                        }),
                      if (_loadingVideo && index == _index)
                        const CircularProgressIndicator(color: Colors.white),
                      if (_videoError && index == _index)
                        TextButton.icon(
                          onPressed: () => _activateSlide(index),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry video'),
                        ),
                      if (controller != null &&
                          controller.value.isInitialized &&
                          !_videoError) ...[
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: IconButton.filledTonal(
                            tooltip:
                                controller.value.isPlaying ? 'Pause' : 'Play',
                            onPressed: _togglePlay,
                            icon: Icon(controller.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: IconButton.filledTonal(
                            tooltip: _muted ? 'Unmute' : 'Mute',
                            onPressed: _toggleMute,
                            icon: Icon(
                                _muted ? Icons.volume_off : Icons.volume_up),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        if (widget.items.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.items.length, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: index == _index ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: index == _index
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}
