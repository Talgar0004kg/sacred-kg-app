import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../main.dart' show MockData, Place;
import '../../services/auth_service.dart';
import '../../services/custom_locations_service.dart';
import '../../services/gemini_service.dart';
import '../../services/locations_override_service.dart';
import '../../services/comment_reports_service.dart';
import '../../services/comments_service.dart';
import '../../services/notifications_service.dart';
import '../../services/requests_service.dart';
import '../../services/tours_service.dart';
import '../tours/tour_editor_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 10, vsync: this);

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
            Tab(icon: Icon(Icons.people_outline), text: 'Пользователи'),
            Tab(icon: Icon(Icons.badge_outlined), text: 'Турагенты'),
            Tab(icon: Icon(Icons.place_outlined), text: 'Локации'),
            Tab(icon: Icon(Icons.tour_outlined), text: 'Туры'),
            Tab(icon: Icon(Icons.inbox_outlined), text: 'Запросы'),
            Tab(icon: Icon(Icons.comment_outlined), text: 'Комментарии'),
            Tab(icon: Icon(Icons.flag_outlined), text: 'Жалобы'),
            Tab(icon: Icon(Icons.campaign_outlined), text: 'Рассылка'),
            Tab(icon: Icon(Icons.visibility_outlined), text: 'Просмотр'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _ApiKeyTab(),
          _UsersTab(),
          _AgentsTab(),
          _LocationsTab(),
          _ToursTab(),
          _RequestsTab(),
          _CommentsModerationTab(),
          _CommentReportsTab(),
          _BroadcastTab(),
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
  String _search = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final agents = await AuthService.getAgents();
    if (!mounted) return;
    setState(() {
      _agents = agents..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _loading = false;
    });
  }

  List<AgentCredentials> _filtered() {
    if (_search.isEmpty) return _agents;
    final q = _search.toLowerCase();
    return _agents
        .where((a) => a.email.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _createAuto() async {
    final agent = await AuthService.createAgent();
    await _refresh();
    if (!mounted) return;
    await _showCredentialsDialog(
      title: 'Агент создан',
      email: agent.email,
      password: agent.password,
    );
  }

  Future<void> _createManual() async {
    final result = await showDialog<({String email, String password})>(
      context: context,
      builder: (_) => const _AgentCredentialsDialog(
        title: 'Создать агента вручную',
        submitLabel: 'Создать',
      ),
    );
    if (result == null) return;
    try {
      final agent = await AuthService.createAgentWithCredentials(
        email: result.email,
        password: result.password,
      );
      await _refresh();
      if (!mounted) return;
      await _showCredentialsDialog(
        title: 'Агент создан',
        email: agent.email,
        password: agent.password,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst(RegExp(r'^[^:]+: '), ''))),
        );
      }
    }
  }

  Future<void> _edit(AgentCredentials a) async {
    final result = await showDialog<({String email, String password})>(
      context: context,
      builder: (_) => _AgentCredentialsDialog(
        title: 'Редактировать агента',
        submitLabel: 'Сохранить',
        initialEmail: a.email,
        passwordOptional: true,
      ),
    );
    if (result == null) return;
    try {
      await AuthService.updateAgent(
        oldEmail: a.email,
        newEmail: result.email,
        newPassword:
            result.password.isEmpty ? null : result.password,
      );
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Изменения сохранены')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst(RegExp(r'^[^:]+: '), ''))),
        );
      }
    }
  }

  Future<void> _resetPassword(AgentCredentials a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сбросить пароль?'),
        content: Text(
          'Будет сгенерирован новый пароль для ${a.email}. Старый перестанет работать.',
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
    if (ok != true) return;
    final newPassword = await AuthService.resetAgentPassword(a.email);
    await _refresh();
    if (!mounted) return;
    await _showCredentialsDialog(
      title: 'Новый пароль',
      email: a.email,
      password: newPassword,
    );
  }

  Future<void> _delete(AgentCredentials a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить агента?'),
        content: Text(
          '${a.email} и все его туры будут удалены безвозвратно.',
        ),
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

  Future<void> _showCredentialsDialog({
    required String title,
    required String email,
    required String password,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText('Email: $email'),
            const SizedBox(height: 6),
            SelectableText('Пароль: $password'),
            const SizedBox(height: 12),
            const Text(
              'Сохраните эти данные сейчас — позже пароль можно только '
              'сбросить.',
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final df = DateFormat('yyyy-MM-dd HH:mm');
    final filtered = _filtered();
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Поиск по email',
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
            Expanded(
              child: _agents.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Турагентов ещё нет. Создайте первого через кнопку справа внизу.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'По запросу никого не найдено.',
                          ),
                        )
                      : ListView.separated(
                          padding:
                              const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final a = filtered[i];
                            return Card(
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Colors.amber,
                                  child: Icon(
                                    Icons.work_outline,
                                    color: Colors.white,
                                  ),
                                ),
                                title: SelectableText(a.email),
                                subtitle: Text(
                                  'Создан ${df.format(a.createdAt)}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Редактировать',
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => _edit(a),
                                    ),
                                    IconButton(
                                      tooltip: 'Сбросить пароль',
                                      icon: const Icon(Icons.lock_reset),
                                      onPressed: () => _resetPassword(a),
                                    ),
                                    IconButton(
                                      tooltip: 'Удалить',
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => _delete(a),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 76,
          child: FloatingActionButton.small(
            heroTag: 'create_agent_manual',
            tooltip: 'Создать вручную',
            onPressed: _createManual,
            child: const Icon(Icons.person_add_alt_1),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'create_agent_auto',
            onPressed: _createAuto,
            icon: const Icon(Icons.casino_outlined),
            label: const Text('Сгенерировать'),
          ),
        ),
      ],
    );
  }
}

/// Диалог ввода email и пароля для агента (создание / редактирование).
class _AgentCredentialsDialog extends StatefulWidget {
  const _AgentCredentialsDialog({
    required this.title,
    required this.submitLabel,
    this.initialEmail = '',
    this.passwordOptional = false,
  });

  final String title;
  final String submitLabel;
  final String initialEmail;
  final bool passwordOptional;

  @override
  State<_AgentCredentialsDialog> createState() =>
      _AgentCredentialsDialogState();
}

class _AgentCredentialsDialogState extends State<_AgentCredentialsDialog> {
  late final _email = TextEditingController(text: widget.initialEmail);
  final _password = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _email.text.trim();
    final password = _password.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Введите email');
      return;
    }
    final emailOk =
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!emailOk) {
      setState(() => _error = 'Некорректный email');
      return;
    }
    if (!widget.passwordOptional && password.length < 4) {
      setState(() => _error = 'Пароль минимум 4 символа');
      return;
    }
    if (widget.passwordOptional &&
        password.isNotEmpty &&
        password.length < 4) {
      setState(() => _error = 'Пароль минимум 4 символа (или оставьте пустым)');
      return;
    }
    Navigator.of(context).pop((email: email, password: password));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email *',
                prefixIcon: Icon(Icons.alternate_email),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText:
                    widget.passwordOptional ? 'Новый пароль' : 'Пароль *',
                helperText: widget.passwordOptional
                    ? 'Оставьте пустым, чтобы не менять'
                    : 'Минимум 4 символа',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.submitLabel),
        ),
      ],
    );
  }
}

