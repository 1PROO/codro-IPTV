import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/xtream_service.dart';

class PlayerScreen extends StatefulWidget {
  final String streamId;
  final String streamName;
  final bool isMovie;
  final bool isSeries;
  final String container;

  const PlayerScreen({
    super.key,
    required this.streamId,
    required this.streamName,
    this.isMovie = false,
    this.isSeries = false,
    this.container = 'mp4',
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  static bool _isMediaKitInitialized = false;

  late final Player _player;
  late final VideoController _controller;
  final _xtreamService = XtreamService();

  // State
  bool _isLoading = true;
  bool _isError = false;
  String? _errorMessage;
  bool _showControls = false;
  Timer? _hideControlsTimer;
  int _retryCount = 0;
  bool _isDisposed = false;

  // Constants
  static const int _maxVodRetries = 3;
  static const Duration _controlsTimeout = Duration(seconds: 4);

  final FocusNode _playPauseFocus = FocusNode();
  final FocusNode _backFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ensureMediaKitInitialized();
    _initializePlayer();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  static void _ensureMediaKitInitialized() {
    if (!_isMediaKitInitialized) {
      MediaKit.ensureInitialized();
      _isMediaKitInitialized = true;
    }
  }

  Future<void> _initializePlayer() async {
    _player = Player(
      configuration: const PlayerConfiguration(logLevel: MPVLogLevel.warn),
    );
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );

    _setupListeners();
    _playStream();
  }

  void _setupListeners() {
    _player.stream.error.listen((error) {
      debugPrint('MEDIA_KIT_ERROR: $error');
      _handleError('Playback Error: $error');
    });

    _player.stream.buffering.listen((buffering) {
      if (mounted) {
        setState(() {
          _isLoading = buffering;
        });
      }
    });

    _player.stream.completed.listen((completed) {
      if (completed) {
        if (widget.isMovie || widget.isSeries) {
          if (mounted) Navigator.pop(context);
        } else {
          _handleError('Stream Connection Lost');
        }
      }
    });

    _player.stream.playing.listen((playing) {
      if (playing) {
        _retryCount = 0;
      }
    });
  }

  String _buildUrl() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (widget.isMovie) {
      return _xtreamService.buildMovieUrl(
        auth.host!,
        auth.username!,
        auth.password!,
        widget.streamId,
        container: widget.container,
      );
    } else if (widget.isSeries) {
      return _xtreamService.buildSeriesUrl(
        auth.host!,
        auth.username!,
        auth.password!,
        widget.streamId,
        widget.container,
      );
    } else {
      return _xtreamService.buildStreamUrl(
        auth.host!,
        auth.username!,
        auth.password!,
        widget.streamId,
      );
    }
  }

  Future<void> _playStream() async {
    if (_isDisposed) return;

    setState(() {
      _isLoading = true;
      _isError = false;
      _errorMessage = null;
    });

    try {
      final url = _buildUrl();
      debugPrint('MEDIA_KIT: Opening $url');
      await _player.open(Media(url));
      _resetHideTimer();
      _playPauseFocus.requestFocus();
    } catch (e) {
      _handleError('Initialization Error: $e');
    }
  }

  void _handleError(String message) {
    if (_isDisposed) return;
    final isLive = !widget.isMovie && !widget.isSeries;

    if (isLive) {
      _retryLiveStream();
    } else {
      if (_retryCount < _maxVodRetries) {
        _retryCount++;
        Future.delayed(const Duration(seconds: 2), _playStream);
      } else {
        if (mounted) {
          setState(() {
            _isError = true;
            _errorMessage = message;
          });
        }
      }
    }
  }

  void _retryLiveStream() {
    int delaySeconds = (_retryCount < 5) ? 2 : 5;
    _retryCount++;
    Future.delayed(Duration(seconds: delaySeconds), () {
      if (!_isDisposed) _playStream();
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _resetHideTimer();
      _playPauseFocus.requestFocus();
    } else {
      _hideControlsTimer?.cancel();
    }
  }

  void _resetHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(_controlsTimeout, () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _onKeyPress(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.space) {
        _toggleControls();
      }
      if (_showControls) {
        _resetHideTimer();
      }
    }
  }

  void _seekRelative(int seconds) {
    final currentPosition = _player.state.position;
    final duration = _player.state.duration;
    final newPosition = currentPosition + Duration(seconds: seconds);
    if (newPosition < Duration.zero) {
      _player.seek(Duration.zero);
    } else if (newPosition > duration) {
      _player.seek(duration);
    } else {
      _player.seek(newPosition);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _hideControlsTimer?.cancel();
    _player.dispose();
    _playPauseFocus.dispose();
    _backFocus.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: _onKeyPress,
        autofocus: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControls,
          onDoubleTapDown: (details) {
            if (widget.isMovie || widget.isSeries) {
              final screenWidth = MediaQuery.of(context).size.width;
              if (details.globalPosition.dx < screenWidth / 3) {
                _seekRelative(-10);
              } else if (details.globalPosition.dx > screenWidth * 2 / 3) {
                _seekRelative(10);
              }
            }
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              Video(
                controller: _controller,
                controls: NoVideoControls,
                fit: BoxFit.contain,
              ),
              if (_isLoading && !_isError)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              if (_isError)
                Container(
                  color: Colors.black87,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage ?? 'Error',
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            _retryCount = 0;
                            _playStream();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_showControls && !_isError) _buildControlsOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.6),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                focusNode: _backFocus,
                onTap: () => Navigator.pop(context),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  widget.streamName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          InkWell(
            focusNode: _playPauseFocus,
            onTap: () {
              _player.playOrPause();
              _resetHideTimer();
            },
            child: StreamBuilder<bool>(
              stream: _player.stream.playing,
              builder: (context, snapshot) {
                final playing = snapshot.data ?? false;
                return Icon(
                  playing ? Icons.pause_circle : Icons.play_circle,
                  color: Colors.white,
                  size: 80,
                );
              },
            ),
          ),
          const Spacer(),
          if (widget.isMovie || widget.isSeries)
            StreamBuilder<Duration>(
              stream: _player.stream.position,
              builder: (context, snapshot) {
                final position = snapshot.data ?? Duration.zero;
                final duration = _player.state.duration;
                return Column(
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: Colors.white,
                        thumbColor: Colors.white,
                        inactiveTrackColor: Colors.white30,
                        trackHeight: 2.0,
                      ),
                      child: Slider(
                        value: duration.inSeconds > 0
                            ? position.inSeconds.toDouble()
                            : 0,
                        min: 0,
                        max: duration.inSeconds.toDouble(),
                        onChanged: (val) {
                          _player.seek(Duration(seconds: val.toInt()));
                          _resetHideTimer();
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(position),
                            style: const TextStyle(color: Colors.white),
                          ),
                          Text(
                            _formatDuration(duration),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }
}
