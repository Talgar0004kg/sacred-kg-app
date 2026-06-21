import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Местности, добавленные турагентами и одобренные админом.
///
/// Это отдельный от дефолтных 13 список. Хранится в SharedPreferences.
/// Создаётся через [add] в момент, когда админ одобряет заявку турагента
/// в разделе «Запросы → От турагентов» (см. [RequestsService]).
/// Админ может потом удалить любую такую местность через вкладку «Локации».
class CustomLocation {
  CustomLocation({
    required this.id,
    required this.title,
    required this.regionId,
    required this.shortDescription,
    required this.createdAt,
    required this.addedByEmail,
    this.fullDescription = '',
    this.imageUrl = '',
  });

  final String id;
  String title;
  String regionId;
  String shortDescription;
  String fullDescription;
  String imageUrl;
  final DateTime createdAt;
  final String addedByEmail;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'regionId': regionId,
    'shortDescription': shortDescription,
    'fullDescription': fullDescription,
    'imageUrl': imageUrl,
    'createdAt': createdAt.toIso8601String(),
    'addedByEmail': addedByEmail,
  };

  factory CustomLocation.fromJson(Map<String, dynamic> json) => CustomLocation(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    regionId: json['regionId'] as String? ?? '',
    shortDescription: json['shortDescription'] as String? ?? '',
    fullDescription: json['fullDescription'] as String? ?? '',
    imageUrl: json['imageUrl'] as String? ?? '',
    addedByEmail: json['addedByEmail'] as String? ?? '',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.now(),
  );
}

class CustomLocationsService {
  CustomLocationsService._();

  static const _kKey = 'custom_locations_v1';

  static final List<void Function()> _listeners = [];
  static void addListener(void Function() cb) => _listeners.add(cb);
  static void removeListener(void Function() cb) => _listeners.remove(cb);
  static void _notify() {
    for (final cb in List<void Function()>.from(_listeners)) {
      cb();
    }
  }

  static Future<List<CustomLocation>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = json.decode(raw) as List<dynamic>;
      return list
          .map((e) => CustomLocation.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(CustomLocation location) async {
    final all = await getAll();
    all.add(location);
    await _save(all);
  }

  static Future<void> update(CustomLocation location) async {
    final all = await getAll();
    final idx = all.indexWhere((l) => l.id == location.id);
    if (idx == -1) return;
    all[idx] = location;
    await _save(all);
  }

  static Future<void> delete(String id) async {
    final all = await getAll();
    all.removeWhere((l) => l.id == id);
    await _save(all);
  }

  static Future<void> _save(List<CustomLocation> all) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(all.map((l) => l.toJson()).toList());
    await prefs.setString(_kKey, encoded);
    _notify();
  }
}
