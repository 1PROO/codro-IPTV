import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/iptv_provider.dart';
import '../models/stream_item.dart';
import 'movie_details_screen.dart';
import 'series_details_screen.dart';
import 'player_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('المفضلة', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<StreamItem>>(
        future: Provider.of<IptvProvider>(
          context,
          listen: false,
        ).getFavorites(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.amber),
            );
          }

          final favorites = snapshot.data ?? [];

          if (favorites.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, color: Colors.white24, size: 80),
                  SizedBox(height: 16),
                  Text(
                    'لا توجد عناصر في المفضلة',
                    style: TextStyle(color: Colors.white54, fontSize: 18),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final item = favorites[index];
              return _buildFavoriteTile(context, item);
            },
          );
        },
      ),
    );
  }

  Widget _buildFavoriteTile(BuildContext context, StreamItem item) {
    return Card(
      color: Colors.white.withOpacity(0.05),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: item.streamIcon.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: item.streamIcon,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) =>
                      _placeholderIcon(item.contentType),
                )
              : _placeholderIcon(item.contentType),
        ),
        title: Text(
          item.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          _getTypeLabel(item.contentType),
          style: const TextStyle(color: Colors.white54),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.white24,
          size: 16,
        ),
        onTap: () => _navigateToContent(context, item),
      ),
    );
  }

  Widget _placeholderIcon(ContentType type) {
    IconData icon;
    switch (type) {
      case ContentType.live:
        icon = Icons.live_tv;
        break;
      case ContentType.movie:
        icon = Icons.movie;
        break;
      case ContentType.series:
        icon = Icons.video_library;
        break;
    }
    return Container(
      width: 60,
      height: 60,
      color: Colors.white10,
      child: Icon(icon, color: Colors.white24),
    );
  }

  String _getTypeLabel(ContentType type) {
    switch (type) {
      case ContentType.live:
        return 'قناة مباشرة';
      case ContentType.movie:
        return 'فيلم';
      case ContentType.series:
        return 'مسلسل';
    }
  }

  void _navigateToContent(BuildContext context, StreamItem item) {
    final destination = switch (item.contentType) {
      ContentType.live => PlayerScreen(
        streamId: item.streamId,
        streamName: item.name,
      ),
      ContentType.movie => MovieDetailsScreen(
        streamId: item.streamId,
        movieName: item.name,
        cover: item.streamIcon,
        container: item.containerExtension,
      ),
      ContentType.series => SeriesDetailsScreen(
        seriesId: item.streamId,
        seriesName: item.name,
        cover: item.streamIcon,
      ),
    };

    Navigator.push(context, MaterialPageRoute(builder: (_) => destination));
  }
}
