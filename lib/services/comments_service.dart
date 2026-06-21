import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'auth_service.dart';
import 'notifications_service.dart';

/// Тип сущности, к которой привязан комментарий.
/// - place: сакральная местность (PlaceDetail).
/// - tour: индивидуальный тур от турагента.
/// - post: пост в Юрте сообщества (Community feed).
enum CommentTarget { place, tour, post }

class Comment {
  Comment({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.authorEmail,
    required this.authorName,
    required this.text,
    required this.createdAt,
    this.parentId,
    this.editedAt,
  });

  final String id;
  final CommentTarget targetType;
  final String targetId;

  /// Если задан — это ответ на комментарий с этим id.
  /// Уровень вложенности — один: ответы на ответы тоже хранят parentId
  /// корневого комментария.
  final String? parentId;

  final String authorEmail;
  String authorName;
  String text;
  final DateTime createdAt;
  DateTime? editedAt;

  bool get isReply => parentId != null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'targetType': targetType.name,
    'targetId': targetId,
    'parentId': parentId,
    'authorEmail': authorEmail,
    'authorName': authorName,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    if (editedAt != null) 'editedAt': editedAt!.toIso8601String(),
  };

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    id: json['id'] as String,
    targetType: CommentTarget.values.firstWhere(
      (t) => t.name == json['targetType'],
      orElse: () => CommentTarget.place,
    ),
    targetId: json['targetId'] as String? ?? '',
    parentId: json['parentId'] as String?,
    authorEmail: json['authorEmail'] as String? ?? '',
    authorName: json['authorName'] as String? ?? 'Гость',
    text: json['text'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.now(),
    editedAt: json['editedAt'] is String
        ? DateTime.tryParse(json['editedAt'] as String)
        : null,
  );
}

/// Комментарии с возможностью ответа (Задача 3).
/// Троттлинг — не чаще 1 коммента за 30 секунд на устройство.
class CommentsService {
  CommentsService._();

  static const _kKey = 'comments_v1';
  static const _kLastPostKey = 'last_comment_ts';
  static const _throttleSeconds = 30;
  static const _uuid = Uuid();

  static final List<void Function()> _listeners = [];
  static void addListener(void Function() cb) => _listeners.add(cb);
  static void removeListener(void Function() cb) => _listeners.remove(cb);
  static void _notify() {
    for (final cb in List<void Function()>.from(_listeners)) {
      cb();
    }
  }

  static Future<List<Comment>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list
          .map((e) => Comment.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Все комментарии для конкретной сущности (target). Старые сверху для
  /// корневых, ответы внутри корня тоже старые-сверху.
  static Future<List<Comment>> getForTarget(
    CommentTarget type,
    String id,
  ) async {
    final all = await getAll();
    return all
        .where((c) => c.targetType == type && c.targetId == id)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Сколько секунд ещё ждать до следующей публикации (0 — можно).
  static Future<int> throttleRemainingSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_kLastPostKey);
    if (lastMs == null) return 0;
    final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
    final diff = DateTime.now().difference(last).inSeconds;
    final left = _throttleSeconds - diff;
    return left > 0 ? left : 0;
  }

