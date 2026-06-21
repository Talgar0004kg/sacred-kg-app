import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'tours_service.dart';

/// Демо-данные, которые подсеваются при первом запуске приложения.
///
/// Спецификация (Task #6):
/// - Тестовый аккаунт турагента: agent@test.kg / agent123
/// - 3–5 готовых туров от его имени со всеми полями (название, местность,
///   описание, даты, цена, кол-во мест, фото).
class SeedData {
  SeedData._();

  static const _kSeededKey = 'demo_seeded_v1';

  static const String demoAgentEmail = 'agent@test.kg';
  static const String demoAgentPassword = 'agent123';

  /// Вызывается один раз при старте приложения из `main()`.
  /// Идемпотентно: повторные вызовы — no-op.
  static Future<void> ensureSeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kSeededKey) ?? false) return;

    await _seedAgent();
    await _seedTours();

    await prefs.setBool(_kSeededKey, true);
  }

  static Future<void> _seedAgent() async {
    final agents = await AuthService.getAgents();
    if (agents.any((a) => a.email.toLowerCase() == demoAgentEmail)) return;
    await AuthService.addAgentRaw(
      AgentCredentials(
        email: demoAgentEmail,
        password: demoAgentPassword,
        createdAt: DateTime.now(),
      ),
    );
  }

  static Future<void> _seedTours() async {
    final all = await ToursService.getAll();
    final existing = all
        .where((t) => t.agentEmail.toLowerCase() == demoAgentEmail)
        .toList();
    if (existing.isNotEmpty) return;

    final now = DateTime.now();
    DateTime in_(int days) => DateTime(now.year, now.month, now.day + days);

    final tours = <Tour>[
      Tour(
        id: 'seed-tour-issykkul',
        agentEmail: demoAgentEmail,
        title: 'Иссык-Куль за выходные',
        description:
            'Северное побережье, петроглифы Чолпон-Аты, прогулка на катере '
            'и закат над озером. Включает питание и проживание в гостевом доме.',
        locationIds: const ['cholpon_ata', 'jeti_oguz'],
        price: 12500,
        durationDays: 2,
        createdAt: now.subtract(const Duration(days: 6)),
        startDate: in_(7),
        endDate: in_(9),
        peopleCount: 8,
        photoUrls: const [
          'assets/places/cholpon_ata_1.jpg',
          'assets/places/cholpon_ata_2.jpg',
          'assets/places/jeti_oguz_1.jpg',
        ],
      ),
      Tour(
        id: 'seed-tour-arslanbob',
        agentEmail: demoAgentEmail,
        title: 'Сезон ореха в Арсланбобе',
        description:
            'Поездка в реликтовый ореховый лес, ночёвка у местной семьи (CBT), '
            'малый и большой водопад, рассказ о святом Арсланбобе.',
        locationIds: const ['arslanbob', 'jalal_abad_springs'],
        price: 18900,
        durationDays: 4,
        createdAt: now.subtract(const Duration(days: 4)),
        startDate: in_(20),
        endDate: in_(24),
        peopleCount: 10,
        photoUrls: const [
          'assets/places/arslanbob_1.jpg',
          'assets/places/arslanbob_3.jpg',
        ],
      ),
      Tour(
        id: 'seed-tour-naryn',
        agentEmail: demoAgentEmail,
        title: 'Высокий Нарын: Таш-Рабат и Сон-Куль',
        description:
            'Дорога через Тоо-Ашуу, ночёвка в юрточном лагере у Таш-Рабата, '
            'переезд к Сон-Кулю, конная прогулка, звёздное небо.',
        locationIds: const ['tash_rabat'],
        price: 24500,
        durationDays: 5,
        createdAt: now.subtract(const Duration(days: 3)),
        startDate: in_(30),
        endDate: in_(35),
        peopleCount: 6,
        photoUrls: const [
          'assets/places/tash_rabat_1.jpg',
          'assets/places/tash_rabat_2.jpg',
        ],
      ),
      Tour(
        id: 'seed-tour-osh',
        agentEmail: demoAgentEmail,
        title: 'Сулайман-Тоо и душа Оша',
        description:
            'Восхождение на священную гору на рассвете, Большой базар Джаыма, '
            'набережная Ак-Бууры, дегустация ферганской кухни.',
        locationIds: const ['sulaiman_too', 'osh_spring'],
        price: 9900,
        durationDays: 2,
        createdAt: now.subtract(const Duration(days: 2)),
        startDate: in_(14),
        endDate: in_(16),
        peopleCount: 12,
        photoUrls: const [
          'assets/places/sulaiman_too_1.jpg',
          'assets/places/sulaiman_too_2.jpg',
          'assets/places/osh_spring_1.jpg',
        ],
      ),
      Tour(
        id: 'seed-tour-chuy',
        agentEmail: demoAgentEmail,
        title: 'Чуйская долина: Бурана и Ала-Арча',
        description:
            'Однодневная программа из Бишкека: башня Бурана с балбалами '
            'и Национальный парк Ала-Арча с прогулкой к водопаду.',
        locationIds: const ['burana', 'ala_archa'],
        price: 4200,
        durationDays: 1,
        createdAt: now.subtract(const Duration(days: 1)),
        startDate: in_(3),
        endDate: in_(3),
        peopleCount: 15,
        photoUrls: const [
          'assets/places/burana_1.jpg',
          'assets/places/ala_archa_1.jpg',
        ],
      ),
    ];

    for (final t in tours) {
      await ToursService.addRaw(t);
    }
  }
}
