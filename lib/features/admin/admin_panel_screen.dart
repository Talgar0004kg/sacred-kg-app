import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../main.dart' show MockData, Place;
import '../../services/auth_service.dart';
import '../../services/gemini_service.dart';
import '../../services/locations_override_service.dart';
import '../../services/tours_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 5, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Админ-панель'),
        actions: [
          IconButton(
            tooltip: 'Выйти',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.logout();
              if (!context.mounted) return;
              context.go('/login');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.vpn_key_outlined), text: 'Gemini API'),
            Tab(icon: Icon(Icons.badge_outlined), text: 'Агенты'),
            Tab(icon: Icon(Icons.place_outlined), text: 'Локации'),
            Tab(icon: Icon(Icons.tour_outlined), text: 'Туры'),
            Tab(icon: Icon(Icons.visibility_outlined), text: 'Просмотр'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _ApiKeyTab(),
          _AgentsTab(),
          _LocationsTab(),
          _ToursTab(),
          _ViewAsUserTab(),
        ],
      ),
    );
  }
}

// =====================================================================
// Tab 1: Gemini API key
// =====================================================================

class _ApiKeyTab extends StatefulWidget {
  const _ApiKeyTab();

  @override
  State<_ApiKeyTab> createState() => _ApiKeyTabState();
}

