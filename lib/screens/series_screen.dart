import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../providers/iptv_provider.dart';
import 'series_details_screen.dart';
import 'search_screen.dart';

class SeriesScreen extends StatefulWidget {
  const SeriesScreen({super.key});

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final iptv = Provider.of<IptvProvider>(context, listen: false);

    await iptv.fetchSeriesCategories(
      auth.host!,
      auth.username!,
      auth.password!,
    );
    if (iptv.seriesCategories.isNotEmpty && _selectedCategoryId == null) {
      if (mounted) {
        setState(
          () => _selectedCategoryId = iptv.seriesCategories.first.categoryId,
        );
        _loadStreams();
      }
    }
  }

  void _loadStreams() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    Provider.of<IptvProvider>(context, listen: false).fetchSeries(
      auth.host!,
      auth.username!,
      auth.password!,
      categoryId: _selectedCategoryId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final iptv = Provider.of<IptvProvider>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('مسلسلات', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (iptv.seriesCategories.isNotEmpty)
            SizedBox(
              height: 50,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                reverse: true,
                itemCount: iptv.seriesCategories.length,
                itemBuilder: (context, index) {
                  final cat = iptv.seriesCategories[index];
                  final isSelected = _selectedCategoryId == cat.categoryId;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: ActionChip(
                      label: Text(cat.categoryName),
                      backgroundColor: isSelected
                          ? Colors.white
                          : Colors.white10,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : Colors.white70,
                      ),
                      onPressed: () {
                        setState(() => _selectedCategoryId = cat.categoryId);
                        _loadStreams();
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide.none,
                      ),
                    ),
                  );
                },
              ),
            ),
          Expanded(child: _buildSeriesGrid(iptv)),
        ],
      ),
    );
  }

  Widget _buildSeriesGrid(IptvProvider iptv) {
    return iptv.isLoadingSeries
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: iptv.seriesItems.length,
            itemBuilder: (context, index) {
              final series = iptv.seriesItems[index];
              return _buildSeriesCard(series);
            },
          );
  }

  Widget _buildSeriesCard(dynamic series) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SeriesDetailsScreen(
              seriesId: series.streamId,
              seriesName: series.name,
              cover: series.streamIcon,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: CachedNetworkImage(
                  imageUrl: series.streamIcon,
                  httpHeaders: const {'User-Agent': 'IPTVSmarters'},
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorWidget: (context, url, error) => const Icon(
                    Icons.tv_outlined,
                    size: 50,
                    color: Colors.white24,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                series.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
