import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'auth_service.dart';
import 'notifications_service.dart';

/// Источник заявки — пользователь или турагент. Маршрутизация по вкладкам
/// «От пользователей» / «От турагентов» делается строго по этому полю.
enum RequestSource { user, agent }

/// Статус: ожидает решения админа / одобрено / отклонено.
enum RequestStatus { pending, approved, rejected }

/// Тип заявки.
/// - visitPlace — заявка на посещение местности (от пользователя).
/// - tourInquiry — заявка по «виду тура» (от пользователя, Задача 2).
/// - addLocation — предложение добавить новую местность (от турагента).
/// - other — любые прочие обращения турагента.
enum RequestType { visitPlace, tourInquiry, addLocation, other }

class AppRequest {
  AppRequest({
    required this.id,
    required this.source,
    required this.type,
    required this.status,
    required this.fromEmail,
    required this.createdAt,
    this.fromName,
    this.contactPhone,
    this.adminComment,
    this.decidedAt,
    this.decidedBy,
    Map<String, dynamic>? payload,
  }) : payload = payload ?? <String, dynamic>{};

  final String id;
  final RequestSource source;
  final RequestType type;
  RequestStatus status;
  final String fromEmail;
  final String? fromName;
  final String? contactPhone;
  String? adminComment;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  /// Когда админ принял решение (approve/reject). null пока заявка активная.
  DateTime? decidedAt;

  /// Email админа, принявшего решение. null если ещё в pending.
  String? decidedBy;

  /// Уже не в активных — попадает в раздел «История» админ-панели.
  bool get isHistorical => status != RequestStatus.pending;

  /// Человекочитаемая формулировка статуса для личного кабинета (Задача 1).
  String userFacingStatus() {
    switch (status) {
      case RequestStatus.pending:
        return 'Ожидание решения';
      case RequestStatus.approved:
        return 'Ваша заявка одобрена. Ожидайте, с вами свяжется оператор';
      case RequestStatus.rejected:
        final reason = adminComment;
        if (reason != null && reason.isNotEmpty) {
          return 'Заявка отклонена. Причина: $reason';
        }
        return 'Заявка отклонена';
    }
  }

  /// Краткое название для отображения в карточке заявки в админке.
  String summaryTitle() {
    switch (type) {
      case RequestType.visitPlace:
        return (payload['placeTitle'] as String?) ??
            (payload['placeId'] as String?) ??
            'Заявка на посещение';
      case RequestType.tourInquiry:
        return 'Заявка на тур: '
            '${(payload['tourTitle'] as String?) ?? '-'}';
      case RequestType.addLocation:
        return (payload['title'] as String?) ?? 'Новая местность';
      case RequestType.other:
        return (payload['subject'] as String?) ?? 'Обращение';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source.name,
    'type': type.name,
    'status': status.name,
    'fromEmail': fromEmail,
    'fromName': fromName,
    'contactPhone': contactPhone,
    'adminComment': adminComment,
    'payload': payload,
    'createdAt': createdAt.toIso8601String(),
    if (decidedAt != null) 'decidedAt': decidedAt!.toIso8601String(),
    if (decidedBy != null) 'decidedBy': decidedBy,
  };

  factory AppRequest.fromJson(Map<String, dynamic> json) => AppRequest(
    id: json['id'] as String,
    source: RequestSource.values.firstWhere(
      (e) => e.name == json['source'],
      orElse: () => RequestSource.user,
    ),
    type: RequestType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => RequestType.other,
    ),
    status: RequestStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => RequestStatus.pending,
    ),
    fromEmail: json['fromEmail'] as String? ?? '',
    fromName: json['fromName'] as String?,
    contactPhone: json['contactPhone'] as String?,
    adminComment: json['adminComment'] as String?,
    payload: (json['payload'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{},
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.now(),
    decidedAt: json['decidedAt'] is String
        ? DateTime.tryParse(json['decidedAt'] as String)
        : null,
    decidedBy: json['decidedBy'] as String?,
  );
}

class RequestsService {
  RequestsService._();

