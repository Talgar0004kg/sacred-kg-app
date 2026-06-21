import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app_localizations.dart';
import '../../services/auth_service.dart';
import '../../services/comment_reports_service.dart';
import '../../services/comments_service.dart';

/// Универсальный виджет блока комментариев (Задача 3).
/// Встраивается в карточку местности и в карточку вида тура.
///
/// - Видеть всем (включая гостей).
/// - Писать и отвечать — только залогиненным.
/// - Свой коммент можно редактировать и удалить, чужой — пожаловаться.
/// - Админ удаляет любой (доступ из админ-панели; здесь UI пользователя).
/// - Троттлинг: 1 коммент / 30 сек.
class CommentsSection extends StatefulWidget {
  const CommentsSection({
    super.key,
    required this.targetType,
    required this.targetId,
  });

  final CommentTarget targetType;
  final String targetId;

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  List<Comment> _all = [];
  bool _loading = true;
  String? _currentEmail;
  String? _currentName;
  String? _replyToId; // id корневого комментария, на который отвечаем
  String? _replyToName;
  final _input = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    CommentsService.addListener(_refresh);
  }

  @override
  void dispose() {
    CommentsService.removeListener(_refresh);
    _input.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final user = await AuthService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentEmail = user?.email;
        _currentName = user?.name;
      });
    }
    await _refresh();
  }

  Future<void> _refresh() async {
    final list = await CommentsService.getForTarget(
      widget.targetType,
      widget.targetId,
    );
    if (!mounted) return;
    setState(() {
      _all = list;
      _loading = false;
    });
  }

  bool get _loggedIn => _currentEmail != null && _currentEmail!.isNotEmpty;

  Future<void> _send() async {
    setState(() {
      _error = null;
      _sending = true;
    });
    try {
      await CommentsService.post(
        type: widget.targetType,
        targetId: widget.targetId,
        authorEmail: _currentEmail!,
        authorName: _currentName ?? _currentEmail!.split('@').first,
        text: _input.text,
        parentId: _replyToId,
      );
      _input.clear();
      setState(() {
        _replyToId = null;
        _replyToName = null;
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _editDialog(Comment c) async {
    final controller = TextEditingController(text: c.text);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Редактировать комментарий'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(border: OutlineInputBorder()),
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
    if (result != null && result.trim().isNotEmpty) {
      try {
        await CommentsService.edit(
          commentId: c.id,
          byEmail: _currentEmail!,
          newText: result,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      }
    }
  }

  Future<void> _delete(Comment c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить комментарий?'),
        content: const Text(
          'Если это корневой комментарий, ответы на него тоже удалятся.',
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
    try {
      await CommentsService.delete(
        commentId: c.id,
        byEmail: _currentEmail!,
      );
      await CommentReportsService.deleteByComment(c.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _report(Comment c) async {
    if (!_loggedIn) {
      _showLoginRequired();
      return;
    }
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Пожаловаться на комментарий'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Причина',
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
            child: const Text('Отправить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await CommentReportsService.create(
      commentId: c.id,
      fromEmail: _currentEmail!,
      reason: controller.text.trim().isEmpty
          ? 'Без указания причины'
          : controller.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Жалоба отправлена админу')),
    );
  }

  void _showLoginRequired() {
    final l10n = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.loginToComment),
        action: SnackBarAction(
          label: l10n.login,
          onPressed: () => context.go('/login'),
        ),
      ),
    );
  }

  void _startReply(Comment root) {
    setState(() {
      _replyToId = root.id;
      _replyToName = root.authorName;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final roots = _all.where((c) => c.parentId == null).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.comment_outlined, size: 20),
            const SizedBox(width: 6),
            Text(
              '${l10n.comments} (${_all.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (roots.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.commentsEmpty,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
            ),
          )
        else
          ...roots.map((root) {
            final replies = _all.where((c) => c.parentId == root.id).toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
            return _CommentTile(
              comment: root,
              replies: replies,
              currentEmail: _currentEmail,
              onReply: _loggedIn ? () => _startReply(root) : null,
              onEdit: _editDialog,
              onDelete: _delete,
              onReport: _report,
            );
          }),
        const SizedBox(height: 12),
        _buildInput(context),
      ],
    );
  }

  Widget _buildInput(BuildContext context) {
    final l10n = context.l10n;
    if (!_loggedIn) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.loginToComment)),
            TextButton(
              onPressed: () => context.go('/login'),
              child: Text(l10n.login),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_replyToId != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.reply, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Ответ: ${_replyToName ?? ""}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  iconSize: 18,
                  onPressed: () => setState(() {
                    _replyToId = null;
                    _replyToName = null;
                  }),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        TextField(
          controller: _input,
          minLines: 2,
          maxLines: 4,
          enabled: !_sending,
          decoration: InputDecoration(
            hintText: _replyToId == null ? l10n.yourComment : l10n.yourReply,
            border: const OutlineInputBorder(),
            errorText: _error,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Spacer(),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send, size: 18),
              label: Text(_replyToId == null ? l10n.send : l10n.reply),
            ),
          ],
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.replies,
    required this.currentEmail,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.onReport,
  });

  final Comment comment;
  final List<Comment> replies;
  final String? currentEmail;
  final VoidCallback? onReply;
  final Future<void> Function(Comment) onEdit;
  final Future<void> Function(Comment) onDelete;
  final Future<void> Function(Comment) onReport;

  bool get _isMine =>
      currentEmail != null &&
      comment.authorEmail.toLowerCase() == currentEmail!.toLowerCase();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CommentBody(
              comment: comment,
              isMine: _isMine,
              onReply: onReply,
              onEdit: _isMine ? () => onEdit(comment) : null,
              onDelete: _isMine ? () => onDelete(comment) : null,
              onReport: _isMine ? null : () => onReport(comment),
            ),
            if (replies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 24, top: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: replies
                      .map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: _CommentBody(
                            comment: r,
                            isMine: currentEmail != null &&
                                r.authorEmail.toLowerCase() ==
                                    currentEmail!.toLowerCase(),
                            onReply: null, // 1 уровень вложенности
                            onEdit: currentEmail != null &&
                                    r.authorEmail.toLowerCase() ==
                                        currentEmail!.toLowerCase()
                                ? () => onEdit(r)
                                : null,
                            onDelete: currentEmail != null &&
                                    r.authorEmail.toLowerCase() ==
                                        currentEmail!.toLowerCase()
                                ? () => onDelete(r)
                                : null,
                            onReport: currentEmail != null &&
                                    r.authorEmail.toLowerCase() !=
                                        currentEmail!.toLowerCase()
                                ? () => onReport(r)
                                : null,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CommentBody extends StatelessWidget {
  const _CommentBody({
    required this.comment,
    required this.isMine,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.onReport,
  });

  final Comment comment;
  final bool isMine;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy HH:mm');
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isMine
            ? theme.colorScheme.primary.withOpacity(0.06)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  comment.authorName.isEmpty
                      ? '?'
                      : comment.authorName.characters.first.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  comment.authorName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                df.format(comment.createdAt),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(comment.text),
          if (comment.editedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'отредактировано',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          Row(
            children: [
              if (onReply != null)
                TextButton.icon(
                  onPressed: onReply,
                  icon: const Icon(Icons.reply, size: 16),
                  label: Text(context.l10n.reply),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              if (onEdit != null)
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(context.l10n.edit),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              if (onDelete != null)
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: Text(context.l10n.delete),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              const Spacer(),
              if (onReport != null)
                IconButton(
                  tooltip: context.l10n.report,
                  onPressed: onReport,
                  icon: const Icon(Icons.flag_outlined, size: 18),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
