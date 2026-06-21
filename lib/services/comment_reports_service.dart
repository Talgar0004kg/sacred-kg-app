import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

enum ReportStatus { open, resolved }

class CommentReport {
  CommentReport({
    required this.id,
    required this.commentId,
    required this.fromEmail,
    required this.reason,
    required this.createdAt,
    this.status = ReportStatus.open,
    this.resolvedAt,
    this.resolvedBy,
  });

  final String id;
  final String commentId;
  final String fromEmail;
  String reason;
  final DateTime createdAt;
  ReportStatus status;
  DateTime? resolvedAt;
  String? resolvedBy;

  Map<String, dynamic> toJson() => {
    'id': id,
    'commentId': commentId,
    'fromEmail': fromEmail,
    'reason': reason,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    if (resolvedAt != null) 'resolvedAt': resolvedAt!.toIso8601String(),
    if (resolvedBy != null) 'resolvedBy': resolvedBy,
  };

  factory CommentReport.fromJson(Map<String, dynamic> json) => CommentReport(
    id: json['id'] as String,
    commentId: json['commentId'] as String? ?? '',
    fromEmail: json['fromEmail'] as String? ?? '',
    reason: json['reason'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.now(),
    status: ReportStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => ReportStatus.open,
    ),
    resolvedAt: json['resolvedAt'] is String
        ? DateTime.tryParse(json['resolvedAt'] as String)
        : null,
    resolvedBy: json['resolvedBy'] as String?,
  );
}

class CommentReportsService {
  CommentReportsService._();

  static const _kKey = 'comment_reports_v1';
  static const _uuid = Uuid();

  static final List<void Function()> _listeners = [];
  static void addListener(void Function() cb) => _listeners.add(cb);
  static void removeListener(void Function() cb) => _listeners.remove(cb);
  static void _notify() {
    for (final cb in List<void Function()>.from(_listeners)) {
      cb();
    }
  }

  static Future<List<CommentReport>> getAll({bool openOnly = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = json.decode(raw) as List<dynamic>;
      final all = list
          .map((e) => CommentReport.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return openOnly
          ? all.where((r) => r.status == ReportStatus.open).toList()
          : all;
    } catch (_) {
      return [];
    }
  }

  static Future<int> openCount() async {
    final list = await getAll(openOnly: true);
    return list.length;
  }

  static Future<CommentReport> create({
    required String commentId,
    required String fromEmail,
    required String reason,
  }) async {
    final r = CommentReport(
      id: _uuid.v4(),
      commentId: commentId,
      fromEmail: fromEmail,
      reason: reason,
      createdAt: DateTime.now(),
    );
    final all = await getAll();
    all.add(r);
    await _save(all);
    return r;
  }

  static Future<void> resolve(String id, {String? byEmail}) async {
    final all = await getAll();
    final idx = all.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    all[idx].status = ReportStatus.resolved;
    all[idx].resolvedAt = DateTime.now();
    all[idx].resolvedBy = byEmail;
    await _save(all);
  }

  /// Удаляет все жалобы на конкретный комментарий (когда комментарий удалён).
  static Future<void> deleteByComment(String commentId) async {
    final all = await getAll();
    all.removeWhere((r) => r.commentId == commentId);
    await _save(all);
  }

  static Future<void> delete(String id) async {
    final all = await getAll();
    all.removeWhere((r) => r.id == id);
    await _save(all);
  }

  /// Удаляет все жалобы, оставленные конкретным пользователем.
  static Future<int> deleteByAuthor(String email) async {
    final all = await getAll();
    final lower = email.trim().toLowerCase();
    final before = all.length;
    all.removeWhere((r) => r.fromEmail.toLowerCase() == lower);
    final removed = before - all.length;
    if (removed > 0) await _save(all);
    return removed;
  }

  static Future<void> _save(List<CommentReport> all) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(all.map((r) => r.toJson()).toList());
    await prefs.setString(_kKey, encoded);
    _notify();
  }
}
