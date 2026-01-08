import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/iptv_provider.dart';
import '../widgets/embedded_player.dart';
import '../models/stream_item.dart';

class LivePlayerScreen extends StatefulWidget {
  final String streamId;
  final String streamName;
  final String? icon;

  const LivePlayerScreen({
    super.key,
    required this.streamId,
    required this.streamName,
    this.icon,
  });

  @override
  State<LivePlayerScreen> createState() => _LivePlayerScreenState();
}

class _LivePlayerScreenState extends State<LivePlayerScreen> {
  @override
  Widget build(BuildContext context) {
    final iptv = Provider.of<IptvProvider>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Embedded Player at Top
          SafeArea(
            bottom: false,
            child: EmbeddedPlayer(
              streamId: widget.streamId,
              streamName: widget.streamName,
              isMovie: false,
              isSeries: false,
            ),
          ),

          // Channel Info & Related Channels Below
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
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
                        FutureBuilder<bool>(
                          future: iptv.isFavorite(widget.streamId),
                          builder: (context, snapshot) {
                            final isFav = snapshot.data ?? false;
                            return IconButton(
                              icon: Icon(
                                isFav ? Icons.favorite : Icons.favorite_border,
                                color: isFav ? Colors.red : Colors.white,
                              ),
                              onPressed: () {
                                iptv.toggleFavorite(
                                  StreamItem(
                                    num: 0,
                                    name: widget.streamName,
                                    streamId: widget.streamId,
                                    streamIcon: widget.icon ?? '',
                                    categoryId: '',
                                    contentType: ContentType.live,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 10),
                    const Text(
                      'القنوات المماثلة',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // List of channels from current category
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: (iptv.streams.length > 10
                          ? 10
                          : iptv.streams.length),
                      itemBuilder: (context, index) {
                        final stream = iptv.streams[index];
                        if (stream.streamId == widget.streamId)
                          return const SizedBox.shrink();
                        return ListTile(
                          leading: SizedBox(
                            width: 50,
                            child: stream.streamIcon.isNotEmpty
                                ? Image.network(
                                    stream.streamIcon,
                                    errorBuilder: (c, e, s) => const Icon(
                                      Icons.tv,
                                      color: Colors.white24,
                                    ),
                                  )
                                : const Icon(Icons.tv, color: Colors.white24),
                          ),
                          title: Text(
                            stream.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          onTap: () {
                            Navigator.pushReplacement(
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
                        );
                      },
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
}