  static Future<void> _markPosted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _kLastPostKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Создаёт корневой комментарий или ответ. При ответе автору родительского
  /// комментария создаётся уведомление (если это не тот же пользователь).
  static Future<Comment> post({
    required CommentTarget type,
    required String targetId,
    required String authorEmail,
    required String authorName,
    required String text,
    String? parentId,
  }) async {
    final blockReason = await AuthService.getBlockReason(authorEmail);
    if (blockReason != null) {
      throw StateError(
        blockReason.isEmpty
            ? 'Вы заблокированы администратором.'
            : 'Вы заблокированы. Причина: $blockReason',
      );
    }
    final left = await throttleRemainingSeconds();
    if (left > 0) {
      throw StateError(
        'Подождите $left сек перед следующим комментарием.',
      );
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Текст комментария пуст');
    }
    final c = Comment(
      id: _uuid.v4(),
      targetType: type,
      targetId: targetId,
      authorEmail: authorEmail,
      authorName: authorName.isEmpty ? 'Гость' : authorName,
      text: trimmed,
      createdAt: DateTime.now(),
      parentId: parentId,
    );
    final all = await getAll();
    all.add(c);
    await _save(all);
    await _markPosted();

    // Уведомление автору родительского комментария (если это ответ).
    if (parentId != null) {
      final parent = all.firstWhere(
        (x) => x.id == parentId,
        orElse: () => c, // если не нашли — не упадём
      );
      if (parent.id != c.id &&
          parent.authorEmail.toLowerCase() != authorEmail.toLowerCase()) {
        await NotificationsService.pushSafe(
          recipientEmail: parent.authorEmail,
          kind: NotificationKind.commentReply,
          title: 'Ответ на ваш комментарий',
          body: '${c.authorName}: ${_short(c.text)}',
          payload: {
            'commentId': c.id,
            'parentId': parent.id,
            'targetType': type.name,
            'targetId': targetId,
          },
        );
      }
    }
    return c;
  }

  /// Редактирование — только автор. На уровне сервиса валидируем email.
  static Future<void> edit({
    required String commentId,
    required String byEmail,
    required String newText,
  }) async {
    final all = await getAll();
    final idx = all.indexWhere((c) => c.id == commentId);
    if (idx == -1) return;
    final c = all[idx];
    if (c.authorEmail.toLowerCase() != byEmail.toLowerCase()) {
      throw StateError('Редактировать может только автор');
    }
    final trimmed = newText.trim();
    if (trimmed.isEmpty) throw ArgumentError('Текст пуст');
    c.text = trimmed;
    c.editedAt = DateTime.now();
    await _save(all);
  }

  /// Удаляет комментарий. Если [asAdmin] = true — без проверки автора.
  /// При удалении корневого — удаляются и его ответы.
  static Future<void> delete({
    required String commentId,
    required String byEmail,
    bool asAdmin = false,
  }) async {
    final all = await getAll();
    final idx = all.indexWhere((c) => c.id == commentId);
    if (idx == -1) return;
    final c = all[idx];
    if (!asAdmin &&
        c.authorEmail.toLowerCase() != byEmail.toLowerCase()) {
      throw StateError('Удалить может только автор или админ');
    }
    all.removeWhere(
      (x) => x.id == commentId || (x.parentId == commentId),
    );
    await _save(all);
  }

  /// Переименовывает `authorName` во всех комментариях этого автора.
  /// Возвращает число обновлённых записей.
  static Future<int> renameAuthor(String email, String newName) async {
    final all = await getAll();
    final lower = email.trim().toLowerCase();
    final trimmed = newName.trim();
    var changed = 0;
    for (final c in all) {
      if (c.authorEmail.toLowerCase() != lower) continue;
      if (c.authorName == trimmed) continue;
      c.authorName = trimmed.isEmpty ? 'Гость' : trimmed;
      changed++;
    }
    if (changed > 0) await _save(all);
    return changed;
  }

  /// Удаляет все комментарии конкретного автора (по email).
  /// Возвращает число удалённых записей.
  static Future<int> deleteByAuthor(String email) async {
    final all = await getAll();
    final lower = email.trim().toLowerCase();
    final before = all.length;
    all.removeWhere((c) => c.authorEmail.toLowerCase() == lower);
    final removed = before - all.length;
    if (removed > 0) await _save(all);
    return removed;
  }

  static String _short(String text) {
    if (text.length <= 80) return text;
    return '${text.substring(0, 77)}…';
  }

  static Future<void> _save(List<Comment> all) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(all.map((c) => c.toJson()).toList());
    await prefs.setString(_kKey, encoded);
    _notify();
  }
}
