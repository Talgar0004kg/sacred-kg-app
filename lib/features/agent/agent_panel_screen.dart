import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../main.dart' show MockData;
import '../../services/auth_service.dart';
import '../../services/tours_service.dart';
import '../admin/admin_panel_screen.dart' show TourEditDialog;

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
      title: 'Новый тур',
      description: '',
      locationIds: const [],
      price: 0,
      durationDays: 1,
      createdAt: DateTime.now(),
    );
    final result = await showDialog<Tour>(
      context: context,
      builder: (_) => TourEditDialog(tour: stub),
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
    );
    await _refresh();
  }

  Future<void> _editTour(Tour t) async {
    final result = await showDialog<Tour>(
      context: context,
      builder: (_) => TourEditDialog(tour: t),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Панель турагента'),
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
                  itemCount: _tours.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
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
