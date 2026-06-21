import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_localizations.dart';
import '../../main.dart' show settingsProvider;
import '../../services/auth_service.dart';

/// Login screen.
///
/// Роль (user / agent / admin) определяется автоматически по введённым данным —
/// никаких кнопок выбора роли. В правом верхнем углу — переключатель языка
/// RU/EN/KG со значком глобуса. Он показывается только на экране входа.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _submitting = true;
    });
    UserRole? role;
    try {
      role = await AuthService.resolveRole(
        _email.text,
        _password.text,
      );
    } on BlockedUserException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.reason.isEmpty
            ? 'Аккаунт заблокирован администратором.'
            : 'Аккаунт заблокирован. Причина: ${e.reason}';
      });
      return;
    }
    if (!mounted) return;
    if (role == null) {
      setState(() {
        _submitting = false;
        _error = context.l10n.bothFieldsRequired;
      });
      return;
    }
    await AuthService.login(role: role, email: _email.text.trim());
    if (!mounted) return;
    setState(() => _submitting = false);
    switch (role) {
      case UserRole.admin:
        context.go('/admin');
      case UserRole.agent:
        context.go('/agent');
      case UserRole.user:
        context.go('/home');
    }
  }

  Future<void> _continueAsGuest() async {
    // Гость = посетитель без сессии. Никаких записей в SharedPreferences.
    // На любом защищённом действии сработает AuthGuard и предложит войти.
    await AuthService.logout();
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),
                      Icon(
                        Icons.shield_moon_outlined,
                        size: 56,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.loginGreeting,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.loginSubtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l10n.email,
                          prefixIcon: const Icon(Icons.alternate_email),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: l10n.password,
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(l10n.login),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _submitting
                            ? null
                            : () => context.push('/register'),
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: Text(l10n.createAccount),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _submitting ? null : _continueAsGuest,
                        icon: const Icon(Icons.person_outline),
                        label: Text(l10n.continueAsGuest),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned(
              top: 8,
              right: 8,
              child: _LoginLanguageSwitcher(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Компактный переключатель языков для экрана входа: глобус + RU / EN / KG.
/// Показывается ТОЛЬКО на этом экране (по запросу пользователя).
class _LoginLanguageSwitcher extends ConsumerWidget {
  const _LoginLanguageSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final current = normalizeLanguageCode(settings.language);
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface.withOpacity(0.85),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.public,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ),
            _LangPill(label: 'RU', code: 'ru', selected: current == 'ru'),
            _LangPill(label: 'EN', code: 'en', selected: current == 'en'),
            _LangPill(label: 'KG', code: 'ky', selected: current == 'ky'),
          ],
        ),
      ),
    );
  }
}

class _LangPill extends ConsumerWidget {
  const _LangPill({
    required this.label,
    required this.code,
    required this.selected,
  });

  final String label;
  final String code;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bg = selected ? theme.colorScheme.primary : Colors.transparent;
    final fg = selected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface.withOpacity(0.75);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: selected
          ? null
          : () => ref.read(settingsProvider).setLanguage(code),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: fg,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

