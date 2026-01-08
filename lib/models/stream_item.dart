enum ContentType { live, movie, series }

class StreamItem {
  final int num;
  final String name;
  final String streamId;
  final String streamIcon;
  final String categoryId;
  final String containerExtension;
  final ContentType contentType;

  StreamItem({
    required this.num,
    required this.name,
    required this.streamId,
    required this.streamIcon,
    required this.categoryId,
    this.containerExtension = 'mp4',
    this.contentType = ContentType.live,
  });

  factory StreamItem.fromJson(
    Map<String, dynamic> json, {
    ContentType type = ContentType.live,
  }) {
    return StreamItem(
      num: json['num'] ?? 0,
      name: json['name'] ?? '',
      streamId: (json['stream_id'] ?? json['series_id'] ?? '').toString(),
      streamIcon:
          json['stream_icon'] ?? json['cover'] ?? json['movie_image'] ?? '',
      categoryId: (json['category_id'] ?? '').toString(),
      containerExtension: json['container_extension'] ?? 'mp4',
      contentType: type,
    );
  }
}
