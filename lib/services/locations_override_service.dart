import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persisted admin overrides for the default 13 locations.
///
/// Stored as a single JSON map: `{ "<placeId>": { "title": "...", ... } }`.
/// Only the keys present in the override map win over the bundled defaults.
class LocationOverride {
  LocationOverride({
    this.title,
    this.shortDescription,
    this.fullDescription,
    this.culturalNote,
    this.visitingRules,
    this.route,
    this.imageUrl,
  });

  final String? title;
  final String? shortDescription;
  final String? fullDescription;
  final String? culturalNote;
  final String? visitingRules;
  final String? route;
  final String? imageUrl;

  bool get isEmpty =>
      (title == null || title!.isEmpty) &&
      (shortDescription == null || shortDescription!.isEmpty) &&
      (fullDescription == null || fullDescription!.isEmpty) &&
      (culturalNote == null || culturalNote!.isEmpty) &&
      (visitingRules == null || visitingRules!.isEmpty) &&
      (route == null || route!.isEmpty) &&
      (imageUrl == null || imageUrl!.isEmpty);

  Map<String, dynamic> toJson() => {
    if (title != null) 'title': title,
    if (shortDescription != null) 'shortDescription': shortDescription,
    if (fullDescription != null) 'fullDescription': fullDescription,
    if (culturalNote != null) 'culturalNote': culturalNote,
    if (visitingRules != null) 'visitingRules': visitingRules,
    if (route != null) 'route': route,
    if (imageUrl != null) 'imageUrl': imageUrl,
  };

  factory LocationOverride.fromJson(Map<String, dynamic> json) =>
      LocationOverride(
        title: json['title'] as String?,
        shortDescription: json['shortDescription'] as String?,
        fullDescription: json['fullDescription'] as String?,
        culturalNote: json['culturalNote'] as String?,
        visitingRules: json['visitingRules'] as String?,
        route: json['route'] as String?,
        imageUrl: json['imageUrl'] as String?,
      );
}

class LocationOverridesService {
  LocationOverridesService._();

  static const _kKey = 'location_overrides_v1';

  static final Map<String, LocationOverride> _cache = {};
  static bool _loaded = false;
  static final List<void Function()> _listeners = [];

  static Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = json.decode(raw) as Map<String, dynamic>;
        _cache
          ..clear()
          ..addAll(
            map.map(
              (k, v) => MapEntry(
                k,
                LocationOverride.fromJson(v as Map<String, dynamic>),
              ),
            ),
          );
      } catch (_) {
        _cache.clear();
      }
    }
    _loaded = true;
  }

  static Future<void> loadIfNeeded() => _ensureLoaded();

  static LocationOverride? overrideForSync(String id) => _cache[id];

  static Future<LocationOverride?> overrideFor(String id) async {
    await _ensureLoaded();
    return _cache[id];
  }

  static Future<void> save(String id, LocationOverride override) async {
    await _ensureLoaded();
    if (override.isEmpty) {
      _cache.remove(id);
    } else {
      _cache[id] = override;
    }
    await _persist();
    _notify();
  }

  static Future<void> clearAll() async {
    await _ensureLoaded();
    _cache.clear();
    await _persist();
    _notify();
  }

  static Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(
      _cache.map((k, v) => MapEntry(k, v.toJson())),
    );
    await prefs.setString(_kKey, encoded);
  }

  static void addListener(void Function() cb) => _listeners.add(cb);
  static void removeListener(void Function() cb) => _listeners.remove(cb);
  static void _notify() {
    for (final cb in List<void Function()>.from(_listeners)) {
      cb();
    }
  }
}
