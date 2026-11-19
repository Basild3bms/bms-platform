import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_preferences.dart';
import 'session_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(sessionControllerProvider.notifier)
        .login(_email.text.trim(), _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final session = ref.watch(sessionControllerProvider);
    final theme = ref.watch(themeModeProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.apartment, size: 56),
                      const SizedBox(height: 12),
                      Text('BMS',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineLarge),
                      const SizedBox(height: 8),
                      Text(strings.signIn,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 24),
                      TextFormField(
                        key: const Key('login-email'),
                        controller: _email,
                        decoration: InputDecoration(
                            labelText: strings.email,
                            prefixIcon: const Icon(Icons.email_outlined)),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email
                        ],
                        autocorrect: false,
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(email)
                              ? null
                              : strings.invalidEmail;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('login-password'),
                        controller: _password,
                        decoration: InputDecoration(
                          labelText: strings.password,
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _showPassword
                                ? strings.hidePassword
                                : strings.showPassword,
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                            icon: Icon(_showPassword
                                ? Icons.visibility_off
                                : Icons.visibility),
                          ),
                        ),
                        obscureText: !_showPassword,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                        validator: (value) => value == null || value.isEmpty
                            ? strings.missingPassword
                            : null,
                      ),
                      if (session.failure != null) ...[
                        const SizedBox(height: 16),
                        Text(strings.failureMessage(session.failure!.kind),
                            textAlign: TextAlign.center),
                      ],
                      if (session.revocationUnconfirmed) ...[
                        const SizedBox(height: 16),
                        Text(strings.revocationUnconfirmed,
                            textAlign: TextAlign.center),
                      ],
                      if (session.localRemovalFailed) ...[
                        const SizedBox(height: 16),
                        Text(strings.localRemovalFailed,
                            textAlign: TextAlign.center),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: session.busy ? null : _submit,
                        child: session.busy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator())
                            : Text(strings.signIn),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        children: [
                          TextButton(
                              onPressed: () => ref
                                  .read(localeProvider.notifier)
                                  .setLocale(const Locale('en')),
                              child: const Text('English')),
                          TextButton(
                              onPressed: () => ref
                                  .read(localeProvider.notifier)
                                  .setLocale(const Locale('fr')),
                              child: const Text('Français')),
                          IconButton(
                            tooltip: strings.toggleTheme,
                            onPressed: () => ref
                                .read(themeModeProvider.notifier)
                                .setMode(theme == ThemeMode.dark
                                    ? ThemeMode.light
                                    : ThemeMode.dark),
                            icon: Icon(theme == ThemeMode.dark
                                ? Icons.light_mode
                                : Icons.dark_mode),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
