import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/gemini_service.dart';
import 'chat_screen.dart';

class GuideSelectionScreen extends StatefulWidget {
  const GuideSelectionScreen({super.key});

  @override
  State<GuideSelectionScreen> createState() => _GuideSelectionScreenState();
}

class _GuideSelectionScreenState extends State<GuideSelectionScreen> {
  bool _hasKey = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final hasKey = await GeminiService.hasApiKey();
    try {
      await GeminiService.loadKnowledgeBase();
      if (!mounted) return;
      setState(() {
        _hasKey = hasKey;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить базу знаний: $e';
        _loading = false;
      });
    }
  }

  void _open(String guideId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(guideId: guideId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ИИ-гид'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (!_hasKey)
                      Card(
                        color: Theme.of(context)
                            .colorScheme
                            .errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  GeminiService.unavailableMessage,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (!_hasKey) const SizedBox(height: 12),
                    Text(
                      'Выберите проводника',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Оба гида опираются на одну и ту же базу знаний по '
                      'сакральным местам Кыргызстана.',
                    ),
                    const SizedBox(height: 16),
                    _GuideCard(
                      title: 'Апашка',
                      subtitle: 'Бабушка-наставница',
                      description:
                          'Тёплая, заботливая. Расскажет о традициях, поделится бытовыми деталями и нежно напомнит об этикете.',
                      icon: Icons.elderly_woman,
                      color: Colors.pink.shade300,
                      enabled: _hasKey,
                      onTap: () => _open('apashka'),
                    ),
                    const SizedBox(height: 12),
                    _GuideCard(
                      title: 'Аташка',
                      subtitle: 'Дедушка — хранитель эпоса',
                      description:
                          'Мудрый, сдержанный. Расскажет об истории, легендах эпоса «Манас» и маршрутах через горы.',
                      icon: Icons.elderly,
                      color: Colors.brown.shade400,
                      enabled: _hasKey,
                      onTap: () => _open('atashka'),
                    ),
                  ],
                ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.enabled,
  });

  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.6,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: color.withValues(alpha: 0.2),
                  child: Icon(icon, size: 36, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(description),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
