import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app_localizations.dart';
import '../../services/auth_service.dart';
import '../../services/notifications_service.dart';

/// Экран уведомлений: список свежих → старых, кнопка «Прочитать все».
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String? _email;
  List<AppNotification> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    NotificationsService.addListener(_refresh);
  }

  @override
  void dispose() {
    NotificationsService.removeListener(_refresh);
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
    final list = await NotificationsService.getFor(email);
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _markAllRead() async {
    final email = _email;
    if (email == null) return;
    await NotificationsService.markAllReadFor(email);
  }

  Future<void> _delete(AppNotification n) async {
    await NotificationsService.delete(n.id);
  }

  IconData _icon(NotificationKind k) {
    switch (k) {
      case NotificationKind.commentReply:
        return Icons.comment_outlined;
      case NotificationKind.requestApproved:
        return Icons.check_circle_outline;
      case NotificationKind.requestRejected:
        return Icons.cancel_outlined;
      case NotificationKind.adminBroadcast:
        return Icons.campaign_outlined;
      case NotificationKind.custom:
        return Icons.notifications_outlined;
    }
  }

  Color _color(BuildContext ctx, NotificationKind k) {
    switch (k) {
      case NotificationKind.commentReply:
        return Theme.of(ctx).colorScheme.primary;
      case NotificationKind.requestApproved:
        return Colors.green;
      case NotificationKind.requestRejected:
        return Theme.of(ctx).colorScheme.error;
      case NotificationKind.adminBroadcast:
        return Theme.of(ctx).colorScheme.secondary;
      case NotificationKind.custom:
        return Theme.of(ctx).hintColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy HH:mm');
    final unread = _items.where((n) => !n.isRead).length;
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notifications),
        actions: [
          if (unread > 0)
            TextButton.icon(
              onPressed: _markAllRead,
              icon: const Icon(Icons.done_all),
              label: Text(l10n.markAllRead),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      l10n.noNotifications,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final n = _items[i];
                    final color = _color(context, n.kind);
                    return Dismissible(
                      key: ValueKey(n.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        color: Theme.of(context).colorScheme.error,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => _delete(n),
                      child: Card(
                        color: n.isRead
                            ? null
                            : color.withOpacity(0.05),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withOpacity(0.15),
                            child: Icon(_icon(n.kind), color: color),
                          ),
                          title: Text(
                            n.title,
                            style: TextStyle(
                              fontWeight: n.isRead
                                  ? FontWeight.normal
                                  : FontWeight.w800,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n.body),
                              const SizedBox(height: 2),
                              Text(
                                df.format(n.createdAt),
                                style:
                                    Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          trailing: n.isRead
                              ? null
                              : Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                          onTap: () =>
                              NotificationsService.markRead(n.id),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

/// Колокольчик с бейджем непрочитанных. Тап → /notifications.
class NotificationsBell extends StatefulWidget {
  const NotificationsBell({super.key});

  @override
  State<NotificationsBell> createState() => _NotificationsBellState();
}

class _NotificationsBellState extends State<NotificationsBell> {
  int _unread = 0;
  String? _email;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    NotificationsService.addListener(_refresh);
  }

  @override
  void dispose() {
    NotificationsService.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final user = await AuthService.getCurrentUser();
    if (!mounted) return;
    setState(() => _email = user?.email);
    await _refresh();
  }

  Future<void> _refresh() async {
    final email = _email;
    if (email == null) {
      if (mounted) setState(() => _unread = 0);
      return;
    }
    final n = await NotificationsService.unreadCountFor(email);
    if (!mounted) return;
    setState(() => _unread = n);
  }

  @override
  Widget build(BuildContext context) {
    // Гостям колокольчик не показываем.
    if (_email == null) return const SizedBox.shrink();
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: context.l10n.notifications,
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => context.push('/notifications'),
        ),
        if (_unread > 0)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                _unread > 99 ? '99+' : '$_unread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
