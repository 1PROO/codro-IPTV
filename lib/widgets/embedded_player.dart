import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import '../providers/auth_provider.dart';
import '../services/xtream_service.dart';

class EmbeddedPlayer extends StatefulWidget {
  final String streamId;
  final String streamName;
  final bool isMovie;
  final bool isSeries;
  final String container;
  final VoidCallback? onFullScreenToggle;

  const EmbeddedPlayer({
    super.key,
    required this.streamId,
    required this.streamName,
    this.isMovie = false,
    this.isSeries = false,
    this.container = 'mp4',
    this.onFullScreenToggle,
  });

  @override
  State<EmbeddedPlayer> createState() => _EmbeddedPlayerState();
}

class _EmbeddedPlayerState extends State<EmbeddedPlayer> {
  late final Player _player;
  late final VideoController _controller;
  final _xtreamService = XtreamService();

  bool _isLoading = true;
  bool _isError = false;
  String? _errorMessage;
  bool _isFullscreen = false;
  bool _showControls = false;
  Timer? _hideControlsTimer;

  // Gesture states
  double _volumeValue = 0.5;
  double _brightnessValue = 0.5;
  bool _showVolumeIndicator = false;
  bool _showBrightnessIndicator = false;
  Timer? _indicatorTimer;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _initSystemStates();
  }

  Future<void> _initSystemStates() async {
    try {
      _brightnessValue = await ScreenBrightness().current;
      VolumeController().getVolume().then((v) => _volumeValue = v);
    } catch (_) {}
  }

  Future<void> _initializePlayer() async {
    _player = Player();
    _controller = VideoController(_player);

    _setupListeners();
    _playStream();
  }

  void _setupListeners() {
    _player.stream.buffering.listen((buffering) {
      if (mounted) setState(() => _isLoading = buffering);
    });

    _player.stream.error.listen((error) {
      if (mounted) {
        setState(() {
          _isError = true;
          _errorMessage = error.toString();
        });
      }
    });
  }

  Future<void> _playStream() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    String url;
    if (widget.isMovie) {
      url = _xtreamService.buildMovieUrl(
        auth.host!,
        auth.username!,
        auth.password!,
        widget.streamId,
        container: widget.container,
      );
    } else if (widget.isSeries) {
      url = _xtreamService.buildSeriesUrl(
        auth.host!,
        auth.username!,
        auth.password!,
        widget.streamId,
        widget.container,
      );
    } else {
      url = _xtreamService.buildStreamUrl(
        auth.host!,
        auth.username!,
        auth.password!,
        widget.streamId,
      );
    }

    try {
      await _player.open(Media(url));
    } catch (e) {
      if (mounted) {
        setState(() {
          _isError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });

    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    if (widget.onFullScreenToggle != null) {
      widget.onFullScreenToggle!();
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _resetHideTimer();
    }
  }

  void _resetHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final isRightSide = details.globalPosition.dx > screenWidth / 2;

    if (isRightSide) {
      // Volume
      _volumeValue -= details.delta.dy / 200;
      _volumeValue = _volumeValue.clamp(0.0, 1.0);
      VolumeController().setVolume(_volumeValue);
      setState(() => _showVolumeIndicator = true);
    } else {
      // Brightness
      _brightnessValue -= details.delta.dy / 200;
      _brightnessValue = _brightnessValue.clamp(0.0, 1.0);
      ScreenBrightness().setScreenBrightness(_brightnessValue);
      setState(() => _showBrightnessIndicator = true);
    }

    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _showVolumeIndicator = false;
          _showBrightnessIndicator = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _indicatorTimer?.cancel();
    _player.dispose();
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: GestureDetector(
        onTap: _toggleControls,
        onVerticalDragUpdate: _handleVerticalDragUpdate,
        child: Stack(
          children: [
            Video(controller: _controller, controls: NoVideoControls),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            if (_isError)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    Text(
                      _errorMessage ?? 'Error',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            if (_showControls) _buildControls(),

            // Volume Indicator
            if (_showVolumeIndicator)
              _buildGestureIndicator(Icons.volume_up, _volumeValue, true),
            // Brightness Indicator
            if (_showBrightnessIndicator)
              _buildGestureIndicator(
                Icons.brightness_6,
                _brightnessValue,
                false,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGestureIndicator(IconData icon, double value, bool isRight) {
    return Align(
      alignment: isRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(height: 5),
            SizedBox(
              height: 100,
              width: 5,
              child: LinearProgressIndicator(
                value: value,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      color: Colors.black26,
      child: Stack(
        children: [
          // Header (Name + Cast)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      widget.streamName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cast, color: Colors.white),
                    onPressed: () {
                      // Placeholder for Cast
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Casting to screen...')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Center Controls
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.replay_10,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: () => _player.seek(
                    _player.state.position - const Duration(seconds: 10),
                  ),
                ),
                const SizedBox(width: 20),
                IconButton(
                  icon: Icon(
                    _player.state.playing
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: Colors.white,
                    size: 60,
                  ),
                  onPressed: () => _player.playOrPause(),
                ),
                const SizedBox(width: 20),
                IconButton(
                  icon: const Icon(
                    Icons.forward_10,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: () => _player.seek(
                    _player.state.position + const Duration(seconds: 10),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Controls (Seekbar + Fullscreen)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSeekbar(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_player.state.position),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _formatDuration(_player.state.duration),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.aspect_ratio,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () {
                          // Toggle fit if needed
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          _isFullscreen
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                          color: Colors.white,
                        ),
                        onPressed: _toggleFullscreen,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeekbar() {
    final pos = _player.state.position.inMilliseconds.toDouble();
    final dur = _player.state.duration.inMilliseconds.toDouble();
    if (dur <= 0) return const SizedBox.shrink();

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 2,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
        activeTrackColor: Colors.amber,
        inactiveTrackColor: Colors.white24,
        thumbColor: Colors.amber,
      ),
      child: Slider(
        min: 0,
        max: dur,
        value: pos.clamp(0, dur),
        onChanged: (val) {
          _player.seek(Duration(milliseconds: val.toInt()));
        },
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return "${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}";
    }
    return "${d.inMinutes.remainder(60)}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}";
  }
}
