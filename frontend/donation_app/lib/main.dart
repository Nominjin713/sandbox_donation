import 'package:flutter/material.dart';

import 'services/auth_service.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.authService});
  final AuthService? authService;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Хандив',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF087F6B)),
      scaffoldBackgroundColor: const Color(0xFFF3F7F6),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Color(0xFFF8FAF9),
      ),
    ),
    home: AuthPage(authService: authService),
  );
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, this.authService});
  final AuthService? authService;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late final AuthService _authService = widget.authService ?? AuthService();
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _password = TextEditingController(),
      _confirm = TextEditingController();
  bool _register = false, _busy = false, _hide = true;
  String? _error;
  AuthSession? _session;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    if (widget.authService == null) _authService.close();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = _register
          ? await _authService.register(
              name: _name.text,
              email: _email.text,
              password: _password.text,
            )
          : await _authService.login(
              email: _email.text,
              password: _password.text,
            );
      if (!mounted) return;
      setState(() {
        _session = session;
        _hide = true;
      });
      _password.clear();
      _confirm.clear();
    } on AuthException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    if (_busy || _session == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _authService.logout(_session!.token);
      if (mounted) {
        setState(() {
          _session = null;
          _register = false;
        });
      }
    } on AuthException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: AutofillGroup(
                  child: Form(
                    key: _form,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.volunteer_activism,
                          size: 48,
                          color: Color(0xFF087F6B),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _session != null
                              ? 'Тавтай морил!'
                              : (_register ? 'Бүртгүүлэх' : 'Нэвтрэх'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _session != null
                              ? '${_session!.name}\n${_session!.email}'
                              : (_register
                                    ? 'Бүртгэл үүсгээд бидэнтэй нэгдээрэй.'
                                    : 'Бүртгэлээрээ нэвтрэн үргэлжлүүлээрэй.'),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 28),
                        if (_session == null) ...[
                          if (_register) ...[
                            TextFormField(
                              controller: _name,
                              enabled: !_busy,
                              maxLength: 100,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.name],
                              decoration: const InputDecoration(
                                labelText: 'Нэр',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Нэрээ оруулна уу.'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _email,
                            enabled: !_busy,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            enableSuggestions: false,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Имэйл',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                            validator: (v) =>
                                v == null ||
                                    v.trim().length > 254 ||
                                    !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                        .hasMatch(v.trim())
                                ? 'Зөв имэйл оруулна уу.'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _password,
                            enabled: !_busy,
                            obscureText: _hide,
                            autocorrect: false,
                            enableSuggestions: false,
                            autofillHints: [
                              _register
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                            textInputAction: _register
                                ? TextInputAction.next
                                : TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: 'Нууц үг',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _hide
                                    ? 'Нууц үг харах'
                                    : 'Нууц үг нуух',
                                onPressed: () => setState(() => _hide = !_hide),
                                icon: Icon(
                                  _hide
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (v) =>
                                v == null || v.length < 8 || v.length > 128
                                ? '8–128 тэмдэгттэй нууц үг оруулна уу.'
                                : null,
                            onFieldSubmitted: (_) {
                              if (!_busy && !_register) _submit();
                            },
                          ),
                          if (_register) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirm,
                              enabled: !_busy,
                              obscureText: _hide,
                              autocorrect: false,
                              enableSuggestions: false,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.newPassword],
                              decoration: const InputDecoration(
                                labelText: 'Нууц үг давтах',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                              validator: (v) => v != _password.text
                                  ? 'Нууц үг таарахгүй байна.'
                                  : null,
                              onFieldSubmitted: (_) {
                                if (!_busy) _submit();
                              },
                            ),
                          ],
                        ],
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _busy
                              ? null
                              : (_session != null ? _logout : _submit),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _session != null
                                        ? 'Гарах'
                                        : (_register
                                              ? 'Бүртгүүлэх'
                                              : 'Нэвтрэх'),
                                  ),
                          ),
                        ),
                        if (_session == null)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () {
                                    _form.currentState?.reset();
                                    setState(() {
                                      _register = !_register;
                                      _hide = true;
                                      _error = null;
                                      _password.clear();
                                      _confirm.clear();
                                    });
                                  },
                            child: Text(
                              _register
                                  ? 'Бүртгэлтэй юу? Нэвтрэх'
                                  : 'Бүртгэлгүй юу? Бүртгүүлэх',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