// =====================================================================
// Tab: Users management (просмотр / поиск / редактирование / удаление)
// =====================================================================

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  List<_UserInfo> _users = [];
  Map<String, String> _blocked = const {};
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _refresh();
    RequestsService.addListener(_refresh);
    CommentsService.addListener(_refresh);
  }

  @override
  void dispose() {
    RequestsService.removeListener(_refresh);
    CommentsService.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final users = await _collectUsers();
    final blocked = await AuthService.getBlocklist();
    if (!mounted) return;
    setState(() {
      _users = users;
      _blocked = blocked;
      _loading = false;
    });
  }

  /// Собирает обычных пользователей из заявок и комментариев,
  /// исключая агентов и админа.
  Future<List<_UserInfo>> _collectUsers() async {
    final agents = await AuthService.getAgents();
    final agentSet = agents.map((a) => a.email.toLowerCase()).toSet();
    final requests = await RequestsService.getAll();
    final comments = await CommentsService.getAll();
    final byEmail = <String, _UserInfo>{};

    for (final r in requests) {
      final key = r.fromEmail.toLowerCase();
      if (key.isEmpty || agentSet.contains(key)) continue;
      if (key == AuthService.adminEmail.toLowerCase()) continue;
      final existing = byEmail[key];
      byEmail[key] = _UserInfo(
        email: r.fromEmail,
        name: existing?.name ?? r.fromName,
        requestsCount: (existing?.requestsCount ?? 0) + 1,
        commentsCount: existing?.commentsCount ?? 0,
        lastSeen: _max(existing?.lastSeen, r.createdAt),
      );
    }
    for (final c in comments) {
      final key = c.authorEmail.toLowerCase();
      if (key.isEmpty || agentSet.contains(key)) continue;
      if (key == AuthService.adminEmail.toLowerCase()) continue;
      final existing = byEmail[key];
      byEmail[key] = _UserInfo(
        email: c.authorEmail,
        name: existing?.name ?? c.authorName,
        requestsCount: existing?.requestsCount ?? 0,
        commentsCount: (existing?.commentsCount ?? 0) + 1,
        lastSeen: _max(existing?.lastSeen, c.createdAt),
      );
    }
    final list = byEmail.values.toList();
    list.sort((a, b) {
      final l = b.lastSeen ?? DateTime(2000);
      final r = a.lastSeen ?? DateTime(2000);
      return l.compareTo(r);
    });
    return list;
  }

  DateTime? _max(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.isAfter(b) ? a : b;
  }

  List<_UserInfo> _filtered() {
    if (_search.isEmpty) return _users;
    final q = _search.toLowerCase();
    return _users.where((u) {
      return u.email.toLowerCase().contains(q) ||
          (u.name?.toLowerCase() ?? '').contains(q);
    }).toList();
  }

  Future<void> _openUserActions(_UserInfo user) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _UserActionsSheet(user: user, onChanged: _refresh),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final filtered = _filtered();
    final df = DateFormat('dd.MM.yyyy HH:mm');
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Поиск по имени или email',
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                'Всего пользователей: ${_users.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      _users.isEmpty
                          ? 'Пользователей пока нет. Они появятся здесь, '
                              'когда отправят заявку или оставят комментарий.'
                          : 'По запросу никого не найдено.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final u = filtered[i];
                    final isBlocked =
                        _blocked.containsKey(u.email.toLowerCase());
                    return Card(
                      child: ListTile(
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              backgroundColor: isBlocked
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.primary,
                              child: Text(
                                u.displayName.characters.isEmpty
                                    ? '?'
                                    : u.displayName.characters.first
                                        .toUpperCase(),
                                style:
                                    const TextStyle(color: Colors.white),
                              ),
                            ),
                            if (isBlocked)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surface,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.block,
                                    size: 12,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .error,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                u.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (isBlocked)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .error
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Заблокирован',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.email),
                            const SizedBox(height: 2),
                            Text(
                              'Заявок: ${u.requestsCount} • Комментариев: ${u.commentsCount}'
                              '${u.lastSeen != null ? "\nАктивен: ${df.format(u.lastSeen!)}" : ""}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.more_vert),
                        onTap: () => _openUserActions(u),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _UserInfo {
  _UserInfo({
    required this.email,
    this.name,
    required this.requestsCount,
    required this.commentsCount,
    this.lastSeen,
  });

  final String email;
  final String? name;
  final int requestsCount;
  final int commentsCount;
  final DateTime? lastSeen;

  String get displayName =>
      (name != null && name!.trim().isNotEmpty) ? name! : email.split('@').first;
}

class _UserActionsSheet extends StatefulWidget {
  const _UserActionsSheet({required this.user, required this.onChanged});

  final _UserInfo user;
  final VoidCallback onChanged;

  @override
  State<_UserActionsSheet> createState() => _UserActionsSheetState();
}

class _UserActionsSheetState extends State<_UserActionsSheet> {
  String? _blockReason;
  bool _checkingBlock = true;

  _UserInfo get user => widget.user;
  VoidCallback get onChanged => widget.onChanged;

  @override
  void initState() {
    super.initState();
    _loadBlockStatus();
  }

  Future<void> _loadBlockStatus() async {
    final reason = await AuthService.getBlockReason(user.email);
    if (!mounted) return;
    setState(() {
      _blockReason = reason;
      _checkingBlock = false;
    });
  }

  bool get _isBlocked => _blockReason != null;

  Future<void> _sendMessage(BuildContext context) async {
    Navigator.of(context).pop();
    await showDialog<bool>(
      context: context,
      builder: (_) => _ComposeMessageDialog(
        person: _Person(
          email: user.email,
          name: user.name,
          isAgent: false,
        ),
      ),
    );
  }

  Future<void> _editName(BuildContext context) async {
    final controller =
        TextEditingController(text: user.name ?? user.displayName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Изменить имя'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Имя пользователя',
            helperText:
                'Применится во всех его заявках и комментариях.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (newName == null) return;
    final reqChanged =
        await RequestsService.renameAuthor(user.email, newName);
    final comChanged =
        await CommentsService.renameAuthor(user.email, newName);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    onChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Имя обновлено: заявок $reqChanged, комментариев $comChanged.',
        ),
      ),
    );
  }

  Future<void> _block(BuildContext context) async {
    final controller = TextEditingController();
    final commit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Заблокировать пользователя?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Он не сможет войти в аккаунт, отправлять заявки и оставлять '
              'комментарии. Старые данные остаются нетронутыми.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Причина (необязательно)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Заблокировать'),
          ),
        ],
      ),
    );
    if (commit != true) return;
    await AuthService.blockUser(user.email, reason: controller.text.trim());
    if (!context.mounted) return;
    Navigator.of(context).pop();
    onChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Пользователь ${user.email} заблокирован')),
    );
  }

  Future<void> _unblock(BuildContext context) async {
    await AuthService.unblockUser(user.email);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    onChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${user.email} разблокирован')),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить пользователя?'),
        content: Text(
          'Будут удалены ВСЕ данные ${user.email}: '
          '${user.requestsCount} заявок, ${user.commentsCount} комментариев, '
          'жалобы и уведомления. Действие необратимо.',
        ),
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
    final delReq = await RequestsService.deleteByEmail(user.email);
    final delCom = await CommentsService.deleteByAuthor(user.email);
    await CommentReportsService.deleteByAuthor(user.email);
    await NotificationsService.deleteAllFor(user.email);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    onChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Удалено: заявок $delReq, комментариев $delCom.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    user.displayName.characters.isEmpty
                        ? '?'
                        : user.displayName.characters.first.toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(user.email),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.inbox, size: 16),
                  label: Text('Заявок: ${user.requestsCount}'),
                ),
                Chip(
                  avatar: const Icon(Icons.comment, size: 16),
                  label: Text('Комментариев: ${user.commentsCount}'),
                ),
              ],
            ),
            if (_isBlocked)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .error
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.block,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _blockReason!.isEmpty
                              ? 'Пользователь заблокирован'
                              : 'Заблокирован: $_blockReason',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            const Divider(),
            if (_checkingBlock)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.send),
                title: const Text('Написать сообщение'),
                subtitle:
                    const Text('Уведомление придёт в колокольчик'),
                onTap: () => _sendMessage(context),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Изменить имя'),
                subtitle: const Text(
                  'Обновит имя автора во всех его заявках и комментариях',
                ),
                onTap: () => _editName(context),
              ),
              if (_isBlocked)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.lock_open,
                    color: Colors.green,
                  ),
                  title: const Text(
                    'Разблокировать',
                    style: TextStyle(color: Colors.green),
                  ),
                  subtitle: const Text(
                    'Пользователь снова сможет войти и оставлять записи',
                  ),
                  onTap: () => _unblock(context),
                )
              else
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.block,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    'Заблокировать',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  subtitle: const Text(
                    'Запрет на вход, заявки и комментарии',
                  ),
                  onTap: () => _block(context),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Удалить пользователя',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                subtitle: const Text(
                  'Удалит все его заявки, комментарии и уведомления',
                ),
                onTap: () => _delete(context),
              ),
            ],
          ],
        ),
      ),
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
  List<CustomLocation> _custom = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
    LocationOverridesService.addListener(_onChanged);
    CustomLocationsService.addListener(_refreshCustom);
  }

  @override
  void dispose() {
    LocationOverridesService.removeListener(_onChanged);
    CustomLocationsService.removeListener(_refreshCustom);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await LocationOverridesService.loadIfNeeded();
    await _refreshCustom();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refreshCustom() async {
    final list = await CustomLocationsService.getAll();
    if (!mounted) return;
    setState(() {
      _custom = list..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _deleteCustom(CustomLocation l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить местность?'),
        content: Text(
          'Местность «${l.title}» будет полностью удалена для всех пользователей.',
        ),
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
    await CustomLocationsService.delete(l.id);
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
                  'без перезапуска. Местности от турагентов можно удалить полностью.',
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
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_custom.isNotEmpty) ...[
                _SectionHeader(
                  icon: Icons.new_releases_outlined,
                  text: 'Добавленные турагентами (${_custom.length})',
                ),
                const SizedBox(height: 8),
                for (final l in _custom) ...[
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.teal,
                        child: Icon(Icons.add_location_alt_outlined,
                            color: Colors.white),
                      ),
                      title: Text(l.title),
                      subtitle: Text(
                        '${l.shortDescription}\nДобавил: ${l.addedByEmail}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        tooltip: 'Удалить местность',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteCustom(l),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                _SectionHeader(
                  icon: Icons.place_outlined,
                  text: 'Базовые местности (${places.length})',
                ),
                const SizedBox(height: 8),
              ],
              for (final place in places) ...[
                _buildDefaultPlaceCard(place),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultPlaceCard(Place place) {
    final override = LocationOverridesService.overrideForSync(place.id);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: override != null && !override.isEmpty
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
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
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
    final updated = await Navigator.of(context).push<Tour>(
      MaterialPageRoute(
        builder: (_) => TourEditorScreen(
          initial: t,
          title: 'Редактирование тура',
        ),
      ),
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
// Tab 5: Requests (от пользователей / от турагентов)
// =====================================================================

class _RequestsTab extends StatefulWidget {
  const _RequestsTab();

  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab>
    with SingleTickerProviderStateMixin {
  late final TabController _inner = TabController(length: 2, vsync: this);
  List<AppRequest> _userActive = [];
  List<AppRequest> _userHistory = [];
  List<AppRequest> _agentActive = [];
  List<AppRequest> _agentHistory = [];
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
    _inner.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final userActive = await RequestsService.getFromUsers();
    final userHistory =
        await RequestsService.getFromUsers(historyOnly: true);
    final agentActive = await RequestsService.getFromAgents();
    final agentHistory =
        await RequestsService.getFromAgents(historyOnly: true);
    if (!mounted) return;
    setState(() {
      _userActive = userActive;
      _userHistory = userHistory;
      _agentActive = agentActive;
      _agentHistory = agentHistory;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _inner,
            tabs: [
              Tab(
                icon: const Icon(Icons.person_outline),
                text:
                    'От пользователей (${_userActive.length}/${_userHistory.length})',
              ),
              Tab(
                icon: const Icon(Icons.work_outline),
                text:
                    'От турагентов (${_agentActive.length}/${_agentHistory.length})',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _inner,
            children: [
              _RequestsBucket(
                active: _userActive,
                history: _userHistory,
                emptyActiveText:
                    'Активных заявок от пользователей пока нет. Они появятся '
                    'здесь, когда пользователи отправят заявку на посещение или '
                    'заявку по виду тура.',
              ),
              _RequestsBucket(
                active: _agentActive,
                history: _agentHistory,
                emptyActiveText:
                    'Активных запросов от турагентов пока нет. Они появятся '
                    'здесь, когда турагент предложит новую местность или '
                    'другое обращение.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Корзина одной суб-вкладки: сегмент «Активные / История» + фильтры в истории.
class _RequestsBucket extends StatefulWidget {
  const _RequestsBucket({
    required this.active,
    required this.history,
    required this.emptyActiveText,
  });

  final List<AppRequest> active;
  final List<AppRequest> history;
  final String emptyActiveText;

  @override
  State<_RequestsBucket> createState() => _RequestsBucketState();
}

class _RequestsBucketState extends State<_RequestsBucket> {
  bool _showHistory = false;
  RequestStatus? _statusFilter; // null = любой
  RequestType? _typeFilter; // null = любой
  DateTimeRange? _dateRange;

  List<AppRequest> _applyFilters(List<AppRequest> list) {
    return list.where((r) {
      if (_statusFilter != null && r.status != _statusFilter) return false;
      if (_typeFilter != null && r.type != _typeFilter) return false;
      if (_dateRange != null) {
        final t = r.decidedAt ?? r.createdAt;
        if (t.isBefore(_dateRange!.start) ||
            t.isAfter(_dateRange!.end.add(const Duration(days: 1)))) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _dateRange,
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  @override
  Widget build(BuildContext context) {
    final list =
        _showHistory ? _applyFilters(widget.history) : widget.active;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                icon: const Icon(Icons.inbox_outlined),
                label: Text('Активные (${widget.active.length})'),
              ),
              ButtonSegment(
                value: true,
                icon: const Icon(Icons.history),
                label: Text('История (${widget.history.length})'),
              ),
            ],
            selected: {_showHistory},
            onSelectionChanged: (s) =>
                setState(() => _showHistory = s.first),
          ),
        ),
        if (_showHistory) _buildFilters(),
        Expanded(
          child: list.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      _showHistory
                          ? 'В истории нет заявок, подходящих под фильтры.'
                          : widget.emptyActiveText,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _RequestCard(request: list[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    final df = DateFormat('dd.MM.yyyy');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilterChip(
            label: const Text('Все статусы'),
            selected: _statusFilter == null,
            onSelected: (_) => setState(() => _statusFilter = null),
          ),
          FilterChip(
            label: const Text('Одобрено'),
            selected: _statusFilter == RequestStatus.approved,
            onSelected: (_) =>
                setState(() => _statusFilter = RequestStatus.approved),
          ),
          FilterChip(
            label: const Text('Отклонено'),
            selected: _statusFilter == RequestStatus.rejected,
            onSelected: (_) =>
                setState(() => _statusFilter = RequestStatus.rejected),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<RequestType?>(
            tooltip: 'Тип',
            initialValue: _typeFilter,
            onSelected: (v) => setState(() => _typeFilter = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: null, child: Text('Все типы')),
              PopupMenuItem(
                value: RequestType.visitPlace,
                child: Text('Посещение местности'),
              ),
              PopupMenuItem(
                value: RequestType.tourInquiry,
                child: Text('Заявки на туры'),
              ),
              PopupMenuItem(
                value: RequestType.addLocation,
                child: Text('Добавление местности'),
              ),
              PopupMenuItem(
                value: RequestType.other,
                child: Text('Прочее'),
              ),
            ],
            child: Chip(
              avatar: const Icon(Icons.filter_alt_outlined, size: 16),
              label: Text(_typeFilter == null
                  ? 'Все типы'
                  : _typeLabel(_typeFilter!)),
            ),
          ),
          ActionChip(
            avatar: const Icon(Icons.date_range, size: 16),
            label: Text(
              _dateRange == null
                  ? 'Любая дата'
                  : '${df.format(_dateRange!.start)} – ${df.format(_dateRange!.end)}',
            ),
            onPressed: _pickRange,
          ),
          if (_dateRange != null)
            IconButton(
              tooltip: 'Сбросить даты',
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _dateRange = null),
            ),
        ],
      ),
    );
  }

  String _typeLabel(RequestType t) {
    switch (t) {
      case RequestType.visitPlace:
        return 'Посещение';
      case RequestType.tourInquiry:
        return 'Тур';
      case RequestType.addLocation:
        return 'Новая местность';
      case RequestType.other:
        return 'Прочее';
    }
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final AppRequest request;

  static const _uuid = Uuid();

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

  String _statusLabel() {
    switch (request.status) {
      case RequestStatus.pending:
        return 'Ожидает';
      case RequestStatus.approved:
        return 'Одобрено';
      case RequestStatus.rejected:
        return 'Отклонено';
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

  Future<String?> _currentAdminEmail() async {
    final user = await AuthService.getCurrentUser();
    return user?.email;
  }

  Future<void> _approve(BuildContext context) async {
    // Если это заявка турагента на добавление местности — публикуем её.
    if (request.type == RequestType.addLocation) {
      final loc = CustomLocation(
        id: _uuid.v4(),
        title: (request.payload['title'] as String?) ?? '',
        regionId: (request.payload['regionId'] as String?) ?? '',
        shortDescription:
            (request.payload['shortDescription'] as String?) ?? '',
        fullDescription:
            (request.payload['fullDescription'] as String?) ?? '',
        imageUrl: (request.payload['imageUrl'] as String?) ?? '',
        addedByEmail: request.fromEmail,
        createdAt: DateTime.now(),
      );
      await CustomLocationsService.add(loc);
    }
    final adminEmail = await _currentAdminEmail();
    await RequestsService.setStatus(
      request.id,
      RequestStatus.approved,
      adminEmail: adminEmail,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Заявка одобрена')),
    );
  }

  Future<void> _reject(BuildContext context) async {
    final controller = TextEditingController();
    final commit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отклонить заявку?'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Причина (необязательно)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Отклонить'),
          ),
        ],
      ),
    );
    if (commit != true) return;
    final adminEmail = await _currentAdminEmail();
    await RequestsService.setStatus(
      request.id,
      RequestStatus.rejected,
      comment: controller.text.trim().isEmpty ? null : controller.text.trim(),
      adminEmail: adminEmail,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Заявка отклонена')),
    );
  }

  Future<void> _restore(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Восстановить заявку?'),
        content: const Text(
          'Заявка вернётся в активные. Статус, дата решения и админ '
          'будут сброшены.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Восстановить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await RequestsService.revert(request.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Заявка возвращена в активные')),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить заявку из архива?'),
        content: const Text('Запись будет полностью удалена.'),
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
    await RequestsService.delete(request.id);
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy HH:mm');
    final isPending = request.status == RequestStatus.pending;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      _statusColor(context).withOpacity(0.15),
                  child: Icon(_typeIcon(), color: _statusColor(context)),
                ),
                const SizedBox(width: 10),
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
                      const SizedBox(height: 2),
                      Text(
                        'От: ${request.fromName ?? request.fromEmail}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(context).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusLabel(),
                    style: TextStyle(
                      color: _statusColor(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (request.contactPhone != null &&
                request.contactPhone!.isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.phone, size: 16),
                  const SizedBox(width: 6),
                  SelectableText(
                    request.contactPhone!,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            if (request.type == RequestType.visitPlace) ...[
              const SizedBox(height: 4),
              Text('Место: ${request.payload['placeTitle'] ?? '-'}'),
              if (request.payload['date'] is String)
                Text('Дата: ${request.payload['date']}'),
              if (request.payload['peopleCount'] != null)
                Text('Людей: ${request.payload['peopleCount']}'),
              if ((request.payload['notes'] as String?)?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Заметка: ${request.payload['notes']}'),
                ),
            ],
            if (request.type == RequestType.tourInquiry) ...[
              const SizedBox(height: 4),
              Text('Тур: ${request.payload['tourTitle'] ?? '-'}'),
              if ((request.payload['agentEmail'] as String?)?.isNotEmpty == true)
                Text('Турагент: ${request.payload['agentEmail']}'),
              if (request.payload['peopleCount'] != null)
                Text('Человек: ${request.payload['peopleCount']}'),
              if ((request.payload['note'] as String?)?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Пожелания: ${request.payload['note']}'),
                ),
            ],
            if (request.type == RequestType.addLocation) ...[
              const SizedBox(height: 4),
              Text('Регион: ${request.payload['regionId'] ?? '-'}'),
              if ((request.payload['shortDescription'] as String?)
                      ?.isNotEmpty ==
                  true)
                Text(
                  'Описание: ${request.payload['shortDescription']}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
            if (request.type == RequestType.other &&
                (request.payload['body'] as String?)?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(request.payload['body'] as String),
              ),
            if (request.adminComment != null &&
                request.adminComment!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Комментарий админа: ${request.adminComment}',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            if (request.decidedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Решено: ${df.format(request.decidedAt!)}'
                '${request.decidedBy != null ? " · ${request.decidedBy}" : ""}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 14,
                  color: Theme.of(context).hintColor,
                ),
                const SizedBox(width: 4),
                Text(
                  df.format(request.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                if (isPending) ...[
                  TextButton.icon(
                    onPressed: () => _reject(context),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Отклонить'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.icon(
                    onPressed: () => _approve(context),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Одобрить'),
                  ),
                ] else ...[
                  TextButton.icon(
                    onPressed: () => _restore(context),
                    icon: const Icon(Icons.restore, size: 18),
                    label: const Text('Восстановить'),
                  ),
                  IconButton(
                    tooltip: 'Удалить из архива',
                    onPressed: () => _delete(context),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Tab: Comments moderation
// =====================================================================

class _CommentsModerationTab extends StatefulWidget {
  const _CommentsModerationTab();

  @override
  State<_CommentsModerationTab> createState() =>
      _CommentsModerationTabState();
}

class _CommentsModerationTabState extends State<_CommentsModerationTab> {
  List<Comment> _all = [];
  bool _loading = true;
  String _search = '';

  String _targetLabel(CommentTarget t) {
    switch (t) {
      case CommentTarget.place:
        return 'Местность';
      case CommentTarget.tour:
        return 'Тур';
      case CommentTarget.post:
        return 'Пост';
    }
  }
  CommentTarget? _typeFilter;

  @override
  void initState() {
    super.initState();
    _refresh();
    CommentsService.addListener(_refresh);
  }

  @override
  void dispose() {
    CommentsService.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final list = await CommentsService.getAll();
    if (!mounted) return;
    setState(() {
      _all = list..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _loading = false;
    });
  }

  Future<void> _delete(Comment c) async {
    final user = await AuthService.getCurrentUser();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить комментарий?'),
        content: Text(
          c.parentId == null
              ? 'Корневой комментарий и все ответы на него будут удалены.'
              : 'Ответ будет удалён.',
        ),
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
    await CommentsService.delete(
      commentId: c.id,
      byEmail: user?.email ?? '',
      asAdmin: true,
    );
    await CommentReportsService.deleteByComment(c.id);
  }

  List<Comment> _applyFilters() {
    return _all.where((c) {
      if (_typeFilter != null && c.targetType != _typeFilter) return false;
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        if (!c.text.toLowerCase().contains(q) &&
            !c.authorName.toLowerCase().contains(q) &&
            !c.authorEmail.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final filtered = _applyFilters();
    final df = DateFormat('dd.MM.yyyy HH:mm');
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Поиск по тексту, автору или email…',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 6,
            children: [
              ChoiceChip(
                label: Text('Все (${_all.length})'),
                selected: _typeFilter == null,
                onSelected: (_) => setState(() => _typeFilter = null),
              ),
              ChoiceChip(
                label: const Text('Местности'),
                selected: _typeFilter == CommentTarget.place,
                onSelected: (_) =>
                    setState(() => _typeFilter = CommentTarget.place),
              ),
              ChoiceChip(
                label: const Text('Туры'),
                selected: _typeFilter == CommentTarget.tour,
                onSelected: (_) =>
                    setState(() => _typeFilter = CommentTarget.tour),
              ),
              ChoiceChip(
                label: const Text('Посты'),
                selected: _typeFilter == CommentTarget.post,
                onSelected: (_) =>
                    setState(() => _typeFilter = CommentTarget.post),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Комментариев, подходящих под фильтры, нет.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final c = filtered[i];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              c.parentId == null ? Colors.teal : Colors.blue,
                          child: Icon(
                            c.parentId == null
                                ? Icons.comment_outlined
                                : Icons.reply,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          c.text,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${c.authorName} <${c.authorEmail}>',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${_targetLabel(c.targetType)}: '
                                '${c.targetId} • ${df.format(c.createdAt)}',
                                style:
                                    Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          tooltip: 'Удалить',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(c),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// =====================================================================
// Tab: Comment reports
// =====================================================================

class _CommentReportsTab extends StatefulWidget {
  const _CommentReportsTab();

  @override
  State<_CommentReportsTab> createState() => _CommentReportsTabState();
}

class _CommentReportsTabState extends State<_CommentReportsTab> {
  List<CommentReport> _reports = [];
  Map<String, Comment> _commentsById = {};
  bool _loading = true;
  bool _openOnly = true;

  @override
  void initState() {
    super.initState();
    _refresh();
    CommentReportsService.addListener(_refresh);
    CommentsService.addListener(_refresh);
  }

  @override
  void dispose() {
    CommentReportsService.removeListener(_refresh);
    CommentsService.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final reports = await CommentReportsService.getAll(openOnly: _openOnly);
    final allComments = await CommentsService.getAll();
    if (!mounted) return;
    setState(() {
      _reports = reports;
      _commentsById = {for (final c in allComments) c.id: c};
      _loading = false;
    });
  }

  Future<void> _deleteComment(CommentReport r) async {
    final user = await AuthService.getCurrentUser();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить комментарий?'),
        content: const Text(
          'Комментарий будет удалён вместе со всеми ответами и жалобами на него.',
        ),
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
    await CommentsService.delete(
      commentId: r.commentId,
      byEmail: user?.email ?? '',
      asAdmin: true,
    );
    await CommentReportsService.deleteByComment(r.commentId);
  }

  Future<void> _resolve(CommentReport r) async {
    final user = await AuthService.getCurrentUser();
    await CommentReportsService.resolve(r.id, byEmail: user?.email);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final df = DateFormat('dd.MM.yyyy HH:mm');
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Открытые')),
                    ButtonSegment(value: false, label: Text('Все')),
                  ],
                  selected: {_openOnly},
                  onSelectionChanged: (s) {
                    setState(() => _openOnly = s.first);
                    _refresh();
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _reports.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Жалоб пока нет.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reports.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final r = _reports[i];
                    final c = _commentsById[r.commentId];
                    final isOpen = r.status == ReportStatus.open;
                    final color =
                        isOpen ? Colors.orange : Colors.grey;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      color.withOpacity(0.15),
                                  child: Icon(
                                    Icons.flag_outlined,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Жалоба от ${r.fromEmail}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        df.format(r.createdAt),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isOpen ? 'Открыта' : 'Закрыта',
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Причина: ${r.reason}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  if (c == null)
                                    const Text(
                                      'Комментарий уже удалён.',
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                      ),
                                    )
                                  else ...[
                                    Text(
                                      'Автор коммента: ${c.authorName} <${c.authorEmail}>',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Text('«${c.text}»'),
                                  ],
                                ],
                              ),
                            ),
                            if (r.resolvedAt != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'Закрыта: ${df.format(r.resolvedAt!)}'
                                  '${r.resolvedBy != null ? " · ${r.resolvedBy}" : ""}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        fontStyle: FontStyle.italic,
                                      ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (c != null)
                                  TextButton.icon(
                                    onPressed: () => _deleteComment(r),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                    ),
                                    label: const Text('Удалить коммент'),
                                  ),
                                const Spacer(),
                                if (isOpen)
                                  FilledButton.icon(
                                    onPressed: () => _resolve(r),
                                    icon: const Icon(Icons.check, size: 18),
                                    label: const Text('Закрыть жалобу'),
                                  )
                                else
                                  IconButton(
                                    tooltip: 'Удалить запись жалобы',
                                    onPressed: () =>
                                        CommentReportsService.delete(r.id),
                                    icon:
                                        const Icon(Icons.delete_sweep_outlined),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// =====================================================================
// Tab: Broadcast (рассылка новостей / адресных сообщений)
// =====================================================================

/// Аудитория для общей (массовой) рассылки.
enum _GeneralAudience { all, users, agents }

/// Фильтр для адресной вкладки.
enum _PeopleFilter { all, users, agents }

/// Запись о человеке, известном системе (из агентов, заявок, комментов).
class _Person {
  _Person({required this.email, this.name, required this.isAgent});

  final String email;
  final String? name;
  final bool isAgent;

  String get displayName =>
      (name != null && name!.trim().isNotEmpty) ? name! : email.split('@').first;
}

class _BroadcastTab extends StatefulWidget {
  const _BroadcastTab();

  @override
  State<_BroadcastTab> createState() => _BroadcastTabState();
}

class _BroadcastTabState extends State<_BroadcastTab>
    with SingleTickerProviderStateMixin {
  late final TabController _inner = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _inner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _inner,
            tabs: const [
              Tab(
                icon: Icon(Icons.campaign_outlined),
                text: 'Общая',
              ),
              Tab(
                icon: Icon(Icons.person_pin_outlined),
                text: 'Адресная',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _inner,
            children: const [
              _GeneralBroadcastView(),
              _TargetedBroadcastView(),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------- Общая рассылка ----------

class _GeneralBroadcastView extends StatefulWidget {
  const _GeneralBroadcastView();

  @override
  State<_GeneralBroadcastView> createState() => _GeneralBroadcastViewState();
}

class _GeneralBroadcastViewState extends State<_GeneralBroadcastView> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  _GeneralAudience _audience = _GeneralAudience.all;
  bool _sending = false;
  String? _info;
  bool _infoError = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<Set<String>> _resolveRecipients() async {
    final all = await _collectAllEmails();
    switch (_audience) {
      case _GeneralAudience.all:
        return all;
      case _GeneralAudience.users:
        final agents = await AuthService.getAgents();
        final agentSet =
            agents.map((a) => a.email.toLowerCase()).toSet();
        return all.where((e) => !agentSet.contains(e)).toSet();
      case _GeneralAudience.agents:
        final agents = await AuthService.getAgents();
        return agents.map((a) => a.email.toLowerCase()).toSet();
    }
  }

  Future<void> _send() async {
    setState(() {
      _info = null;
      _infoError = false;
      _sending = true;
    });
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.isEmpty) {
      setState(() {
        _info = 'Заполните заголовок и текст.';
        _infoError = true;
        _sending = false;
      });
      return;
    }
    final recipients = await _resolveRecipients();
    if (recipients.isEmpty) {
      setState(() {
        _info = 'Нет получателей для выбранной аудитории.';
        _infoError = true;
        _sending = false;
      });
      return;
    }
    final count = await NotificationsService.broadcast(
      recipients: recipients,
      title: title,
      body: body,
    );
    if (!mounted) return;
    setState(() {
      _title.clear();
      _body.clear();
      _info = 'Отправлено получателей: $count.';
      _infoError = false;
      _sending = false;
    });
  }

  String _audienceLabel(_GeneralAudience a) {
    switch (a) {
      case _GeneralAudience.all:
        return 'Всем';
      case _GeneralAudience.users:
        return 'Только пользователям';
      case _GeneralAudience.agents:
        return 'Только турагентам';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Массовая рассылка',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Одно сообщение уйдёт всем получателям выбранной аудитории.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        const Text('Аудитория',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _GeneralAudience.values
              .map(
                (a) => ChoiceChip(
                  label: Text(_audienceLabel(a)),
                  selected: _audience == a,
                  onSelected: (_) => setState(() => _audience = a),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 10),
        FutureBuilder<Set<String>>(
          future: _resolveRecipients(),
          builder: (_, snap) => Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.group_outlined, size: 18),
                const SizedBox(width: 8),
                Text(
                  snap.connectionState == ConnectionState.done
                      ? 'Будет отправлено: ${snap.data?.length ?? 0} получателям'
                      : 'Считаем получателей…',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _title,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Заголовок *',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _body,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Текст сообщения *',
            border: OutlineInputBorder(),
          ),
        ),
        if (_info != null) ...[
          const SizedBox(height: 12),
          _InfoBanner(text: _info!, isError: _infoError),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _sending ? null : _send,
          icon: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: const Text('Отправить'),
        ),
      ],
    );
  }
}

// ---------- Адресная рассылка ----------

class _TargetedBroadcastView extends StatefulWidget {
  const _TargetedBroadcastView();

  @override
  State<_TargetedBroadcastView> createState() => _TargetedBroadcastViewState();
}

class _TargetedBroadcastViewState extends State<_TargetedBroadcastView> {
  List<_Person> _people = [];
  bool _loading = true;
  String _search = '';
  _PeopleFilter _filter = _PeopleFilter.all;

  @override
  void initState() {
    super.initState();
    _refresh();
    RequestsService.addListener(_refresh);
    CommentsService.addListener(_refresh);
  }

  @override
  void dispose() {
    RequestsService.removeListener(_refresh);
    CommentsService.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final list = await _loadAllPeople();
    if (!mounted) return;
    setState(() {
      _people = list;
      _loading = false;
    });
  }

  List<_Person> _applyFilters() {
    return _people.where((p) {
      if (_filter == _PeopleFilter.users && p.isAgent) return false;
      if (_filter == _PeopleFilter.agents && !p.isAgent) return false;
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        final inEmail = p.email.toLowerCase().contains(q);
        final inName = (p.name?.toLowerCase() ?? '').contains(q);
        if (!inEmail && !inName) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _openCompose(_Person person) async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => _ComposeMessageDialog(person: person),
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Сообщение отправлено на ${person.email}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final filtered = _applyFilters();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Поиск по имени или email…',
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Wrap(
            spacing: 6,
            children: [
              ChoiceChip(
                label: Text('Все (${_people.length})'),
                selected: _filter == _PeopleFilter.all,
                onSelected: (_) => setState(() => _filter = _PeopleFilter.all),
              ),
              ChoiceChip(
                label: Text(
                  'Пользователи (${_people.where((p) => !p.isAgent).length})',
                ),
                selected: _filter == _PeopleFilter.users,
                onSelected: (_) => setState(() => _filter = _PeopleFilter.users),
              ),
              ChoiceChip(
                label: Text(
                  'Турагенты (${_people.where((p) => p.isAgent).length})',
                ),
                selected: _filter == _PeopleFilter.agents,
                onSelected: (_) => setState(() => _filter = _PeopleFilter.agents),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      _people.isEmpty
                          ? 'Известных пользователей пока нет. Они появятся '
                              'здесь, когда оставят заявку или комментарий.'
                          : 'По выбранным фильтрам никого не найдено.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final p = filtered[i];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: p.isAgent
                              ? Colors.amber
                              : Theme.of(context).colorScheme.primary,
                          child: Icon(
                            p.isAgent
                                ? Icons.work_outline
                                : Icons.person_outline,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          p.displayName,
                          style:
                              const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(p.email),
                        trailing: FilledButton.icon(
                          onPressed: () => _openCompose(p),
                          icon: const Icon(Icons.send, size: 16),
                          label: const Text('Написать'),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Диалог адресного сообщения (заголовок + текст) для одного получателя.
class _ComposeMessageDialog extends StatefulWidget {
  const _ComposeMessageDialog({required this.person});

  final _Person person;

  @override
  State<_ComposeMessageDialog> createState() => _ComposeMessageDialogState();
}

class _ComposeMessageDialogState extends State<_ComposeMessageDialog> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _error = null;
      _sending = true;
    });
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.isEmpty) {
      setState(() {
        _error = 'Заполните заголовок и текст.';
        _sending = false;
      });
      return;
    }
    await NotificationsService.broadcast(
      recipients: [widget.person.email],
      title: title,
      body: body,
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Сообщение: ${widget.person.displayName}'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.person.email,
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Заголовок *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _body,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Текст *',
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
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton.icon(
          onPressed: _sending ? null : _send,
          icon: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: const Text('Отправить'),
        ),
      ],
    );
  }
}

// ---------- Общие helpers для рассылки ----------

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isError
            ? Theme.of(context).colorScheme.error.withOpacity(0.12)
            : Colors.green.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle,
            color: isError
                ? Theme.of(context).colorScheme.error
                : Colors.green,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

/// Собирает все известные email (агенты + заявки + комменты), исключая
/// админский email. Возвращает только адреса.
Future<Set<String>> _collectAllEmails() async {
  final agents = await AuthService.getAgents();
  final requests = await RequestsService.getAll();
  final comments = await CommentsService.getAll();
  final result = <String>{};
  for (final a in agents) {
    if (a.email.isNotEmpty) result.add(a.email.toLowerCase());
  }
  for (final r in requests) {
    if (r.fromEmail.isNotEmpty) result.add(r.fromEmail.toLowerCase());
  }
  for (final c in comments) {
    if (c.authorEmail.isNotEmpty) result.add(c.authorEmail.toLowerCase());
  }
  result.remove(AuthService.adminEmail.toLowerCase());
  return result;
}

/// Собирает полные карточки людей (email + name + флаг агента).
/// Имя берётся из последней встретившейся записи (заявка / коммент).
Future<List<_Person>> _loadAllPeople() async {
  final agents = await AuthService.getAgents();
  final requests = await RequestsService.getAll();
  final comments = await CommentsService.getAll();
  final byEmail = <String, _Person>{};

  for (final a in agents) {
    final key = a.email.toLowerCase();
    if (key.isEmpty) continue;
    byEmail[key] = _Person(email: a.email, isAgent: true);
  }
  for (final r in requests) {
    final key = r.fromEmail.toLowerCase();
    if (key.isEmpty) continue;
    final existing = byEmail[key];
    byEmail[key] = _Person(
      email: r.fromEmail,
      name: r.fromName ?? existing?.name,
      isAgent: existing?.isAgent ?? false,
    );
  }
  for (final c in comments) {
    final key = c.authorEmail.toLowerCase();
    if (key.isEmpty) continue;
    final existing = byEmail[key];
    byEmail[key] = _Person(
      email: c.authorEmail,
      name: existing?.name ?? c.authorName,
      isAgent: existing?.isAgent ?? false,
    );
  }
  byEmail.remove(AuthService.adminEmail.toLowerCase());
  final list = byEmail.values.toList();
  list.sort((a, b) => a.displayName
      .toLowerCase()
      .compareTo(b.displayName.toLowerCase()));
  return list;
}

// =====================================================================
// Tab: View as user
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
