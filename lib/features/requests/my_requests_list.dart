import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/requests_service.dart';

/// Раздел «Мои заявки» для личного кабинета пользователя и панели турагента
/// (Задача 1). Показывает свежие заявки текущего email с человекочитаемым
/// статусом: «Ожидание», «Ваша заявка одобрена…», «Заявка отклонена…».
class MyRequestsList extends StatefulWidget {
  const MyRequestsList({
    super.key,
    required this.email,
    this.maxItems,
  });

  final String email;

  /// Если задано — показывать не более N заявок (для компактных секций).
  final int? maxItems;

  @override
  State<MyRequestsList> createState() => _MyRequestsListState();
}

class _MyRequestsListState extends State<MyRequestsList> {
  List<AppRequest> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
    RequestsService.addListener(_refresh);
  }

  @override
  void dispose() {
    RequestsService.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final items = await RequestsService.getForEmail(widget.email);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'У вас пока нет заявок.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    final visible = widget.maxItems != null && _items.length > widget.maxItems!
        ? _items.sublist(0, widget.maxItems!)
        : _items;
    return Column(
      children: visible.map((r) => _RequestRow(request: r)).toList(),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.request});

  final AppRequest request;

  Color _statusColor(BuildContext ctx) {
    switch (request.status) {
      case RequestStatus.pending:
        return Colors.orange;
      case RequestStatus.approved:
        return Colors.green;
      case RequestStatus.rejected:
        return Theme.of(ctx).colorScheme.error;
    }
  }

  IconData _typeIcon() {
    switch (request.type) {
      case RequestType.visitPlace:
        return Icons.event_available_outlined;
      case RequestType.tourInquiry:
        return Icons.tour_outlined;
      case RequestType.addLocation:
        return Icons.add_location_alt_outlined;
      case RequestType.other:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy HH:mm');
    final color = _statusColor(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_typeIcon(), color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.summaryTitle(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  if (request.type == RequestType.tourInquiry &&
                      request.payload['peopleCount'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Человек: ${request.payload['peopleCount']}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    request.userFacingStatus(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Отправлено: ${df.format(request.createdAt)}'
                    '${request.decidedAt != null ? "  •  Решено: ${df.format(request.decidedAt!)}" : ""}',
                    style: Theme.of(context).textTheme.bodySmall,
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
