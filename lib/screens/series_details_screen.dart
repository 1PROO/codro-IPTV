import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../providers/iptv_provider.dart';
import '../widgets/embedded_player.dart';
import '../models/stream_item.dart';

class SeriesDetailsScreen extends StatefulWidget {
  final String seriesId;
  final String seriesName;
  final String? cover;

  const SeriesDetailsScreen({
    super.key,
    required this.seriesId,
    required this.seriesName,
    this.cover,
  });

  @override
  State<SeriesDetailsScreen> createState() => _SeriesDetailsScreenState();
}

class _SeriesDetailsScreenState extends State<SeriesDetailsScreen> {
  Map<String, dynamic>? _seriesInfo;
  bool _isLoading = true;
  String? _selectedSeason;
  Map<String, dynamic>? _currentPlayingEpisode;

  @override
  void initState() {
    super.initState();
    _loadSeriesInfo();
  }

  Future<void> _loadSeriesInfo() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final iptv = Provider.of<IptvProvider>(context, listen: false);
    final info = await iptv.getSeriesInfo(
      auth.host!,
      auth.username!,
      auth.password!,
      widget.seriesId,
    );

    if (mounted) {
      setState(() {
        _seriesInfo = info;
        _isLoading = false;
        if (info != null &&
            info['seasons'] != null &&
            (info['seasons'] as List).isNotEmpty) {
          _selectedSeason = (info['seasons'][0]['season_number']).toString();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final iptv = Provider.of<IptvProvider>(context);
    final info = _seriesInfo?['info'] ?? {};
    final episodes = _seriesInfo?['episodes'] ?? {};
    final seasonsList = _seriesInfo?['seasons'] as List? ?? [];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Fixed Player at Top
          SafeArea(
            bottom: false,
            child: _currentPlayingEpisode != null
                ? EmbeddedPlayer(
                    streamId: _currentPlayingEpisode!['id'].toString(),
                    streamName:
                        _currentPlayingEpisode!['title'] ?? widget.seriesName,
                    isSeries: true,
                    container:
                        _currentPlayingEpisode!['container_extension'] ?? 'mp4',
                  )
                : AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: widget.cover ?? info['cover'] ?? '',
                          httpHeaders: const {'User-Agent': 'IPTVSmarters'},
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => const Icon(
                            Icons.tv,
                            size: 100,
                            color: Colors.white24,
                          ),
                        ),
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.black, Colors.transparent],
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            widget.seriesName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(blurRadius: 10, color: Colors.black),
                              ],
                            ),
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

          // Scrollable Content
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title + Favorite
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.seriesName,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            FutureBuilder<bool>(
                              future: iptv.isFavorite(widget.seriesId),
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
                                        name: widget.seriesName,
                                        streamId: widget.seriesId,
                                        streamIcon: widget.cover ?? '',
                                        categoryId: '',
                                        contentType: ContentType.series,
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _infoChip(
                              Icons.star,
                              info['rating']?.toString() ?? 'N/A',
                            ),
                            const SizedBox(width: 10),
                            _infoChip(
                              Icons.calendar_today,
                              info['releaseDate'] ?? 'N/A',
                            ),
                            const SizedBox(width: 10),
                            _infoChip(Icons.movie, info['genre'] ?? 'N/A'),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          info['plot'] ?? 'لا يوجد وصف متاح.',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.right, // Arabic support
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          'المواسم',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.right,
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 50,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            reverse: true, // RTL for Arabic
                            itemCount: seasonsList.length,
                            itemBuilder: (context, index) {
                              final sNum = seasonsList[index]['season_number']
                                  .toString();
                              final isSelected = _selectedSeason == sNum;
                              return Padding(
                                padding: const EdgeInsets.only(left: 10.0),
                                child: ChoiceChip(
                                  label: Text('موسم $sNum'),
                                  selected: isSelected,
                                  selectedColor: Colors.white,
                                  backgroundColor: Colors.white10,
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.white70,
                                  ),
                                  onSelected: (val) {
                                    setState(() => _selectedSeason = sNum);
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                _buildEpisodesList(episodes),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodesList(Map<String, dynamic> allEpisodes) {
    final currentEpisodes = allEpisodes[_selectedSeason] as List? ?? [];

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final ep = currentEpisodes[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 80,
              height: 50,
              color: Colors.white10,
              child: const Icon(Icons.play_arrow, color: Colors.white),
            ),
          ),
          title: Text(
            'الحلقة ${ep['episode_num']} - ${ep['title'] ?? ""}',
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.right,
          ),
          subtitle: Text(
            ep['duration'] ?? '',
            style: const TextStyle(color: Colors.white54),
            textAlign: TextAlign.right,
          ),
          onTap: () {
            setState(() {
              _currentPlayingEpisode = ep;
            });
          },
        );
      }, childCount: currentEpisodes.length),
    );
  }
}
