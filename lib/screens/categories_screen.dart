import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/auth_provider.dart';
import '../providers/iptv_provider.dart';
import 'live_player_screen.dart';
import 'search_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
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

    await iptv.fetchCategories(auth.host!, auth.username!, auth.password!);
    if (iptv.categories.isNotEmpty && _selectedCategoryId == null) {
      if (mounted) {
        setState(() {
          _selectedCategoryId = iptv.categories.first.categoryId;
        });
        _loadStreams();
      }
    }
  }

  void _loadStreams() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    Provider.of<IptvProvider>(context, listen: false).fetchStreams(
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
        title: const Text('بث مباشر', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
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
          if (iptv.categories.isNotEmpty)
            SizedBox(
              height: 50,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                reverse: true, // RTL
                itemCount: iptv.categories.length,
                itemBuilder: (context, index) {
                  final cat = iptv.categories[index];
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
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
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
          Expanded(child: _buildStreamsGrid(iptv)),
        ],
      ),
    );
  }

  Widget _buildStreamsGrid(IptvProvider iptv) {
    return iptv.isLoadingLive
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : iptv.streams.isEmpty
        ? const Center(
            child: Text('لا توجد قنوات', style: TextStyle(color: Colors.white)),
          )
        : GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.9,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            cacheExtent: 1000,
            itemCount: iptv.streams.length,
            itemBuilder: (context, index) {
              final stream = iptv.streams[index];
              return _buildStreamCard(stream);
            },
          );
  }

  Widget _buildStreamCard(dynamic stream) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LivePlayerScreen(
              streamId: stream.streamId,
              streamName: stream.name,
              icon: stream.streamIcon,
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
                  imageUrl: stream.streamIcon,
                  httpHeaders: const {'User-Agent': 'IPTVSmarters'},
                  fit: BoxFit.cover,
                  width: double.infinity,
                  memCacheWidth: 200,
                  placeholder: (context, url) =>
                      Container(color: Colors.white.withOpacity(0.05)),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.tv, size: 40, color: Colors.white24),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 8.0,
              ),
              child: Text(
                stream.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
