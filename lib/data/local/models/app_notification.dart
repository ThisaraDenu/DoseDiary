class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    this.senderUserId,
    required this.type,
    required this.priority,
    required this.title,
    required this.body,
    this.sourceId,
    this.route,
    this.isRead = false,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? senderUserId;
  final String type;
  final String priority;
  final String title;
  final String body;
  final String? sourceId;
  final String? route;
  final bool isRead;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'sender_user_id': senderUserId,
        'type': type,
        'priority': priority,
        'title': title,
        'body': body,
        'source_id': sourceId,
        'route': route,
        'is_read': isRead ? 1 : 0,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        senderUserId: map['sender_user_id'] as String?,
        type: map['type'] as String,
        priority: map['priority'] as String? ?? 'normal',
        title: map['title'] as String,
        body: map['body'] as String,
        sourceId: map['source_id'] as String?,
        route: map['route'] as String?,
        isRead: map['is_read'] == 1 || map['is_read'] == true,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      );
}
