import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({
    super.key,
    required this.authService,
    this.email = '',
  });
  final AuthService authService;
  final String email;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email);
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  String? _message;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_email, _code, _password, _confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit({bool resend = false}) async {
    if (_busy || (!resend && !_form.currentState!.validate())) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.authService.request(
        _sent && !resend ? '/auth/reset-password' : '/auth/forgot-password',
        post: true,
        body: {
          'email': _email.text.trim(),
          if (_sent && !resend) 'code': _code.text.trim(),
          if (_sent && !resend) 'password': _password.text,
        },
      );
      if (!mounted) return;
      if (_sent && !resend) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _sent = true;
        _message = result['message'] as String?;
      });
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Алдаа гарлаа. Дахин оролдоно уу.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Нууц үг сэргээх')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 470),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Бүртгэлтэй имэйл хаягаа оруулж сэргээх код авна уу.',
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _email,
                  enabled: !_busy && !_sent,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Имэйл хаяг'),
                  validator: (value) =>
                      (value ?? '').trim().length <= 254 &&
                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch((value ?? '').trim())
                      ? null
                      : 'Зөв имэйл оруулна уу.',
                ),
                if (_sent) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _code,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    decoration: const InputDecoration(
                      labelText: '6 оронтой код',
                    ),
                    validator: (value) =>
                        RegExp(r'^[0-9]{6}$').hasMatch(value ?? '')
                        ? null
                        : '6 оронтой код оруулна уу.',
                  ),
                  TextFormField(
                    controller: _password,
                    enabled: !_busy,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: const InputDecoration(
                      labelText: 'Шинэ нууц үг',
                    ),
                    validator: (value) =>
                        (value ?? '').length >= 8 && (value ?? '').length <= 128
                        ? null
                        : '8–128 тэмдэгттэй нууц үг оруулна уу.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirm,
                    enabled: !_busy,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: const InputDecoration(
                      labelText: 'Нууц үг давтах',
                    ),
                    validator: (value) => value == _password.text
                        ? null
                        : 'Нууц үг таарахгүй байна.',
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => _submit(resend: true),
                    child: const Text('Код дахин авах (60 секундийн дараа)'),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _sent = false;
                            _code.clear();
                            _message = null;
                            _error = null;
                          }),
                    child: const Text('Имэйл хаяг солих'),
                  ),
                ],
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(_message!),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : () => _submit(),
                  child: Text(
                    _busy
                        ? 'Түр хүлээнэ үү...'
                        : _sent
                        ? 'Нууц үг шинэчлэх'
                        : 'Код авах',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
