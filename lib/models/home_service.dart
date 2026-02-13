class HomeService {

  HomeService({
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.thumbUrl,
    this.serviceKeyword,
    required this.orderIndex,
  });

  factory HomeService.fromMap(Map<String, dynamic> map) {
    return HomeService(
      id: map['id'],
      title: map['title'],
      subtitle: map['subtitle'],
      imageUrl: map['image_url'],
      thumbUrl: map['thumb_url'],
      serviceKeyword: map['service_slug'],
      orderIndex: map['order_index'] ?? 999,
    );
  }
  final String id;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? thumbUrl;
  final String? serviceKeyword;
  final int orderIndex;
}
