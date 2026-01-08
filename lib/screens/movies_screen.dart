import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../providers/iptv_provider.dart';
import 'search_screen.dart';
import 'movie_details_screen.dart';

class MoviesScreen extends StatefulWidget {
  const MoviesScreen({super.key});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
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

    await iptv.fetchVodCategories(auth.host!, auth.username!, auth.password!);
    if (iptv.vodCategories.isNotEmpty && _selectedCategoryId == null) {
      if (mounted) {
        setState(
          () => _selectedCategoryId = iptv.vodCategories.first.categoryId,
        );
        _loadStreams();
      }
    }
  }

  void _loadStreams() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    Provider.of<IptvProvider>(context, listen: false).fetchVodStreams(
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
        title: const Text('أفلام', style: TextStyle(color: Colors.white)),
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
          if (iptv.vodCategories.isNotEmpty)
            SizedBox(
              height: 50,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                reverse: true,
                itemCount: iptv.vodCategories.length,
                itemBuilder: (context, index) {
                  final cat = iptv.vodCategories[index];
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
          Expanded(child: _buildMoviesGrid(iptv)),
        ],
      ),
    );
  }

  Widget _buildMoviesGrid(IptvProvider iptv) {
    return iptv.isLoadingVod
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: iptv.vodStreams.length,
            itemBuilder: (context, index) {
              final movie = iptv.vodStreams[index];
              return _buildMovieCard(movie);
            },
          );
  }

  Widget _buildMovieCard(dynamic movie) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MovieDetailsScreen(
              streamId: movie.streamId,
              movieName: movie.name,
              cover: movie.streamIcon,
              container: movie.containerExtension,
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
                  imageUrl: movie.streamIcon,
                  httpHeaders: const {'User-Agent': 'IPTVSmarters'},
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.movie, size: 50, color: Colors.white24),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                movie.name,
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
