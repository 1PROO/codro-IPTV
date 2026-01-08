import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/iptv_provider.dart';
import '../widgets/embedded_player.dart';
import '../models/stream_item.dart';

class MovieDetailsScreen extends StatefulWidget {
  final String streamId;
  final String movieName;
  final String? cover;
  final String container;

  const MovieDetailsScreen({
    super.key,
    required this.streamId,
    required this.movieName,
    this.cover,
    this.container = 'mp4',
  });

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  Map<String, dynamic>? _movieInfo;
  bool _isLoading = true;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _loadMovieInfo();
  }

  Future<void> _loadMovieInfo() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final iptv = Provider.of<IptvProvider>(context, listen: false);

    final info = await iptv.getVodInfo(
      auth.host!,
      auth.username!,
      auth.password!,
      widget.streamId,
    );

    if (mounted) {
      setState(() {
        _movieInfo = info;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final iptv = Provider.of<IptvProvider>(context);
    final info = _movieInfo?['info'] ?? {};
    final tmdb = _movieInfo?['tmdb'] ?? {};
    final cast = (tmdb['cast'] as List?)?.take(5).toList() ?? [];
    // Placeholder for related movies - can be fetched from API later
    // final related = (tmdb['similar'] as List?)?.take(5).toList() ?? [];

    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.amber))
          : Column(
              children: [
                // Fixed Video Player / Cover at Top
                SafeArea(
                  bottom: false,
                  child: _isPlaying
                      ? EmbeddedPlayer(
                          streamId: widget.streamId,
                          streamName: widget.movieName,
                          isMovie: true,
                          container: widget.container,
                        )
                      : GestureDetector(
                          onTap: () => setState(() => _isPlaying = true),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  imageUrl:
                                      widget.cover ??
                                      info['movie_image'] ??
                                      info['cover_big'] ??
                                      '',
                                  httpHeaders: const {
                                    'User-Agent': 'IPTVSmarters',
                                  },
                                  fit: BoxFit.cover,
                                  errorWidget: (c, u, e) =>
                                      Container(color: Colors.grey[900]),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.8),
                                      ],
                                    ),
                                  ),
                                ),
                                const Center(
                                  child: Icon(
                                    Icons.play_circle_fill,
                                    color: Colors.white70,
                                    size: 80,
                                  ),
                                ),
                                Positioned(
                                  top: 10,
                                  left: 10,
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.arrow_back,
                                      color: Colors.white,
                                    ),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),

                // Scrollable Content Below
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title + Favorite
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  widget.movieName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              FutureBuilder<bool>(
                                future: iptv.isFavorite(widget.streamId),
                                builder: (context, snapshot) {
                                  final isFav = snapshot.data ?? false;
                                  return IconButton(
                                    icon: Icon(
                                      isFav
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: isFav ? Colors.red : Colors.white,
                                    ),
                                    onPressed: () {
                                      iptv.toggleFavorite(
                                        StreamItem(
                                          num: 0,
                                          name: widget.movieName,
                                          streamId: widget.streamId,
                                          streamIcon: widget.cover ?? '',
                                          categoryId: '',
                                          containerExtension: widget.container,
                                          contentType: ContentType.movie,
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Rating, Year, Genre
                          Row(
                            children: [
                              _infoChip(
                                info['rating']?.toString() ?? 'N/A',
                                Colors.amber,
                              ),
                              const SizedBox(width: 10),
                              _infoChip(
                                info['releasedate']
                                        ?.toString()
                                        .split('-')
                                        .first ??
                                    'N/A',
                                Colors.white24,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  info['genre'] ?? 'N/A',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Description
                          const Text(
                            'Describe',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            info['plot'] ??
                                info['description'] ??
                                'لا يوجد وصف متاح.',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              height: 1.5,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 24),

                          // Actors
                          if (cast.isNotEmpty) ...[
                            const Text(
                              'Actor',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 100,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: cast.length,
                                itemBuilder: (context, index) {
                                  final actor = cast[index];
                                  return _actorCard(actor);
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // You might like it (Placeholder)
                          const Text(
                            'You might like it',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 180,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: 3,
                              itemBuilder: (context, index) {
                                return _relatedMovieCard(
                                  'Related Movie ${index + 1}',
                                  '', // No image for placeholder
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _infoChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color == Colors.amber ? Colors.amber : Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _actorCard(Map<String, dynamic> actor) {
    final name = actor['name'] ?? 'Unknown';
    final character = actor['character'] ?? '';
    final profilePath = actor['profile_path'] ?? '';
    final imageUrl = profilePath.isNotEmpty
        ? 'https://image.tmdb.org/t/p/w185$profilePath'
        : '';

    return Container(
      width: 70,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.grey[800],
            backgroundImage: imageUrl.isNotEmpty
                ? CachedNetworkImageProvider(imageUrl)
                : null,
            child: imageUrl.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: const TextStyle(color: Colors.white, fontSize: 11),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            character,
            style: const TextStyle(color: Colors.white38, fontSize: 9),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _relatedMovieCard(String title, String imageUrl) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    height: 140,
                    width: 120,
                    fit: BoxFit.cover,
                    errorWidget: (c, u, e) =>
                        Container(height: 140, color: Colors.grey[900]),
                  )
                : Container(
                    height: 140,
                    width: 120,
                    color: Colors.grey[900],
                    child: const Icon(
                      Icons.movie,
                      color: Colors.white24,
                      size: 40,
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
