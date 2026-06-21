import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/kg_phone_input_formatter.dart';
import '../../main.dart' show MockData;
import '../../services/auth_service.dart';
import '../../services/comments_service.dart';
import '../../services/requests_service.dart';
import '../../services/tours_service.dart';
import '../auth/auth_guard.dart';
import '../comments/comments_section.dart';

/// Детальная страница индивидуального тура от турагента.
/// Имеет: фото-карусель, описание, программа, условия, даты, цена, кнопка
/// «Записаться на тур» и блок комментариев.
class TourDetailScreen extends StatefulWidget {
  const TourDetailScreen({super.key, required this.id});

  final String id;

  @override
  State<TourDetailScreen> createState() => _TourDetailScreenState();
}

class _TourDetailScreenState extends State<TourDetailScreen> {
  Tour? _tour;
  bool _loading = true;
  final _pageController = PageController();
  int _photoIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
    ToursService.addListener(_load);
  }

  @override
  void dispose() {
    ToursService.removeListener(_load);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final t = await ToursService.getById(widget.id);
    if (!mounted) return;
    setState(() {
      _tour = t;
      _loading = false;
    });
  }

  String _placeTitle(String id) =>
      MockData.places.where((p) => p.id == id).map((p) => p.title).firstOrNull ??
      id;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final t = _tour;
    if (t == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Тур')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Этот тур был удалён турагентом или администратором.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final df = NumberFormat.decimalPattern('ru');
    final dateFmt = DateFormat('dd.MM.yyyy');
    final photos = t.photoUrls;
    return Scaffold(
      appBar: AppBar(title: Text(t.title)),
      body: ListView(
        padding: const EdgeInsets.all(0),
        children: [
          if (photos.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: photos.length,
                    onPageChanged: (i) => setState(() => _photoIndex = i),
                    itemBuilder: (_, i) => _Photo(url: photos[i]),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_photoIndex + 1}/${photos.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  if (photos.length > 1)
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(photos.length, (i) {
                          final active = i == _photoIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(
                              horizontal: 3,
                            ),
                            width: active ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: active
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Турагент: ${t.agentEmail}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '${df.format(t.price.toInt())} ${t.currency}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (t.startDate != null && t.endDate != null)
                      Chip(
                        avatar: const Icon(Icons.date_range, size: 16),
                        label: Text(
                          '${dateFmt.format(t.startDate!)} – ${dateFmt.format(t.endDate!)}',
                        ),
                        visualDensity: VisualDensity.compact,
                      )
                    else
                      Chip(
                        avatar: const Icon(Icons.calendar_month, size: 16),
                        label: Text('${t.durationDays} дн.'),
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
                        label: Text(_placeTitle(id)),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (t.description.isNotEmpty) ...[
                  Text(t.description),
                  const SizedBox(height: 16),
                ],
                if (t.program.isNotEmpty) ...[
                  const _SectionHeader(
                    icon: Icons.list_alt_outlined,
                    text: 'Программа',
                  ),
                  const SizedBox(height: 6),
                  Text(t.program),
                  const SizedBox(height: 16),
                ],
                if (t.conditions.isNotEmpty) ...[
                  const _SectionHeader(
                    icon: Icons.info_outline,
                    text: 'Условия',
                  ),
                  const SizedBox(height: 6),
                  Text(t.conditions),
                  const SizedBox(height: 20),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _openBooking(context, t),
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Записаться на тур'),
                  ),
                ),
                const SizedBox(height: 24),
                CommentsSection(
                  targetType: CommentTarget.tour,
                  targetId: t.id,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openBooking(BuildContext context, Tour t) async {
    if (!await AuthGuard.requireOrPrompt(
      context,
      action: 'записаться на тур',
    )) {
      return;
    }
    if (!context.mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => TourBookingDialog(tour: t),
    );
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Заявка отправлена. Админ свяжется с вами по указанному телефону.',
          ),
        ),
      );
    }
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey.shade300,
          child: const Icon(Icons.image_not_supported_outlined, size: 48),
        ),
      );
    }
    if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey.shade300,
          child: const Icon(Icons.image_not_supported_outlined, size: 48),
        ),
      );
    }
    return Container(
      color: Colors.grey.shade300,
      child: const Icon(Icons.image_outlined, size: 48),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          text,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// Форма «Записаться на тур». Валидация телефона +996 XXX XXX XXX,
/// анти-спам: 1 заявка / 30 сек на устройстве.
class TourBookingDialog extends StatefulWidget {
  const TourBookingDialog({super.key, required this.tour});

  final Tour tour;

  @override
  State<TourBookingDialog> createState() => _TourBookingDialogState();
}

class _TourBookingDialogState extends State<TourBookingDialog> {
  static const _kLastBookingKey = 'last_tour_booking_ts';
  static const _throttleSeconds = 30;

  final _name = TextEditingController();
  final _phone = TextEditingController(text: '+996 ');
  final _people = TextEditingController(text: '1');
  final _note = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _prefillName();
  }

  Future<void> _prefillName() async {
    final user = await AuthService.getCurrentUser();
    if (!mounted) return;
    if (user != null && _name.text.isEmpty) {
      _name.text = user.name;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _people.dispose();
    _note.dispose();
    super.dispose();
  }

  bool _isValidPhone(String raw) => KgPhoneInputFormatter.isValid(raw);

  Future<bool> _throttled() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_kLastBookingKey);
    if (lastMs == null) return false;
    final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
    final diff = DateTime.now().difference(last).inSeconds;
    return diff < _throttleSeconds;
  }

  Future<void> _markSent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _kLastBookingKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _submitting = true;
    });
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() {
        _error = 'Укажите имя (минимум 2 символа)';
        _submitting = false;
      });
      return;
    }
    if (!_isValidPhone(_phone.text)) {
      setState(() {
        _error = 'Телефон в формате +996 XXX XXX XXX';
        _submitting = false;
      });
      return;
    }
    final peopleCount = int.tryParse(_people.text.trim()) ?? 0;
    if (peopleCount < 1) {
      setState(() {
        _error = 'Укажите количество человек (минимум 1)';
        _submitting = false;
      });
      return;
    }
    final tourCapacity = widget.tour.peopleCount;
    if (tourCapacity > 0 && peopleCount > tourCapacity) {
      setState(() {
        _error =
            'В этом туре всего $tourCapacity мест. Уменьшите количество человек.';
        _submitting = false;
      });
      return;
    }
    if (await _throttled()) {
      setState(() {
        _error =
            'Подождите $_throttleSeconds секунд перед следующей заявкой.';
        _submitting = false;
      });
      return;
    }
    final user = await AuthService.getCurrentUser();
    if (user == null) {
      setState(() {
        _error = 'Сессия истекла. Войдите снова.';
        _submitting = false;
      });
      return;
    }
    await RequestsService.createUserTourBooking(
      fromEmail: user.email,
      fromName: name,
      contactPhone: _phone.text.trim(),
      tourId: widget.tour.id,
      tourTitle: widget.tour.title,
      agentEmail: widget.tour.agentEmail,
      peopleCount: peopleCount,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    await _markSent();
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Запись на тур: ${widget.tour.title}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Оставьте контакты — оператор свяжется с вами и подтвердит участие.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Имя *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                inputFormatters: [KgPhoneInputFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Телефон *',
                  hintText: '+996 XXX XXX XXX',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _people,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                decoration: InputDecoration(
                  labelText: 'Количество человек *',
                  helperText: widget.tour.peopleCount > 0
                      ? 'Доступно мест: ${widget.tour.peopleCount}'
                      : null,
                  prefixIcon: const Icon(Icons.group_outlined),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _note,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Комментарий / пожелания (необязательно)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined),
          label: const Text('Отправить'),
        ),
      ],
    );
  }
}
