import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:pip/pip.dart';
import 'package:path/path.dart' as p;

class UniversalVideoPlayer extends StatefulWidget {
  final String source;

  const UniversalVideoPlayer({super.key, required this.source});

  @override
  State<UniversalVideoPlayer> createState() => _UniversalVideoPlayerState();
}

class _UniversalVideoPlayerState extends State<UniversalVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  final Pip _pip = Pip();

  bool get _isUrl => widget.source.startsWith('http://') || widget.source.startsWith('https://');
  bool get _isHls => widget.source.endsWith('.m3u8');

  @override
  void initState() {
    super.initState();
    _initController();
    _setupPip();
  }

  Future<void> _initController() async {
    if (_isUrl) {
      _controller = VideoPlayerController.network(widget.source);
    } else {
      _controller = VideoPlayerController.file(File(widget.source));
    }
    await _controller.initialize();
    setState(() => _isInitialized = true);
    _controller.play();
  }

  Future<void> _setupPip() async {
    final isSupported = await _pip.isSupported();
    if (isSupported) {
      await _pip.setup(PipOptions(
        autoEnterEnabled: false,
        aspectRatioX: 16,
        aspectRatioY: 9,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pip.dispose();
    super.dispose();
  }

  Future<void> _enterPiP() async {
    if (await _pip.isSupported()) {
      await _pip.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(p.basename(widget.source)),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_in_picture),
            onPressed: _enterPiP,
            tooltip: 'Enter PiP',
          ),
        ],
      ),
      body: Center(
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              VideoPlayer(_controller),
              _ControlsOverlay(controller: _controller),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlsOverlay extends StatelessWidget {
  final VideoPlayerController controller;
  const _ControlsOverlay({required this.controller});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }
      },
      child: Container(
        color: Colors.black26,
        child: Center(
          child: Icon(
            controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
            color: Colors.white,
            size: 64,
          ),
        ),
      ),
    );
  }
}