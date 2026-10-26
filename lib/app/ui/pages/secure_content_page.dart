import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_house/data/services/secure_playback_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class SecureContentPage extends StatefulWidget {
  const SecureContentPage({
    super.key,
    required this.contentId,
    required this.contentUrl,
    required this.contentType,
  });

  final String contentId;
  final String contentUrl;
  final String contentType;

  @override
  State<SecureContentPage> createState() => _SecureContentPageState();
}

class _SecureContentPageState extends State<SecureContentPage>
    with WidgetsBindingObserver {
  static const _screenChannel = MethodChannel('com.filmytell.ott/anti_piracy');
  final SecurePlaybackService _service = SecurePlaybackService();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  late final Player _player;
  late final VideoController _videoController;
  Timer? _refreshTimer;
  Future<void>? _authorizationRequest;
  bool _ready = false;
  bool _disposed = false;
  bool _handled403 = false;
  bool _resumeAfterForeground = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _player = Player(
      configuration: const PlayerConfiguration(
        title: 'Secure Production House Player',
        bufferSize: 64 * 1024 * 1024,
      ),
    );
    _videoController = VideoController(_player);
    _subscriptions.add(_player.stream.error.listen(_onPlayerError));
    unawaited(_enableScreenProtection());
    unawaited(_authorizeAndLoad(isRefresh: false));
  }

  Future<void> _authorizeAndLoad({required bool isRefresh}) {
    return _authorizationRequest ??=
        _loadAuthorization(isRefresh: isRefresh).whenComplete(() {
      _authorizationRequest = null;
    });
  }

  Future<void> _loadAuthorization({required bool isRefresh}) async {
    final position = isRefresh ? _player.state.position : Duration.zero;
    final wasPlaying = isRefresh && _player.state.playing;
    final volume = _player.state.volume;
    final rate = _player.state.rate;
    if (mounted) {
      setState(() {
        _error = null;
        if (!isRefresh) _ready = false;
      });
    }
    try {
      final authorization = await _service.authorize(
        contentId: widget.contentId,
        playbackUrl: widget.contentUrl,
        type: widget.contentType,
      );
      if (_disposed) return;
      await _player.open(
        Media(
          authorization.playbackUrl,
          httpHeaders: authorization.httpHeaders,
        ),
        play: false,
      );
      if (position > Duration.zero) await _player.seek(position);
      await _player.setVolume(volume);
      await _player.setRate(rate);
      if (wasPlaying) await _player.play();
      _scheduleRefresh(authorization.expiresAt);
      if (mounted) setState(() => _ready = true);
    } on SecurePlaybackException catch (error) {
      await _player.pause();
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      await _player.pause();
      if (mounted) {
        setState(() =>
            _error = 'Secure playback could not be initialized. Please retry.');
      }
    }
  }

  void _scheduleRefresh(DateTime expiresAt) {
    _refreshTimer?.cancel();
    final remaining = expiresAt.difference(DateTime.now().toUtc());
    final delay = remaining - const Duration(seconds: 60);
    _refreshTimer = Timer(
      delay.isNegative ? Duration.zero : delay,
      () => unawaited(_authorizeAndLoad(isRefresh: true)),
    );
  }

  void _onPlayerError(String error) {
    if (_disposed) return;
    final is403 = RegExp(r'(^|\D)403(\D|$)').hasMatch(error);
    if (is403 && !_handled403) {
      _handled403 = true;
      unawaited(_authorizeAndLoad(isRefresh: true));
      return;
    }
    if (mounted) {
      setState(() => _error =
          'Protected content could not be played. Please retry securely.');
    }
  }

  Future<void> _enableScreenProtection() async {
    try {
      await _screenChannel.invokeMethod<void>('enableSecureScreen');
    } catch (_) {}
  }

  Future<void> _disableScreenProtection() async {
    try {
      await _screenChannel.invokeMethod<void>('disableSecureScreen');
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _resumeAfterForeground = _player.state.playing;
      unawaited(_player.pause());
    } else if (state == AppLifecycleState.resumed && _resumeAfterForeground) {
      _resumeAfterForeground = false;
      unawaited(_player.play());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_player.dispose());
    _service.dispose();
    unawaited(_disableScreenProtection());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: const Text('Secure Content Playback')),
        body: Center(
          child: _error != null
              ? _errorView()
              : !_ready
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Preparing secure playback...',
                            style: TextStyle(color: Colors.white)),
                      ],
                    )
                  : Video(controller: _videoController),
        ),
      );

  Widget _errorView() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.gpp_bad, color: Colors.white, size: 42),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _authorizeAndLoad(isRefresh: _ready),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry securely'),
            ),
          ],
        ),
      );
}
