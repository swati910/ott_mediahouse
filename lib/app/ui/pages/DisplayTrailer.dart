import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:universal_html/html.dart' as html;

class TrailerPage extends StatefulWidget {
  final String trailerUrl;

  const TrailerPage({super.key, required this.trailerUrl});

  @override
  State<TrailerPage> createState() => _TrailerPageState();
}

class _TrailerPageState extends State<TrailerPage> with WidgetsBindingObserver {
  late final Player _player;
  late final VideoController _videoController;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  bool _hasPlayer = false;
  bool _isMuted = false;
  bool _isReady = false;
  bool _wasPlayingBeforeBackground = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final url = widget.trailerUrl.trim();
    if (url.isEmpty) {
      setState(() {
        _errorMessage = 'Video URL is not available.';
      });
      return;
    }

    _player = Player(
      configuration: const PlayerConfiguration(
        title: 'OTT Production House Player',
        bufferSize: 64 * 1024 * 1024,
      ),
    );
    _videoController = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );
    _hasPlayer = true;

    _subscriptions.add(
      _player.stream.error.listen((error) {
        if (!mounted) return;
        setState(() {
          _errorMessage = error;
        });
      }),
    );

    _subscriptions.add(
      _player.stream.playing.listen((playing) {
        if (mounted) setState(() {});
      }),
    );

    try {
      // media_kit keeps compatibility with MP4, HLS (.m3u8), DASH, audio-only
      // URLs, embedded subtitle tracks, and remote HTTP/HTTPS media.
      await _player.open(Media(url), play: false);
      await _player.setVolume(100);
      if (!mounted) return;
      setState(() {
        _isReady = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
      _errorMessage = 'Unable to load the media. Please try again.';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isReady) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _wasPlayingBeforeBackground = _player.state.playing;
      _player.pause();
    } else if (state == AppLifecycleState.resumed &&
        _wasPlayingBeforeBackground) {
      _wasPlayingBeforeBackground = false;
      _player.play();
    }
  }

  Future<void> _seekForward() async {
    final position = _player.state.position;
    final duration = _player.state.duration;
    final target = position + const Duration(seconds: 10);
    await _player.seek(
        duration > Duration.zero && target > duration ? duration : target);
  }

  Future<void> _seekBackward() async {
    final position = _player.state.position;
    final target = position - const Duration(seconds: 10);
    await _player.seek(target.isNegative ? Duration.zero : target);
  }

  Future<void> _toggleMute() async {
    final muted = !_isMuted;
    await _player.setVolume(muted ? 0 : 100);
    if (!mounted) return;
    setState(() {
      _isMuted = muted;
    });
  }

  Future<void> _setPlaybackSpeed(double speed) async {
    await _player.setRate(speed);
    if (mounted) setState(() {});
  }

  void _downloadVideo() {
    html.AnchorElement(href: widget.trailerUrl)
      ..target = 'blank'
      ..download = widget.trailerUrl.split('/').last
      ..click();
  }

  Future<void> _enterFullscreen() async {
    await defaultEnterNativeFullscreen();
  }

  Future<void> _exitFullscreen() async {
    await defaultExitNativeFullscreen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    if (_hasPlayer) {
      unawaited(_player.dispose());
    }
    unawaited(_exitFullscreen());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _buildPlayerSurface(theme),
            ),
          ),
          Offstage(child: _buildControlBar(theme)),
        ],
      ),
    );
  }

  Widget _buildPlayerSurface(ThemeData theme) {
    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          _errorMessage!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white),
        ),
      );
    }

    if (!_isReady) {
      return CircularProgressIndicator(color: theme.primaryColor);
    }

    return MaterialVideoControlsTheme(
      normal: MaterialVideoControlsThemeData(
        seekBarPositionColor: theme.primaryColor,
        seekBarThumbColor: theme.primaryColor,
        bufferingIndicatorBuilder: (_) => CircularProgressIndicator(
          color: theme.primaryColor,
        ),
      ),
      fullscreen: MaterialVideoControlsThemeData(
        seekBarPositionColor: theme.primaryColor,
        seekBarThumbColor: theme.primaryColor,
        bufferingIndicatorBuilder: (_) => CircularProgressIndicator(
          color: theme.primaryColor,
        ),
      ),
      child: Video(
        controller: _videoController,
        fit: BoxFit.contain,
        controls: AdaptiveVideoControls,
        wakelock: true,
        pauseUponEnteringBackgroundMode: true,
        resumeUponEnteringForegroundMode: false,
        onEnterFullscreen: _enterFullscreen,
        onExitFullscreen: _exitFullscreen,
        subtitleViewConfiguration: const SubtitleViewConfiguration(
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 4),
            ],
          ),
          padding: EdgeInsets.only(bottom: 24),
        ),
      ),
    );
  }

  Widget _buildControlBar(ThemeData theme) {
    if (!_isReady || _errorMessage != null) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              tooltip: 'Back 10 seconds',
              icon: const Icon(Icons.replay_10, color: Colors.blue),
              onPressed: _seekBackward,
            ),
            IconButton(
              tooltip: _isMuted ? 'Unmute' : 'Mute',
              icon: Icon(
                _isMuted ? Icons.volume_off : Icons.volume_up,
                color: Colors.blue,
              ),
              onPressed: _toggleMute,
            ),
            IconButton(
              tooltip: 'Forward 10 seconds',
              icon: const Icon(Icons.forward_10, color: Colors.blue),
              onPressed: _seekForward,
            ),
            Visibility(
              visible: false,
              maintainState: true,
              child: ElevatedButton.icon(
                onPressed: _downloadVideo,
                icon: const Icon(Icons.download),
                label: const Text("Download"),
              ),
            ),
            StreamBuilder<double>(
              stream: _player.stream.rate,
              initialData: _player.state.rate,
              builder: (context, snapshot) {
                final currentSpeed = _normalizedSpeed(snapshot.data ?? 1.0);
                return DropdownButton<double>(
                  dropdownColor: theme.cardColor,
                  value: currentSpeed,
                  items: const [0.5, 1.0, 1.5, 2.0].map((speed) {
                    return DropdownMenuItem(
                      value: speed,
                      child: Text(
                        "$speed",
                        style: TextStyle(color: theme.canvasColor),
                      ),
                    );
                  }).toList(),
                  onChanged: (speed) {
                    if (speed != null) {
                      _setPlaybackSpeed(speed);
                    }
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  double _normalizedSpeed(double speed) {
    const speeds = [0.5, 1.0, 1.5, 2.0];
    return speeds.contains(speed) ? speed : 1.0;
  }
}
