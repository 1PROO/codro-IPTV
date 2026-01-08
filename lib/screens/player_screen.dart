import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/xtream_service.dart';
import '../widgets/advanced_video_player.dart';

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
  final _xtreamService = XtreamService();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: AdvancedVideoPlayer(
            url: _buildUrl(),
            title: widget.streamName,
            isLive: !widget.isMovie && !widget.isSeries,
          ),
        ),
      ),
    );
  }
}
