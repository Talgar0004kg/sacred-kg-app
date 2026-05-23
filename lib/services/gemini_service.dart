import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kGeminiApiKeyPref = 'gemini_api_key';
const String kGeminiModel = 'gemini-2.5-flash';

class GuideProfile {
  GuideProfile({
    required this.id,
    required this.name,
    required this.systemPrompt,
    required this.greeting,
  });

  final String id;
  final String name;
  final String systemPrompt;
  final String greeting;
}

class GeminiKnowledgeBase {
  GeminiKnowledgeBase({
    required this.guides,
    required this.locationsBlock,
  });

  final Map<String, GuideProfile> guides;

  /// A pre-built textual block describing all locations, ready to inject into
  /// the system prompt.
  final String locationsBlock;
}

/// Stateful chat handle. Provides a single [send] entry point that the UI can
/// call as the user types messages.
class GuideChatSession {
  GuideChatSession._({
    required this.guide,
    required ChatSession session,
  }) : _session = session;

  final GuideProfile guide;
  final ChatSession _session;

  Future<String> send(String userMessage) async {
    try {
      final response = await _session.sendMessage(Content.text(userMessage));
      final text = response.text;
      if (text == null || text.trim().isEmpty) {
        return 'Гид не смог сформировать ответ. Попробуйте переформулировать.';
      }
      return text.trim();
    } on GenerativeAIException catch (e) {
      return 'Гид временно недоступен: ${e.message}';
    } catch (_) {
      return 'Гид временно недоступен, обратитесь к администратору.';
    }
  }
}

class GeminiService {
  GeminiService._();

  static GeminiKnowledgeBase? _kb;

  /// Read the API key from SharedPreferences. Returns null/empty if not set.
  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(kGeminiApiKeyPref);
    if (key == null || key.trim().isEmpty) return null;
    return key.trim();
  }

  static Future<void> setApiKey(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kGeminiApiKeyPref, value.trim());
  }

  static Future<bool> hasApiKey() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }

  static Future<GeminiKnowledgeBase> loadKnowledgeBase() async {
    if (_kb != null) return _kb!;
    final raw = await rootBundle.loadString('assets/ai_knowledge_base.json');
    final decoded = json.decode(raw) as Map<String, dynamic>;

    final guidesJson = decoded['guides'] as Map<String, dynamic>;
    final guides = <String, GuideProfile>{};
    guidesJson.forEach((id, value) {
      final v = value as Map<String, dynamic>;
      guides[id] = GuideProfile(
        id: id,
        name: v['name'] as String,
        systemPrompt: v['system_prompt'] as String,
        greeting: v['greeting'] as String,
      );
    });

    final locations = (decoded['locations'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final buffer = StringBuffer();
    buffer.writeln('\n\nСПРАВОЧНИК САКРАЛЬНЫХ МЕСТ КЫРГЫЗСТАНА:');
    for (final loc in locations) {
      buffer.writeln('---');
      buffer.writeln('ID: ${loc['id']}');
      buffer.writeln('Название: ${loc['name']}');
      if (loc['region'] != null) buffer.writeln('Регион: ${loc['region']}');
      buffer.writeln('Кратко: ${loc['short_description']}');
      buffer.writeln('Подробно: ${loc['full_description']}');
    }
    _kb = GeminiKnowledgeBase(
      guides: guides,
      locationsBlock: buffer.toString(),
    );
    return _kb!;
  }

  /// Start a fresh chat session with the given guide.
  ///
  /// Returns null when the API key is missing or the SDK fails to initialize.
  static Future<GuideChatSession?> startChat(String guideId) async {
    final apiKey = await getApiKey();
    if (apiKey == null) return null;

    final kb = await loadKnowledgeBase();
    final guide = kb.guides[guideId];
    if (guide == null) return null;

    final systemPrompt = guide.systemPrompt + kb.locationsBlock;
    try {
      final model = GenerativeModel(
        model: kGeminiModel,
        apiKey: apiKey,
        systemInstruction: Content.system(systemPrompt),
        generationConfig: GenerationConfig(
          temperature: 0.7,
          maxOutputTokens: 1024,
        ),
      );
      final chat = model.startChat();
      return GuideChatSession._(guide: guide, session: chat);
    } catch (_) {
      return null;
    }
  }

  static const String unavailableMessage =
      'Гид временно недоступен, обратитесь к администратору.';
}
