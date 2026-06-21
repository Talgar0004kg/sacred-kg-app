import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Тип in-app уведомления (Задача 3).
enum NotificationKind {
  commentReply, // кто-то ответил на ваш комментарий
  requestApproved, // ваша заявка одобрена админом
  requestRejected, // ваша заявка отклонена админом
  adminBroadcast, // рассылка от админа (новость / сообщение)
  custom,
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.recipientEmail,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.payload = const <String, dynamic>{},
  });

  final String id;
  final String recipientEmail;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  bool isRead;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {
    'id': id,
    'recipientEmail': recipientEmail,
    'kind': kind.name,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'isRead': isRead,
    'payload': payload,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        recipientEmail: json['recipientEmail'] as String? ?? '',
        kind: NotificationKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => NotificationKind.custom,
        ),
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        isRead: json['isRead'] as bool? ?? false,
        payload: (json['payload'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      );
}

/// In-app уведомления, привязка по email пользователя.
/// Колокольчик в AppBar показывает [unreadCountFor].
class NotificationsService {
  NotificationsService._();

  static const _kKey = 'notifications_v1';
  static const _uuid = Uuid();

  static final List<void Function()> _listeners = [];
  static void addListener(void Function() cb) => _listeners.add(cb);
  static void removeListener(void Function() cb) => _listeners.remove(cb);
  static void _notify() {
    for (final cb in List<void Function()>.from(_listeners)) {
      cb();
    }
  }

  static Future<List<AppNotification>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Все уведомления конкретного email, новые сверху.
  static Future<List<AppNotification>> getFor(String email) async {
    final all = await getAll();
    final lower = email.toLowerCase();
    return all
        .where((n) => n.recipientEmail.toLowerCase() == lower)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Кол-во непрочитанных для email — для бейджа на колокольчике.
  static Future<int> unreadCountFor(String email) async {
    final list = await getFor(email);
    return list.where((n) => !n.isRead).length;
  }

  /// Создаёт уведомление произвольного типа.
  static Future<AppNotification> push({
    required String recipientEmail,
    required NotificationKind kind,
    required String title,
    required String body,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) async {
    if (recipientEmail.trim().isEmpty) {
      // Не для кого — не пишем.
      throw ArgumentError('recipientEmail is empty');
    }
    final n = AppNotification(
      id: _uuid.v4(),
      recipientEmail: recipientEmail,
      kind: kind,
      title: title,
      body: body,
      createdAt: DateTime.now(),
      payload: payload,
    );
    final all = await getAll();
    all.add(n);
    await _save(all);
    return n;
  }

  /// Безопасная версия push — не падает если recipientEmail пуст.
  static Future<void> pushSafe({
    required String? recipientEmail,
    required NotificationKind kind,
    required String title,
    required String body,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) async {
    if (recipientEmail == null || recipientEmail.trim().isEmpty) return;
    await push(
      recipientEmail: recipientEmail,
      kind: kind,
      title: title,
      body: body,
      payload: payload,
    );
  }

  static Future<void> markRead(String id) async {
    final all = await getAll();
    final idx = all.indexWhere((n) => n.id == id);
    if (idx == -1) return;
    all[idx].isRead = true;
    await _save(all);
  }

  static Future<void> markAllReadFor(String email) async {
    final all = await getAll();
    final lower = email.toLowerCase();
    var changed = false;
    for (final n in all) {
      if (n.recipientEmail.toLowerCase() == lower && !n.isRead) {
        n.isRead = true;
        changed = true;
      }
    }
    if (changed) await _save(all);
  }

  static Future<void> delete(String id) async {
    final all = await getAll();
    all.removeWhere((n) => n.id == id);
    await _save(all);
  }

  static Future<void> deleteAllFor(String email) async {
    final all = await getAll();
    all.removeWhere(
      (n) => n.recipientEmail.toLowerCase() == email.toLowerCase(),
    );
    await _save(all);
  }

  /// Массовая рассылка: одна и та же запись отправляется каждому из
  /// списка [recipients]. Дубликаты email — игнорируются.
  /// Возвращает фактическое количество получателей.
  static Future<int> broadcast({
    required Iterable<String> recipients,
    required String title,
    required String body,
    NotificationKind kind = NotificationKind.adminBroadcast,
    Map<String, dynamic> payload = const <String, dynamic>{},
  }) async {
    final unique = <String>{};
    for (final r in recipients) {
      final email = r.trim().toLowerCase();
      if (email.isNotEmpty) unique.add(email);
    }
    if (unique.isEmpty) return 0;

    final all = await getAll();
    final now = DateTime.now();
    for (final email in unique) {
      all.add(
        AppNotification(
          id: _uuid.v4(),
          recipientEmail: email,
          kind: kind,
          title: title,
          body: body,
          createdAt: now,
          payload: payload,
        ),
      );
    }
    await _save(all);
    return unique.length;
  }

  static Future<void> _save(List<AppNotification> all) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(all.map((n) => n.toJson()).toList());
    await prefs.setString(_kKey, encoded);
    _notify();
  }
}
