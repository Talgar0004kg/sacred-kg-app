import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../main.dart' show MockData;
import '../../services/tours_service.dart';

/// Полноэкранный редактор тура — соответствует Task #5:
/// поля «Название, Местность, Описание, Дата начала/окончания,
/// Количество мест, Цена + валюта, Фото», кнопки «Сохранить» и «Отмена».
///
/// Используется в:
/// - панели турагента (создание / редактирование своих туров);
/// - админ-панели (редактирование любого тура).
class TourEditorScreen extends StatefulWidget {
  const TourEditorScreen({
    super.key,
    required this.initial,
    this.title,
  });

  /// Существующий тур (для редактирования) — либо пустой stub при создании.
  final Tour initial;

  /// Опциональный заголовок для AppBar.
  final String? title;

  @override
  State<TourEditorScreen> createState() => _TourEditorScreenState();
}

class _TourEditorScreenState extends State<TourEditorScreen> {
  late final _title = TextEditingController(text: widget.initial.title);
  late final _description =
      TextEditingController(text: widget.initial.description);
  late final _price = TextEditingController(
    text: widget.initial.price > 0
        ? widget.initial.price.toStringAsFixed(0)
        : '',
  );
  late final _peopleCount = TextEditingController(
    text: widget.initial.peopleCount > 0
        ? widget.initial.peopleCount.toString()
        : '',
  );
  late final _photosText = TextEditingController(
    text: widget.initial.photoUrls.join('\n'),
  );
  late final _program =
      TextEditingController(text: widget.initial.program);
  late final _conditions =
      TextEditingController(text: widget.initial.conditions);

  late String _currency = widget.initial.currency;
  late final Set<String> _selectedLocations = {...widget.initial.locationIds};
  late DateTime? _startDate = widget.initial.startDate;
  late DateTime? _endDate = widget.initial.endDate;

  static const _currencies = ['сом', 'USD', 'EUR'];

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _peopleCount.dispose();
    _photosText.dispose();
    _program.dispose();
    _conditions.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      if (_endDate != null && _endDate!.isBefore(picked)) {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickEnd() async {
    final base = _startDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? base,
      firstDate: base,
      lastDate: DateTime(base.year + 3),
    );
    if (picked == null) return;
    setState(() => _endDate = picked);
  }

  int _computeDurationDays() {
    if (_startDate == null || _endDate == null) {
      return widget.initial.durationDays > 0 ? widget.initial.durationDays : 1;
    }
    final diff = _endDate!.difference(_startDate!).inDays;
    return diff < 1 ? 1 : diff + 1;
  }

  String? _validate() {
    if (_title.text.trim().isEmpty) return 'Введите название тура';
    if (_selectedLocations.isEmpty) return 'Выберите хотя бы одну местность';
    if (_startDate == null) return 'Укажите дату начала';
    if (_endDate == null) return 'Укажите дату окончания';
    if (_endDate!.isBefore(_startDate!)) {
      return 'Дата окончания раньше даты начала';
    }
    final priceRaw = _price.text.trim().replaceAll(',', '.');
    final price = double.tryParse(priceRaw);
    if (price == null || price < 0) return 'Укажите корректную цену';
    final people = int.tryParse(_peopleCount.text.trim());
    if (people == null || people < 1) return 'Укажите количество мест';
    return null;
  }

  void _save() {
    final err = _validate();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    final priceRaw = _price.text.trim().replaceAll(',', '.');
    final photos = _photosText.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final result = widget.initial.copyWith(
      title: _title.text.trim(),
      description: _description.text.trim(),
      locationIds: _selectedLocations.toList(),
      price: double.parse(priceRaw),
      durationDays: _computeDurationDays(),
      startDate: _startDate,
      endDate: _endDate,
      peopleCount: int.parse(_peopleCount.text.trim()),
      photoUrls: photos,
      currency: _currency,
      program: _program.text.trim(),
      conditions: _conditions.text.trim(),
    );
    Navigator.of(context).pop<Tour>(result);
  }

  @override
  Widget build(BuildContext context) {
    final places = MockData.places;
    final df = DateFormat('dd.MM.yyyy');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Редактор тура'),
        actions: [
          IconButton(
            tooltip: 'Отмена',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          IconButton(
            tooltip: 'Сохранить',
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Название тура *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Описание',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Местность *',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: places.map((p) {
              final selected = _selectedLocations.contains(p.id);
              return FilterChip(
                label: Text(p.title),
                selected: selected,
                onSelected: (v) => setState(() {
                  if (v) {
                    _selectedLocations.add(p.id);
                  } else {
                    _selectedLocations.remove(p.id);
                  }
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickStart,
                  icon: const Icon(Icons.event),
                  label: Text(
                    _startDate == null
                        ? 'Дата начала *'
                        : df.format(_startDate!),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickEnd,
                  icon: const Icon(Icons.event_available),
                  label: Text(
                    _endDate == null
                        ? 'Дата окончания *'
                        : df.format(_endDate!),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _peopleCount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Кол-во мест *',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _price,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Цена *',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: DropdownButtonFormField<String>(
                  initialValue: _currency,
                  decoration: const InputDecoration(
                    labelText: 'Валюта',
                    border: OutlineInputBorder(),
                  ),
                  items: _currencies
                      .map(
                        (c) => DropdownMenuItem(value: c, child: Text(c)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _currency = v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _photosText,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Фото — каждое с новой строки (URL или assets/...)',
              helperText:
                  'Можно вставить несколько фото. Поддерживаются URL и пути assets/.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _program,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Программа (по дням)',
              helperText: 'Например: День 1 — Бурана; День 2 — Иссык-Куль.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _conditions,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Условия',
              helperText: 'Что включено, требования, ограничения.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  label: const Text('Отмена'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Сохранить'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
