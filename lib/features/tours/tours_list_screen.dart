import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app_localizations.dart';
import '../../main.dart' show AppScaffold, MockData;
import '../../services/tours_service.dart';

class ToursListScreen extends StatefulWidget {
  const ToursListScreen({super.key});

  @override
  State<ToursListScreen> createState() => _ToursListScreenState();
}

class _ToursListScreenState extends State<ToursListScreen> {
  List<Tour> _all = [];
  bool _loading = true;

  // Фильтры
  String _search = '';
  String? _placeFilter; // id местности из MockData
  String? _agentFilter; // email агента
  double? _priceMin;
  double? _priceMax;
  bool _filtersOpen = false;

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
      _all = tours..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _loading = false;
    });
  }

  String _placeTitle(String id) =>
      MockData.places.where((p) => p.id == id).map((p) => p.title).firstOrNull ??
      id;

  /// Применяет все фильтры к списку.
  List<Tour> _applyFilters(List<Tour> input) {
    return input.where((t) {
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        if (!t.title.toLowerCase().contains(q) &&
            !t.description.toLowerCase().contains(q) &&
            !t.agentEmail.toLowerCase().contains(q)) {
          return false;
        }
      }
      if (_placeFilter != null && !t.locationIds.contains(_placeFilter)) {
        return false;
      }
      if (_agentFilter != null &&
          t.agentEmail.toLowerCase() != _agentFilter!.toLowerCase()) {
        return false;
      }
      if (_priceMin != null && t.price < _priceMin!) return false;
      if (_priceMax != null && t.price > _priceMax!) return false;
      return true;
    }).toList();
  }

  void _resetFilters() {
    setState(() {
      _search = '';
      _placeFilter = null;
      _agentFilter = null;
      _priceMin = null;
      _priceMax = null;
    });
  }

  bool get _hasActiveFilters =>
      _search.isNotEmpty ||
      _placeFilter != null ||
      _agentFilter != null ||
      _priceMin != null ||
      _priceMax != null;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filtered = _applyFilters(_all);
    final agents = _all.map((t) => t.agentEmail).toSet().toList()..sort();
    final places = _all
        .expand((t) => t.locationIds)
        .toSet()
        .toList()
      ..sort();
    return AppScaffold(
      title: l10n.tours,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchBar(),
                if (_filtersOpen)
                  _buildFiltersPanel(agents: agents, places: places),
                if (_hasActiveFilters) _buildActiveChips(),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _all.isEmpty
                                  ? l10n.toursCaption
                                  : 'Туров по выбранным фильтрам нет.',
                              textAlign: TextAlign.center,
                              style:
                                  Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _TourCard(
                            tour: filtered[i],
                            placeTitle: _placeTitle,
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Поиск по названию, описанию, агенту…',
                isDense: true,
                border: const OutlineInputBorder(),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _search = ''),
                      ),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Фильтры',
            onPressed: () => setState(() => _filtersOpen = !_filtersOpen),
            icon: Icon(
              _filtersOpen ? Icons.tune : Icons.tune_outlined,
              color: _hasActiveFilters
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersPanel({
    required List<String> agents,
    required List<String> places,
  }) {
    final minCtrl = TextEditingController(
      text: _priceMin == null ? '' : _priceMin!.toStringAsFixed(0),
    );
    final maxCtrl = TextEditingController(
      text: _priceMax == null ? '' : _priceMax!.toStringAsFixed(0),
    );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Цена',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: minCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'от',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    setState(() {
                      _priceMin = double.tryParse(v.replaceAll(',', '.'));
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: maxCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'до',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    setState(() {
                      _priceMax = double.tryParse(v.replaceAll(',', '.'));
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Местность',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('Любая'),
                selected: _placeFilter == null,
                onSelected: (_) => setState(() => _placeFilter = null),
              ),
              ...places.map(
                (id) => ChoiceChip(
                  label: Text(_placeTitle(id)),
                  selected: _placeFilter == id,
                  onSelected: (_) => setState(
                    () => _placeFilter = _placeFilter == id ? null : id,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Турагент',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String?>(
            initialValue: _agentFilter,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Любой')),
              ...agents.map(
                (email) =>
                    DropdownMenuItem(value: email, child: Text(email)),
              ),
            ],
            onChanged: (v) => setState(() => _agentFilter = v),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Сбросить'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveChips() {
    final df = NumberFormat.decimalPattern('ru');
    final chips = <Widget>[];
    if (_search.isNotEmpty) {
      chips.add(InputChip(
        avatar: const Icon(Icons.search, size: 14),
        label: Text('«$_search»'),
        onDeleted: () => setState(() => _search = ''),
      ));
    }
    if (_placeFilter != null) {
      chips.add(InputChip(
        avatar: const Icon(Icons.place_outlined, size: 14),
        label: Text(_placeTitle(_placeFilter!)),
        onDeleted: () => setState(() => _placeFilter = null),
      ));
    }
    if (_agentFilter != null) {
      chips.add(InputChip(
        avatar: const Icon(Icons.person_outline, size: 14),
        label: Text(_agentFilter!),
        onDeleted: () => setState(() => _agentFilter = null),
      ));
    }
    if (_priceMin != null) {
      chips.add(InputChip(
        avatar: const Icon(Icons.arrow_upward, size: 14),
        label: Text('от ${df.format(_priceMin!.toInt())}'),
        onDeleted: () => setState(() => _priceMin = null),
      ));
    }
    if (_priceMax != null) {
      chips.add(InputChip(
        avatar: const Icon(Icons.arrow_downward, size: 14),
        label: Text('до ${df.format(_priceMax!.toInt())}'),
        onDeleted: () => setState(() => _priceMax = null),
      ));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(spacing: 6, runSpacing: 4, children: chips),
    );
  }
}

class _TourCard extends StatefulWidget {
  const _TourCard({required this.tour, required this.placeTitle});

  final Tour tour;
  final String Function(String id) placeTitle;

  @override
  State<_TourCard> createState() => _TourCardState();
}

class _TourCardState extends State<_TourCard> {
  final _pageController = PageController();
  int _currentPhoto = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) => DateFormat('dd.MM.yyyy').format(d);

  @override
  Widget build(BuildContext context) {
    final t = widget.tour;
    final photos = t.photoUrls;
    final df = NumberFormat.decimalPattern('ru');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/tour/${t.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (photos.isNotEmpty)
              _PhotoCarousel(
                photoUrls: photos,
                controller: _pageController,
                currentIndex: _currentPhoto,
                onPageChanged: (i) => setState(() => _currentPhoto = i),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Турагент: ${t.agentEmail}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (t.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      t.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (t.startDate != null && t.endDate != null)
                        Chip(
                          avatar: const Icon(Icons.date_range, size: 16),
                          label: Text(
                            '${_formatDate(t.startDate!)} – ${_formatDate(t.endDate!)}',
                          ),
                          visualDensity: VisualDensity.compact,
                        )
                      else
                        Chip(
                          avatar: const Icon(Icons.calendar_month, size: 16),
                          label: Text('${t.durationDays} дн.'),
                          visualDensity: VisualDensity.compact,
                        ),
                      Chip(
                        avatar: const Icon(Icons.payments_outlined, size: 16),
                        label: Text(
                          '${df.format(t.price.toInt())} ${t.currency}',
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      if (t.peopleCount > 0)
                        Chip(
                          avatar: const Icon(Icons.group_outlined, size: 16),
                          label: Text('${t.peopleCount} мест'),
                          visualDensity: VisualDensity.compact,
                        ),
                      ...t.locationIds.map(
                        (id) => Chip(
                          avatar: const Icon(Icons.place_outlined, size: 16),
                          label: Text(widget.placeTitle(id)),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Spacer(),
                      Text(
                        'Подробнее →',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Карусель с PageView, точками-индикаторами и счётчиком 1/N (Task #4).
class _PhotoCarousel extends StatelessWidget {
  const _PhotoCarousel({
    required this.photoUrls,
    required this.controller,
    required this.currentIndex,
    required this.onPageChanged,
    this.height = 200,
  });

  final List<String> photoUrls;
  final PageController controller;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          PageView.builder(
            controller: controller,
            itemCount: photoUrls.length,
            onPageChanged: onPageChanged,
            itemBuilder: (_, i) {
              final url = photoUrls[i];
              if (url.startsWith('assets/')) {
                return Image.asset(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.image_not_supported_outlined,
                        size: 48),
                  ),
                );
              }
              if (url.startsWith('http')) {
                return Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.image_not_supported_outlined,
                        size: 48),
                  ),
                );
              }
              return Container(
                color: Colors.grey.shade300,
                child: const Icon(Icons.image_outlined, size: 48),
              );
            },
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${currentIndex + 1}/${photoUrls.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          if (photoUrls.length > 1)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(photoUrls.length, (i) {
                  final active = i == currentIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color:
                          active ? Colors.white : Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
