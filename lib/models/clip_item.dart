class ClipItem {
  final String id;
  String title;
  String content;
  DateTime createdAt;
  DateTime? updatedAt;
  bool isStarred;
  bool isDeleted;
  bool isAuto;
  DateTime? deletedAt;
  bool isImage;
  String? imagePath;
  String? customTitle;
  String? imageBase64;
  String? labelColor; // Hex string e.g. '#EF4444' or null

  ClipItem({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.isStarred = false,
    this.isDeleted = false,
    this.isAuto = false,
    this.deletedAt,
    this.isImage = false,
    this.imagePath,
    this.customTitle,
    this.imageBase64,
    this.labelColor,
  });

  bool matchesSearch(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase().trim();
    return title.toLowerCase().contains(q) || content.toLowerCase().contains(q);
  }

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      final mins = diff.inMinutes;
      return mins == 1 ? '1 min ago' : '$mins mins ago';
    } else if (diff.inHours < 24) {
      final hrs = diff.inHours;
      return hrs == 1 ? '1 hr ago' : '$hrs hrs ago';
    } else if (diff.inDays <= 3) {
      final days = diff.inDays;
      return days == 1 ? '1 day ago' : '$days days ago';
    } else {
      // Date and time format: e.g. Aug 21, 2026 • 5:30 PM
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final month = months[createdAt.month - 1];
      final day = createdAt.day;
      final year = createdAt.year;
      final hourRaw = createdAt.hour;
      final hour = hourRaw == 0 ? 12 : (hourRaw > 12 ? hourRaw - 12 : hourRaw);
      final period = hourRaw >= 12 ? 'PM' : 'AM';
      final minute = createdAt.minute.toString().padLeft(2, '0');
      return '$month $day, $year • $hour:$minute $period';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isStarred': isStarred,
      'isDeleted': isDeleted,
      'isAuto': isAuto,
      'deletedAt': deletedAt?.toIso8601String(),
      'isImage': isImage,
      'imagePath': imagePath,
      'customTitle': customTitle,
      if (imageBase64 != null) 'imageBase64': imageBase64,
      if (labelColor != null) 'labelColor': labelColor,
    };
  }

  factory ClipItem.fromJson(Map<String, dynamic> json) {
    return ClipItem(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      isStarred: json['isStarred'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
      isAuto: json['isAuto'] as bool? ?? false,
      deletedAt: json['deletedAt'] != null
          ? DateTime.tryParse(json['deletedAt'] as String)
          : null,
      isImage: json['isImage'] as bool? ?? false,
      imagePath: json['imagePath'] as String?,
      customTitle: json['customTitle'] as String?,
      imageBase64: json['imageBase64'] as String?,
      labelColor: json['labelColor'] as String?,
    );
  }
}
