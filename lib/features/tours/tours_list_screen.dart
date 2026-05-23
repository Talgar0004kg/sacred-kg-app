import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart' show MockData;
import '../../services/tours_service.dart';

class ToursListScreen extends StatefulWidget {
  const ToursListScreen({super.key});

  @override
  State<ToursListScreen> createState() => _ToursListScreenState();
}

class _ToursListScreenState extends State<ToursListScreen> {
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
      _tours = tours..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _loading = false;
    });
  }

  String _placeTitle(String id) =>
      MockData.places.where((p) => p.id == id).map((p) => p.title).firstOrNull ??
      id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Туры'),
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
          : _tours.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Туров пока нет. Загляните позже — турагенты добавляют '
                      'новые маршруты по сакральным местам Кыргызстана.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tours.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final t = _tours[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.title,
                              style:
                                  Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'От агента: ${t.agentEmail}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (t.description.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(t.description),
                            ],
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Chip(
                                  avatar: const Icon(
                                    Icons.calendar_month,
                                    size: 16,
                                  ),
                                  label: Text('${t.durationDays} дн.'),
                                  visualDensity: VisualDensity.compact,
                                ),
                                Chip(
                                  avatar: const Icon(
                                    Icons.payments_outlined,
                                    size: 16,
                                  ),
                                  label: Text(
                                    '${t.price.toStringAsFixed(0)} сом',
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                ...t.locationIds.map(
                                  (id) => Chip(
                                    avatar: const Icon(
                                      Icons.place_outlined,
                                      size: 16,
                                    ),
                                    label: Text(_placeTitle(id)),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
