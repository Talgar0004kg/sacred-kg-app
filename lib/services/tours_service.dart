import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class Tour {
  Tour({
    required this.id,
    required this.agentEmail,
    required this.title,
    required this.description,
    required this.locationIds,
    required this.price,
    required this.durationDays,
    required this.createdAt,
    this.startDate,
    this.endDate,
    this.peopleCount = 0,
    this.photoUrls = const <String>[],
    this.currency = 'сом',
    this.program = '',
    this.conditions = '',
  });

  final String id;
  final String agentEmail;
  final String title;
  final String description;
  final List<String> locationIds;
  final double price;
  final int durationDays;
  final DateTime createdAt;

  /// Поля редактора тура (Task #5). Опциональны для совместимости с
  /// существующими демо-турами без дат.
  final DateTime? startDate;
  final DateTime? endDate;
  final int peopleCount;
  final List<String> photoUrls;
  final String currency;

  /// Программа тура по дням (опционально).
  final String program;

  /// Условия участия: что включено, требования, ограничения (опционально).
  final String conditions;

  Tour copyWith({
    String? title,
    String? description,
    List<String>? locationIds,
    double? price,
    int? durationDays,
    DateTime? startDate,
    DateTime? endDate,
    int? peopleCount,
    List<String>? photoUrls,
    String? currency,
    String? program,
    String? conditions,
  }) {
    return Tour(
      id: id,
      agentEmail: agentEmail,
      title: title ?? this.title,
      description: description ?? this.description,
      locationIds: locationIds ?? this.locationIds,
      price: price ?? this.price,
      durationDays: durationDays ?? this.durationDays,
      createdAt: createdAt,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      peopleCount: peopleCount ?? this.peopleCount,
      photoUrls: photoUrls ?? this.photoUrls,
      currency: currency ?? this.currency,
      program: program ?? this.program,
      conditions: conditions ?? this.conditions,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'agentEmail': agentEmail,
    'title': title,
    'description': description,
    'locationIds': locationIds,
    'price': price,
    'durationDays': durationDays,
    'createdAt': createdAt.toIso8601String(),
    if (startDate != null) 'startDate': startDate!.toIso8601String(),
    if (endDate != null) 'endDate': endDate!.toIso8601String(),
    'peopleCount': peopleCount,
    'photoUrls': photoUrls,
    'currency': currency,
    'program': program,
    'conditions': conditions,
  };

  factory Tour.fromJson(Map<String, dynamic> json) => Tour(
    id: json['id'] as String,
    agentEmail: json['agentEmail'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    locationIds: (json['locationIds'] as List<dynamic>)
        .map((e) => e as String)
        .toList(),
    price: (json['price'] as num).toDouble(),
    durationDays: (json['durationDays'] as num).toInt(),
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.now(),
    startDate: json['startDate'] is String
        ? DateTime.tryParse(json['startDate'] as String)
        : null,
    endDate: json['endDate'] is String
        ? DateTime.tryParse(json['endDate'] as String)
        : null,
    peopleCount: (json['peopleCount'] as num?)?.toInt() ?? 0,
    photoUrls: (json['photoUrls'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        const <String>[],
    currency: json['currency'] as String? ?? 'сом',
    program: json['program'] as String? ?? '',
    conditions: json['conditions'] as String? ?? '',
  );
}

class ToursService {
  ToursService._();

  static const _kKey = 'tours_v1';
  static const _uuid = Uuid();

  static final List<void Function()> _listeners = [];
  static void addListener(void Function() cb) => _listeners.add(cb);
  static void removeListener(void Function() cb) => _listeners.remove(cb);
  static void _notify() {
    for (final cb in List<void Function()>.from(_listeners)) {
      cb();
    }
  }

  static Future<List<Tour>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list
          .map((e) => Tour.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Tour>> getForAgent(String email) async {
    final all = await getAll();
    return all
        .where((t) => t.agentEmail.toLowerCase() == email.toLowerCase())
        .toList();
  }

  static Future<Tour> create({
    required String agentEmail,
    required String title,
    required String description,
    required List<String> locationIds,
    required double price,
    required int durationDays,
    DateTime? startDate,
    DateTime? endDate,
    int peopleCount = 0,
    List<String> photoUrls = const <String>[],
    String currency = 'сом',
    String program = '',
    String conditions = '',
  }) async {
    final all = await getAll();
    final tour = Tour(
      id: _uuid.v4(),
      agentEmail: agentEmail,
      title: title,
      description: description,
      locationIds: locationIds,
      price: price,
      durationDays: durationDays,
      createdAt: DateTime.now(),
      startDate: startDate,
      endDate: endDate,
      peopleCount: peopleCount,
      photoUrls: photoUrls,
      currency: currency,
      program: program,
      conditions: conditions,
    );
    all.add(tour);
    await _save(all);
    return tour;
  }

  /// Поиск тура по id.
  static Future<Tour?> getById(String id) async {
    final all = await getAll();
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  static Future<void> addRaw(Tour tour) async {
    final all = await getAll();
    if (all.any((t) => t.id == tour.id)) return;
    all.add(tour);
    await _save(all);
  }

  static Future<void> update(Tour tour) async {
    final all = await getAll();
    final idx = all.indexWhere((t) => t.id == tour.id);
    if (idx == -1) return;
    all[idx] = tour;
    await _save(all);
  }

  static Future<void> delete(String id) async {
    final all = await getAll();
    all.removeWhere((t) => t.id == id);
    await _save(all);
  }

  static Future<void> deleteAllForAgent(String email) async {
    final all = await getAll();
    all.removeWhere(
      (t) => t.agentEmail.toLowerCase() == email.toLowerCase(),
    );
    await _save(all);
  }

  static Future<void> _save(List<Tour> tours) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(tours.map((t) => t.toJson()).toList());
    await prefs.setString(_kKey, encoded);
    _notify();
  }
}
