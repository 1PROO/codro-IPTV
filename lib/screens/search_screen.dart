import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/iptv_provider.dart';
import '../models/stream_item.dart';
import '../widgets/glassy_card.dart';
import 'live_player_screen.dart';
import 'series_details_screen.dart';
import 'movie_details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  List<StreamItem> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _performSearch(_searchController.text);
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
        });
      }
      return;
    }

    if (mounted) setState(() => _isSearching = true);

    final iptv = Provider.of<IptvProvider>(context, listen: false);

    // Build a combined list from Provider memory
    final List<StreamItem> allItems = [
      ...iptv.dashboardLive,
      ...iptv.dashboardMovies,
      ...iptv.dashboardSeries,
      ...iptv.streams,
      ...iptv.vodStreams,
      ...iptv.seriesItems,
    ];

    // Remove duplicates
    final seen = <String>{};
    final uniqueItems = allItems
        .where((item) => seen.add(item.streamId))
        .toList();

    // Filter by tab
    List<StreamItem> filtered;
    switch (_tabController.index) {
      case 1:
        filtered = uniqueItems
            .where((i) => i.contentType == ContentType.live)
            .toList();
        break;
      case 2:
        filtered = uniqueItems
            .where((i) => i.contentType == ContentType.movie)
            .toList();
        break;
      case 3:
        filtered = uniqueItems
            .where((i) => i.contentType == ContentType.series)
            .toList();
        break;
      default:
        filtered = uniqueItems;
    }

    // Perform search
    final lowercaseQuery = query.toLowerCase().trim();
    final results = filtered.where((item) {
      return item.name.toLowerCase().contains(lowercaseQuery);
    }).toList();

    // Smart Ranking
    results.sort((a, b) {
      final aName = a.name.toLowerCase();
      final bName = b.name.toLowerCase();
      if (aName == lowercaseQuery && bName != lowercaseQuery) return -1;
      if (bName == lowercaseQuery && aName != lowercaseQuery) return 1;
      final aStarts = aName.startsWith(lowercaseQuery);
      final bStarts = bName.startsWith(lowercaseQuery);
      if (aStarts && !bStarts) return -1;
      if (bStarts && !aStarts) return 1;
      return aName.compareTo(bName);
    });

    if (mounted) {
      setState(() {
        _searchResults = results.take(50).toList();
        _isSearching = false;
      });
    }
  }

  String _getTypeLabel(ContentType type) {
    switch (type) {
      case ContentType.live:
        return '📺 قناة';
      case ContentType.movie:
        return '🎬 فيلم';
      case ContentType.series:
        return '📺 مسلسل';
    }
  }

  IconData _getTypeIcon(ContentType type) {
    switch (type) {
      case ContentType.live:
        return Icons.live_tv;
      case ContentType.movie:
        return Icons.movie;
      case ContentType.series:
        return Icons.tv;
    }
  }

  void _navigateToContent(StreamItem item) {
    if (item.contentType == ContentType.series) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SeriesDetailsScreen(
            seriesId: item.streamId,
            seriesName: item.name,
            cover: item.streamIcon,
          ),
        ),
      );
    } else if (item.contentType == ContentType.movie) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MovieDetailsScreen(
            streamId: item.streamId,
            movieName: item.name,
            cover: item.streamIcon,
            container: item.containerExtension,
          ),
        ),
      );
    } else {
      // Live TV
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LivePlayerScreen(
            streamId: item.streamId,
            streamName: item.name,
            icon: item.streamIcon,
          ),
        ),
      );
    }
  }

  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) {
      return Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.right,
      );
    }

    final lowercaseText = text.toLowerCase();
    final lowercaseQuery = query.toLowerCase();
    final startIndex = lowercaseText.indexOf(lowercaseQuery);

    if (startIndex == -1) {
      return Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.right,
      );
    }

    final endIndex = startIndex + query.length;
    final beforeMatch = text.substring(0, startIndex);
    final match = text.substring(startIndex, endIndex);
    final afterMatch = text.substring(endIndex);

    return RichText(
      textAlign: TextAlign.right,
      text: TextSpan(
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontFamily: 'Outfit',
        ),
        children: [
          TextSpan(text: beforeMatch),
          TextSpan(
            text: match,
            style: const TextStyle(
              color: Colors.black,
              backgroundColor: Colors.white,
            ),
          ),
          TextSpan(text: afterMatch),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final iptv = Provider.of<IptvProvider>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.right,
          decoration: const InputDecoration(
            hintText: '...ابحث عن فيلم، مسلسل، أو قناة',
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
          ),
          onChanged: _onSearchChanged,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.white),
              onPressed: () {
                _searchController.clear();
                _performSearch('');
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'الكل'),
            Tab(text: 'قنوات'),
            Tab(text: 'أفلام'),
            Tab(text: 'مسلسلات'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (iptv.isSyncing)
            LinearProgressIndicator(
              value: iptv.syncProgress,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          Expanded(
            child: _isSearching
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : _searchResults.isEmpty
                ? _buildEmptyState()
                : _buildResultsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchController.text.isEmpty ? Icons.search : Icons.search_off,
            size: 100,
            color: Colors.white12,
          ),
          const SizedBox(height: 20),
          Text(
            _searchController.text.isEmpty
                ? 'ابحث عن محتواك المفضل'
                : 'لم يتم العثور على نتائج',
            style: const TextStyle(color: Colors.white54, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassyCard(
            height: null,
            padding: EdgeInsets.zero,
            onTap: () => _navigateToContent(item),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Icon(
                    item.contentType == ContentType.series
                        ? Icons.arrow_back_ios
                        : Icons.play_circle_outline,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildHighlightedText(
                          item.name,
                          _searchController.text,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _getTypeLabel(item.contentType),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: item.streamIcon,
                      httpHeaders: const {'User-Agent': 'IPTVSmarters'},
                      width: 60,
                      height: 90,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: Colors.white10),
                      errorWidget: (context, url, e) => Container(
                        color: Colors.white10,
                        child: Icon(
                          _getTypeIcon(item.contentType),
                          color: Colors.white24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