class _ApiKeyTabState extends State<_ApiKeyTab> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _hasKey = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final key = await GeminiService.getApiKey();
    if (!mounted) return;
    setState(() {
      _controller.text = key ?? '';
      _hasKey = key != null && key.isNotEmpty;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await GeminiService.setApiKey(_controller.text);
    if (!mounted) return;
    setState(() => _hasKey = _controller.text.trim().isNotEmpty);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ключ Gemini сохранён')),
    );
  }

  Future<void> _clear() async {
    await GeminiService.setApiKey('');
    if (!mounted) return;
    setState(() {
      _controller.clear();
      _hasKey = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Icon(
              _hasKey ? Icons.check_circle : Icons.error_outline,
              color: _hasKey ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            Text(_hasKey ? 'Ключ сохранён' : 'Ключ не задан'),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _controller,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: 'Gemini API key',
            hintText: 'AIzaSy...',
            prefixIcon: const Icon(Icons.vpn_key_outlined),
            suffixIcon: IconButton(
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Сохранить'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _clear,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Очистить'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Где взять ключ',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 6),
                Text(
                  'Перейдите на https://aistudio.google.com/app/apikey, создайте ключ '
                  'и вставьте его сюда. Используется модель gemini-2.5-flash.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// Tab 2: Agents CRUD
// =====================================================================

class _AgentsTab extends StatefulWidget {
  const _AgentsTab();

  @override
  State<_AgentsTab> createState() => _AgentsTabState();
}

class _AgentsTabState extends State<_AgentsTab> {
  List<AgentCredentials> _agents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final agents = await AuthService.getAgents();
    if (!mounted) return;
    setState(() {
      _agents = agents;
      _loading = false;
    });
  }

  Future<void> _create() async {
    final agent = await AuthService.createAgent();
    await _refresh();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Агент создан'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText('Email: ${agent.email}'),
            const SizedBox(height: 6),
            SelectableText('Пароль: ${agent.password}'),
            const SizedBox(height: 12),
            const Text(
              'Сохраните эти данные сейчас — позже пароль показать нельзя будет '
              'без удаления и пересоздания агента.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Готово'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(AgentCredentials a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить агента?'),
        content: Text('${a.email} и все его туры будут удалены.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await AuthService.deleteAgent(a.email);
    await ToursService.deleteAllForAgent(a.email);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final df = DateFormat('yyyy-MM-dd HH:mm');
    return Stack(
      children: [
        if (_agents.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Агентов ещё нет. Создайте первого, нажав кнопку ниже.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _agents.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final a = _agents[i];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  title: SelectableText(a.email),
                  subtitle: Text('Создан ${df.format(a.createdAt)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(a),
                  ),
                ),
              );
            },
          ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'create_agent',
            onPressed: _create,
            icon: const Icon(Icons.add),
            label: const Text('Создать агента'),
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// Tab 3: Locations override
// =====================================================================

class _LocationsTab extends StatefulWidget {
  const _LocationsTab();

  @override
  State<_LocationsTab> createState() => _LocationsTabState();
}

class _LocationsTabState extends State<_LocationsTab> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    LocationOverridesService.loadIfNeeded().then((_) {
      if (mounted) setState(() => _loading = false);
    });
    LocationOverridesService.addListener(_onChanged);
  }

  @override
  void dispose() {
    LocationOverridesService.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final places = MockData.places;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Изменения сохраняются поверх дефолтных значений и применяются '
                  'без перезапуска.',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Сбросить к дефолтам?'),
                      content: const Text(
                        'Все админские правки локаций будут удалены.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Отмена'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Сбросить'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await LocationOverridesService.clearAll();
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Сбросить'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: places.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final place = places[i];
              final override =
                  LocationOverridesService.overrideForSync(place.id);
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        override != null && !override.isEmpty
                            ? Colors.orange
                            : Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      override != null && !override.isEmpty
                          ? Icons.edit_note
                          : Icons.place_outlined,
                    ),
                  ),
                  title: Text(
                    override?.title?.isNotEmpty == true
                        ? override!.title!
                        : place.title,
                  ),
                  subtitle: Text(
                    override?.shortDescription?.isNotEmpty == true
                        ? override!.shortDescription!
                        : place.shortDescription,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openEditor(place),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openEditor(Place place) async {
    final current = LocationOverridesService.overrideForSync(place.id);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _LocationEditorScreen(
          place: place,
          initialOverride: current,
        ),
      ),
    );
  }
}

class _LocationEditorScreen extends StatefulWidget {
  const _LocationEditorScreen({
    required this.place,
    required this.initialOverride,
  });

  final Place place;
  final LocationOverride? initialOverride;

  @override
  State<_LocationEditorScreen> createState() => _LocationEditorScreenState();
}

class _LocationEditorScreenState extends State<_LocationEditorScreen> {
  late final TextEditingController _title = TextEditingController(
    text: widget.initialOverride?.title ?? widget.place.title,
  );
  late final TextEditingController _short = TextEditingController(
    text: widget.initialOverride?.shortDescription ??
        widget.place.shortDescription,
  );
  late final TextEditingController _full = TextEditingController(
    text: widget.initialOverride?.fullDescription ??
        widget.place.fullDescription,
  );
  late final TextEditingController _image = TextEditingController(
    text: widget.initialOverride?.imageUrl ?? widget.place.imageUrl,
  );
  late final TextEditingController _cultural = TextEditingController(
    text: widget.initialOverride?.culturalNote ?? widget.place.culturalNote,
  );
  late final TextEditingController _rules = TextEditingController(
    text: widget.initialOverride?.visitingRules ??
        widget.place.visitingRules,
  );
  late final TextEditingController _route = TextEditingController(
    text: widget.initialOverride?.route ?? widget.place.route,
  );

  @override
  void dispose() {
    _title.dispose();
    _short.dispose();
    _full.dispose();
    _image.dispose();
    _cultural.dispose();
    _rules.dispose();
    _route.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final override = LocationOverride(
      title: _title.text.trim().isEmpty ? null : _title.text.trim(),
      shortDescription: _short.text.trim().isEmpty ? null : _short.text.trim(),
      fullDescription: _full.text.trim().isEmpty ? null : _full.text.trim(),
      imageUrl: _image.text.trim().isEmpty ? null : _image.text.trim(),
      culturalNote:
          _cultural.text.trim().isEmpty ? null : _cultural.text.trim(),
      visitingRules: _rules.text.trim().isEmpty ? null : _rules.text.trim(),
      route: _route.text.trim().isEmpty ? null : _route.text.trim(),
    );
    await LocationOverridesService.save(widget.place.id, override);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _reset() async {
    await LocationOverridesService.save(
      widget.place.id,
      LocationOverride(),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Локация: ${widget.place.title}'),
        actions: [
          IconButton(
            tooltip: 'Сбросить эту локацию',
            icon: const Icon(Icons.restore),
            onPressed: _reset,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _LabelledField(controller: _title, label: 'Название'),
          _LabelledField(
            controller: _short,
            label: 'Краткое описание',
            maxLines: 2,
          ),
          _LabelledField(
            controller: _full,
            label: 'Полное описание',
            maxLines: 8,
          ),
          _LabelledField(controller: _image, label: 'URL фото'),
          _LabelledField(
            controller: _cultural,
            label: 'Культурная заметка',
            maxLines: 4,
          ),
          _LabelledField(
            controller: _rules,
            label: 'Правила посещения',
            maxLines: 4,
          ),
          _LabelledField(controller: _route, label: 'Маршрут', maxLines: 3),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}

class _LabelledField extends StatelessWidget {
  const _LabelledField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

// =====================================================================
// Tab 4: Tours (admin sees ALL tours)
// =====================================================================

class _ToursTab extends StatefulWidget {
  const _ToursTab();

  @override
  State<_ToursTab> createState() => _ToursTabState();
}

class _ToursTabState extends State<_ToursTab> {
  List<Tour> _tours = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
    ToursService.addListener(_refresh);
  }

  @override
  void dispose() {
    ToursService.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final tours = await ToursService.getAll();
    if (!mounted) return;
    setState(() {
      _tours = tours
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _loading = false;
    });
  }

  Future<void> _delete(Tour t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить тур?'),
        content: Text('${t.title} (агент ${t.agentEmail})'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ToursService.delete(t.id);
    await _refresh();
  }

  Future<void> _edit(Tour t) async {
    final updated = await showDialog<Tour>(
      context: context,
      builder: (_) => TourEditDialog(tour: t),
    );
    if (updated != null) {
      await ToursService.update(updated);
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_tours.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Туров пока нет. Создавать туры могут турагенты в своей панели.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _tours.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final t = _tours[i];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.tour)),
            title: Text(t.title),
            subtitle: Text(
              '${t.durationDays} дн. • ${t.price.toStringAsFixed(0)} сом\n'
              'Агент: ${t.agentEmail} • ${t.locationIds.length} локаций',
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _edit(t),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(t),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Shared dialog used by both admin and agent panels to edit a tour.
class TourEditDialog extends StatefulWidget {
  const TourEditDialog({super.key, required this.tour});

  final Tour tour;

  @override
  State<TourEditDialog> createState() => _TourEditDialogState();
}

class _TourEditDialogState extends State<TourEditDialog> {
  late final TextEditingController _title =
      TextEditingController(text: widget.tour.title);
  late final TextEditingController _description =
      TextEditingController(text: widget.tour.description);
  late final TextEditingController _price = TextEditingController(
    text: widget.tour.price.toStringAsFixed(0),
  );
  late final TextEditingController _duration = TextEditingController(
    text: widget.tour.durationDays.toString(),
  );
  late final Set<String> _selected = {...widget.tour.locationIds};

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _duration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final places = MockData.places;
    return AlertDialog(
      title: const Text('Редактировать тур'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _description,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Описание'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _price,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Цена, сом',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _duration,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Дней',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Локации в туре',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: places.map((p) {
                  final selected = _selected.contains(p.id);
                  return FilterChip(
                    label: Text(p.title),
                    selected: selected,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _selected.add(p.id);
                      } else {
                        _selected.remove(p.id);
                      }
                    }),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            final updated = widget.tour.copyWith(
              title: _title.text.trim(),
              description: _description.text.trim(),
              price: double.tryParse(_price.text) ?? widget.tour.price,
              durationDays:
                  int.tryParse(_duration.text) ?? widget.tour.durationDays,
              locationIds: _selected.toList(),
            );
            Navigator.pop(context, updated);
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

// =====================================================================
// Tab 5: View as user
// =====================================================================

class _ViewAsUserTab extends StatelessWidget {
  const _ViewAsUserTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.visibility, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Просмотр как обычный пользователь',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Вы останетесь администратором, но увидите интерфейс глазами '
              'обычного пользователя. В верхней части экрана появится баннер '
              'для быстрого возврата сюда.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                await AuthService.setAdminViewAsUser(true);
                if (!context.mounted) return;
                context.go('/home');
              },
              icon: const Icon(Icons.preview_outlined),
              label: const Text('Перейти в режим пользователя'),
            ),
          ],
        ),
      ),
    );
  }
}
