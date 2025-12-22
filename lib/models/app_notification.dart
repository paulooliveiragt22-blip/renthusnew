import 'package:flutter/foundation.dart';

/// Modelo único de notificação usada no app (cliente e prestador)
class AppNotification {
  final String id;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final String channel; // ex: 'app'
  final bool read;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.data,
    required this.channel,
    required this.read,
    required this.createdAt,
  });

  /// Constrói a partir de um map vindo do Supabase (tabela `notifications`)
  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id']?.toString() ?? '',
      title: (map['title'] ?? 'Notificação').toString(),
      body: (map['body'] ?? '').toString(),
      data: map['data'] is Map<String, dynamic>
          ? map['data'] as Map<String, dynamic>
          : map['data'] is Map
              ? Map<String, dynamic>.from(map['data'] as Map)
              : <String, dynamic>{},
      channel: (map['channel'] ?? '').toString(),
      read: (map['read'] as bool?) ?? false,
      createdAt: _parseDate(map['created_at']),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    if (value is DateTime) return value.toLocal();
    try {
      return DateTime.parse(value.toString()).toLocal();
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'data': data,
      'channel': channel,
      'read': read,
      'created_at': createdAt.toIso8601String(),
    };
  }

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    String? channel,
    bool? read,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      channel: channel ?? this.channel,
      read: read ?? this.read,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'AppNotification(id: $id, title: $title, read: $read, channel: $channel, createdAt: $createdAt, data: $data)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppNotification &&
        other.id == id &&
        other.title == title &&
        other.body == body &&
        mapEquals(other.data, data) &&
        other.channel == channel &&
        other.read == read &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        body.hashCode ^
        data.hashCode ^
        channel.hashCode ^
        read.hashCode ^
        createdAt.hashCode;
  }
}
