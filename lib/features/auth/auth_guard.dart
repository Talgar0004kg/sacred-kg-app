import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app_localizations.dart';
import '../../services/auth_service.dart';

/// Универсальная защита действий, требующих аккаунт.
///
/// Использование:
/// ```dart
/// if (await AuthGuard.requireOrPrompt(
///   context,
///   action: 'добавить место в избранное',
/// )) {
///   // действие выполняется
/// }
/// ```
///
/// Если пользователь не залогинен — показывается диалог с предложением войти,
/// и при подтверждении выполняется навигация на `/login`. Метод возвращает
/// `true`, только если пользователь УЖЕ залогинен (само действие после
/// перехода на логин не довыполняется — пользователь повторит после входа).
class AuthGuard {
  AuthGuard._();

  static Future<bool> requireOrPrompt(
    BuildContext context, {
    required String action,
  }) async {
    final user = await AuthService.getCurrentUser();
    if (user != null) return true;
    if (!context.mounted) return false;
    final l10n = context.l10n;
    final goLogin = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.needAccountTitle),
        content: Text(l10n.needAccountBody(action)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.login),
            label: Text(l10n.login),
          ),
        ],
      ),
    );
    if (goLogin == true && context.mounted) {
      context.go('/login');
    }
    return false;
  }
}
