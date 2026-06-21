import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../main.dart' show MockData;
import '../../services/auth_service.dart';
import '../../services/requests_service.dart';
import '../../services/tours_service.dart';
import '../requests/my_requests_list.dart';
import '../tours/tour_editor_screen.dart';

class AgentPanelScreen extends StatefulWidget {
  const AgentPanelScreen({super.key});

  @override
  State<AgentPanelScreen> createState() => _AgentPanelScreenState();
}

class _AgentPanelScreenState extends State<AgentPanelScreen> {
  static const _uuid = Uuid();

  String? _email;
  List<Tour> _tours = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    ToursService.addListener(_refresh);
  }

  @override
  void dispose() {
    ToursService.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final user = await AuthService.getCurrentUser();
    if (!mounted) return;
    if (user == null) {
      context.go('/login');
      return;
    }
    setState(() => _email = user.email);
    await _refresh();
  }

  Future<void> _refresh() async {
    final email = _email;
    if (email == null) return;
    final tours = await ToursService.getForAgent(email);
    if (!mounted) return;
    setState(() {
      _tours = tours..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _loading = false;
    });
  }

  Future<void> _createTour() async {
    final email = _email;
    if (email == null) return;
    final stub = Tour(
      id: _uuid.v4(),
      agentEmail: email,
      title: '',
      description: '',
      locationIds: const [],
      price: 0,
      durationDays: 1,
      createdAt: DateTime.now(),
    );
    final result = await Navigator.of(context).push<Tour>(
      MaterialPageRoute(
        builder: (_) => TourEditorScreen(
          initial: stub,
          title: 'Новый тур',
        ),
      ),
    );
    if (result == null) return;
    if (result.title.trim().isEmpty) return;
    await ToursService.create(
      agentEmail: email,
      title: result.title,
      description: result.description,
      locationIds: result.locationIds,
      price: result.price,
      durationDays: result.durationDays,
      startDate: result.startDate,
      endDate: result.endDate,
      peopleCount: result.peopleCount,
      photoUrls: result.photoUrls,
      currency: result.currency,
      program: result.program,
      conditions: result.conditions,
    );
    await _refresh();
  }

  Future<void> _editTour(Tour t) async {
    final result = await Navigator.of(context).push<Tour>(
      MaterialPageRoute(
        builder: (_) => TourEditorScreen(
          initial: t,
          title: 'Редактирование тура',
        ),
      ),
    );
    if (result == null) return;
    await ToursService.update(result);
    await _refresh();
  }

  Future<void> _deleteTour(Tour t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить тур?'),
        content: Text(t.title),
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

  String _placeTitle(String id) =>
      MockData.places.where((p) => p.id == id).map((p) => p.title).firstOrNull ??
      id;

  Future<void> _proposeLocation() async {
    final email = _email;
    if (email == null) return;
    final result = await showDialog<_ProposedLocationData>(
      context: context,
      builder: (_) => const _ProposeLocationDialog(),
    );
    if (result == null) return;
    await RequestsService.createAgentLocationProposal(
      fromEmail: email,
      title: result.title,
      regionId: result.regionId,
      shortDescription: result.shortDescription,
      fullDescription: result.fullDescription,
      imageUrl: result.imageUrl,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Заявка отправлена админу. Местность появится после одобрения.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Панель турагента'),
        actions: [
          IconButton(
            tooltip: 'Предложить новую местность',
            icon: const Icon(Icons.add_location_alt_outlined),
            onPressed: _proposeLocation,
          ),
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createTour,
        icon: const Icon(Icons.add),
        label: const Text('Новый тур'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tours.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.tour_outlined, size: 64),
                        const SizedBox(height: 12),
                        Text(
                          'У вас ещё нет туров',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Аккаунт: ${_email ?? ""}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tours.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    if (i == _tours.length) {
                      // Раздел «Мои отправленные заявки» в конце списка туров.
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Мои отправленные заявки',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            if (_email != null)
                              MyRequestsList(email: _email!),
                          ],
                        ),
                      );
                    }
                    final t = _tours[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.tour, size: 22),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    t.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _editTour(t),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _deleteTour(t),
                                ),
                              ],
                            ),
                            if (t.description.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(t.description),
                              ),
                            Row(
                              children: [
                                Chip(
                                  label: Text('${t.durationDays} дн.'),
                                  visualDensity: VisualDensity.compact,
                                ),
                                const SizedBox(width: 6),
                                Chip(
                                  label: Text(
                                    '${t.price.toStringAsFixed(0)} сом',
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            if (t.locationIds.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: t.locationIds
                                    .map(
                                      (id) => Chip(
                                        label: Text(_placeTitle(id)),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _ProposedLocationData {
  _ProposedLocationData({
    required this.title,
    required this.regionId,
    required this.shortDescription,
    required this.fullDescription,
    required this.imageUrl,
  });

  final String title;
  final String regionId;
  final String shortDescription;
  final String fullDescription;
  final String imageUrl;
}

class _ProposeLocationDialog extends StatefulWidget {
  const _ProposeLocationDialog();

  @override
  State<_ProposeLocationDialog> createState() => _ProposeLocationDialogState();
}

class _ProposeLocationDialogState extends State<_ProposeLocationDialog> {
  final _title = TextEditingController();
  final _short = TextEditingController();
  final _full = TextEditingController();
  final _image = TextEditingController();
  String? _regionId;

  @override
  void dispose() {
    _title.dispose();
    _short.dispose();
    _full.dispose();
    _image.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _title.text.trim();
    final region = _regionId;
    final shortD = _short.text.trim();
    if (title.isEmpty || region == null || shortD.isEmpty) return;
    Navigator.of(context).pop(
      _ProposedLocationData(
        title: title,
        regionId: region,
        shortDescription: shortD,
        fullDescription: _full.text.trim(),
        imageUrl: _image.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final regions = MockData.regions;
    return AlertDialog(
      title: const Text('Предложить новую местность'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Местность будет отправлена админу на проверку. После одобрения '
                'она появится у всех пользователей.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Название *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _regionId,
                decoration: const InputDecoration(
                  labelText: 'Область *',
                  border: OutlineInputBorder(),
                ),
                items: regions
                    .map(
                      (r) => DropdownMenuItem(
                        value: r.id,
                        child: Text(r.name),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _regionId = v),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _short,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Краткое описание *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _full,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Полное описание',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _image,
                decoration: const InputDecoration(
                  labelText: 'URL фото (необязательно)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.send_outlined),
          label: const Text('Отправить'),
        ),
      ],
    );
  }
}