  static const _kKey = 'requests_v1';
  static const _uuid = Uuid();

  static final List<void Function()> _listeners = [];
  static void addListener(void Function() cb) => _listeners.add(cb);
  static void removeListener(void Function() cb) => _listeners.remove(cb);
  static void _notify() {
    for (final cb in List<void Function()>.from(_listeners)) {
      cb();
    }
  }

  static Future<List<AppRequest>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list
          .map((e) => AppRequest.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Возвращает только активные (pending) заявки от пользователей. Свежие — сверху.
  static Future<List<AppRequest>> getFromUsers({bool historyOnly = false}) async {
    final all = await getAll();
    final filtered = all.where((r) =>
        r.source == RequestSource.user &&
        (historyOnly ? r.isHistorical : !r.isHistorical));
    return filtered.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Возвращает только активные (pending) заявки от турагентов. Свежие — сверху.
  static Future<List<AppRequest>> getFromAgents({bool historyOnly = false}) async {
    final all = await getAll();
    final filtered = all.where((r) =>
        r.source == RequestSource.agent &&
        (historyOnly ? r.isHistorical : !r.isHistorical));
    return filtered.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Заявки конкретного пользователя/агента (для личного кабинета).
  /// Новые — сверху.
  static Future<List<AppRequest>> getForEmail(String email) async {
    final all = await getAll();
    final lower = email.toLowerCase();
    return all
        .where((r) => r.fromEmail.toLowerCase() == lower)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Создаёт заявку от пользователя на посещение местности.
  /// Телефон обязателен — он используется админом для связи.
  static Future<AppRequest> createUserVisitRequest({
    required String fromEmail,
    required String contactPhone,
    required String placeId,
    required String placeTitle,
    String? fromName,
    Map<String, dynamic>? extra,
  }) async {
    final req = AppRequest(
      id: _uuid.v4(),
      source: RequestSource.user,
      type: RequestType.visitPlace,
      status: RequestStatus.pending,
      fromEmail: fromEmail,
      fromName: fromName,
      contactPhone: contactPhone,
      createdAt: DateTime.now(),
      payload: {
        'placeId': placeId,
        'placeTitle': placeTitle,
        ...?extra,
      },
    );
    await _append(req);
    return req;
  }

  /// Создаёт заявку от турагента на добавление новой местности.
  /// Местность не появится у пользователей до approve.
  static Future<AppRequest> createAgentLocationProposal({
    required String fromEmail,
    required String title,
    required String regionId,
    required String shortDescription,
    String? imageUrl,
    String? fullDescription,
  }) async {
    final req = AppRequest(
      id: _uuid.v4(),
      source: RequestSource.agent,
      type: RequestType.addLocation,
      status: RequestStatus.pending,
      fromEmail: fromEmail,
      createdAt: DateTime.now(),
      payload: {
        'title': title,
        'regionId': regionId,
        'shortDescription': shortDescription,
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        if (fullDescription != null && fullDescription.isNotEmpty)
          'fullDescription': fullDescription,
      },
    );
    await _append(req);
    return req;
  }

  /// Заявка пользователя на конкретный тур турагента.
  /// Падает в общий поток админских заявок, в раздел «От пользователей».
  static Future<AppRequest> createUserTourBooking({
    required String fromEmail,
    required String fromName,
    required String contactPhone,
    required String tourId,
    required String tourTitle,
    required String agentEmail,
    required int peopleCount,
    String? note,
  }) async {
    final req = AppRequest(
      id: _uuid.v4(),
      source: RequestSource.user,
      type: RequestType.tourInquiry,
      status: RequestStatus.pending,
      fromEmail: fromEmail,
      fromName: fromName,
      contactPhone: contactPhone,
      createdAt: DateTime.now(),
      payload: {
        'tourId': tourId,
        'tourTitle': tourTitle,
        'agentEmail': agentEmail,
        'peopleCount': peopleCount,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    await _append(req);
    return req;
  }

  /// Произвольная заявка от турагента (контакт с админом, и т. п.).
  static Future<AppRequest> createAgentOtherRequest({
    required String fromEmail,
    required String subject,
    String? body,
  }) async {
    final req = AppRequest(
      id: _uuid.v4(),
      source: RequestSource.agent,
      type: RequestType.other,
      status: RequestStatus.pending,
      fromEmail: fromEmail,
      createdAt: DateTime.now(),
      payload: {
        'subject': subject,
        if (body != null) 'body': body,
      },
    );
    await _append(req);
    return req;
  }

  static Future<void> setStatus(
    String id,
    RequestStatus status, {
    String? comment,
    String? adminEmail,
  }) async {
    final all = await getAll();
    final idx = all.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    final req = all[idx];
    req.status = status;
    if (comment != null) req.adminComment = comment;
    if (status == RequestStatus.pending) {
      req.decidedAt = null;
      req.decidedBy = null;
    } else {
      req.decidedAt = DateTime.now();
      req.decidedBy = adminEmail;
    }
    await _saveAll(all);

    // Уведомление автору заявки о решении админа (Задача 3 ↔ Задача 1).
    if (status == RequestStatus.approved) {
      await NotificationsService.pushSafe(
        recipientEmail: req.fromEmail,
        kind: NotificationKind.requestApproved,
        title: 'Заявка одобрена',
        body: '${req.summaryTitle()}: ${req.userFacingStatus()}',
        payload: {'requestId': req.id},
      );
    } else if (status == RequestStatus.rejected) {
      await NotificationsService.pushSafe(
        recipientEmail: req.fromEmail,
        kind: NotificationKind.requestRejected,
        title: 'Заявка отклонена',
        body: req.userFacingStatus(),
        payload: {'requestId': req.id},
      );
    }
  }

  /// Возвращает заявку из истории обратно в активные (Задача 1).
  static Future<void> revert(String id) async {
    await setStatus(id, RequestStatus.pending);
  }

  static Future<void> delete(String id) async {
    final all = await getAll();
    all.removeWhere((r) => r.id == id);
    await _saveAll(all);
  }

  /// Переименовывает `fromName` во всех заявках указанного автора.
  /// Возвращает число обновлённых записей.
  static Future<int> renameAuthor(String email, String newName) async {
    final all = await getAll();
    final lower = email.trim().toLowerCase();
    final trimmed = newName.trim();
    var changed = 0;
    for (var i = 0; i < all.length; i++) {
      final r = all[i];
      if (r.fromEmail.toLowerCase() != lower) continue;
      if (r.fromName == trimmed) continue;
      all[i] = AppRequest(
        id: r.id,
        source: r.source,
        type: r.type,
        status: r.status,
        fromEmail: r.fromEmail,
        fromName: trimmed.isEmpty ? null : trimmed,
        contactPhone: r.contactPhone,
        adminComment: r.adminComment,
        createdAt: r.createdAt,
        payload: r.payload,
      )
        ..decidedAt = r.decidedAt
        ..decidedBy = r.decidedBy;
      changed++;
    }
    if (changed > 0) await _saveAll(all);
    return changed;
  }

  /// Удаляет все заявки, связанные с этим email (как отправитель).
  static Future<int> deleteByEmail(String email) async {
    final all = await getAll();
    final lower = email.trim().toLowerCase();
    final before = all.length;
    all.removeWhere((r) => r.fromEmail.toLowerCase() == lower);
    final removed = before - all.length;
    if (removed > 0) await _saveAll(all);
    return removed;
  }

  static Future<void> _append(AppRequest req) async {
    // Если автор заявки заблокирован — не сохраняем и сообщаем UI-слою.
    final reason = await AuthService.getBlockReason(req.fromEmail);
    if (reason != null) {
      throw StateError(
        reason.isEmpty
            ? 'Вы заблокированы администратором.'
            : 'Вы заблокированы. Причина: $reason',
      );
    }
    final all = await getAll();
    all.add(req);
    await _saveAll(all);
  }

  static Future<void> _saveAll(List<AppRequest> all) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(all.map((r) => r.toJson()).toList());
    await prefs.setString(_kKey, encoded);
    _notify();
  }
}
