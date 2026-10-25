import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'auth_style.dart';

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
  bool _hide = true;
  bool _hideConfirm = true;
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
    backgroundColor: authBackground,
    appBar: AppBar(
      backgroundColor: authBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: IconButton(
          tooltip: 'Буцах',
          onPressed: () => Navigator.maybePop(context),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: authBlue,
            shape: const CircleBorder(),
          ),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      title: const Text(
        'Volunteer Hub',
        style: TextStyle(
          color: authDarkBlue,
          fontWeight: FontWeight.w900,
          fontSize: 18,
        ),
      ),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 470),
            child: Column(
              children: [
                _banner(),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(29),
                    border: Border.all(color: authBorder),
                    boxShadow: [
                      BoxShadow(
                        color: authDarkBlue.withValues(alpha: 0.045),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: AutofillGroup(
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _sent
                                ? 'Шинэ нууц үг тохируулах'
                                : 'Нууц үг сэргээх',
                            style: const TextStyle(
                              color: authDarkBlue,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            _sent
                                ? 'Имэйлд ирсэн код болон шинэ нууц үгээ оруулна уу.'
                                : 'Бүртгэлтэй имэйл хаягаа оруулж сэргээх код авна уу.',
                            style: const TextStyle(
                              color: Color(0xFF7C8EAA),
                              fontSize: 12,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 22),
                          _label('Имэйл хаяг'),
                          TextFormField(
                            controller: _email,
                            enabled: !_busy && !_sent,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: _decoration(
                              'example@email.com',
                              Icons.mail_outline_rounded,
                            ),
                            autocorrect: false,
                            textInputAction: _sent
                                ? TextInputAction.next
                                : TextInputAction.done,
                            onFieldSubmitted: (_) {
                              if (!_sent) _submit();
                            },
                            validator: (value) =>
                                (value ?? '').trim().length <= 254 &&
                                    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                        .hasMatch((value ?? '').trim())
                                ? null
                                : 'Зөв имэйл оруулна уу.',
                          ),
                          if (_sent) ...[
                            const SizedBox(height: 16),
                            _label('Баталгаажуулах код'),
                            TextFormField(
                              controller: _code,
                              enabled: !_busy,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              autofillHints: const [AutofillHints.oneTimeCode],
                              decoration: _decoration(
                                '6 оронтой код',
                                Icons.verified_outlined,
                              ),
                              textInputAction: TextInputAction.next,
                              validator: (value) =>
                                  RegExp(r'^[0-9]{6}$').hasMatch(value ?? '')
                                  ? null
                                  : '6 оронтой код оруулна уу.',
                            ),
                            const SizedBox(height: 12),
                            _label('Шинэ нууц үг'),
                            TextFormField(
                              controller: _password,
                              enabled: !_busy,
                              obscureText: _hide,
                              autocorrect: false,
                              enableSuggestions: false,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newPassword],
                              decoration:
                                  _decoration(
                                    '8-аас дээш тэмдэгт',
                                    Icons.lock_outline_rounded,
                                  ).copyWith(
                                    suffixIcon: _visibility(
                                      _hide,
                                      () => setState(() => _hide = !_hide),
                                    ),
                                  ),
                              validator: (value) =>
                                  (value ?? '').length >= 8 &&
                                      (value ?? '').length <= 128
                                  ? null
                                  : '8–128 тэмдэгттэй нууц үг оруулна уу.',
                            ),
                            const SizedBox(height: 16),
                            _label('Нууц үг давтах'),
                            TextFormField(
                              controller: _confirm,
                              enabled: !_busy,
                              obscureText: _hideConfirm,
                              autocorrect: false,
                              enableSuggestions: false,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              autofillHints: const [AutofillHints.newPassword],
                              decoration:
                                  _decoration(
                                    'Нууц үгээ дахин оруулна уу',
                                    Icons.verified_user_outlined,
                                  ).copyWith(
                                    suffixIcon: _visibility(
                                      _hideConfirm,
                                      () => setState(
                                        () => _hideConfirm = !_hideConfirm,
                                      ),
                                    ),
                                  ),
                              validator: (value) => value == _password.text
                                  ? null
                                  : 'Нууц үг таарахгүй байна.',
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: authBlue,
                              ),
                              onPressed: _busy
                                  ? null
                                  : () => _submit(resend: true),
                              child: const Text(
                                'Код дахин авах (60 секундийн дараа)',
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: authBlue,
                              ),
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
                          if (_message != null) _notice(_message!, false),
                          if (_error != null) _notice(_error!, true),
                          const SizedBox(height: 24),
                          Container(
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.forest,
                                  AppColors.primary,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: authBlue.withValues(alpha: 0.24),
                                  blurRadius: 15,
                                  offset: const Offset(0, 7),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _busy ? null : () => _submit(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                disabledBackgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: _busy
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _sent
                                              ? Icons.lock_reset_rounded
                                              : Icons.mail_outline_rounded,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 9),
                                        Text(
                                          _sent
                                              ? 'Нууц үг шинэчлэх'
                                              : 'Код авах',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(width: 7),
                                        const Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 18,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => Navigator.maybePop(context),
                            style: TextButton.styleFrom(
                              foregroundColor: authBlue,
                            ),
                            child: const Text(
                              'Нэвтрэх хэсэгт буцах',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  '💙 Сайн үйлсэд хамтдаа!',
                  style: TextStyle(
                    color: Color(0xFF8295B2),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _banner() => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(23, 24, 23, 23),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.softGreen, AppColors.background, AppColors.pale],
      ),
      borderRadius: BorderRadius.circular(29),
      border: Border.all(color: Colors.white, width: 2),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(25),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, color: authBlue, size: 16),
              SizedBox(width: 6),
              Text(
                'VOLUNTEER HUB',
                style: TextStyle(
                  color: authBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _sent ? 'Шинэ нууц үг,\nшинэ эхлэл. 💙' : 'Нууц үгээ\nмартсан уу? 💙',
          style: const TextStyle(
            color: authDarkBlue,
            fontSize: 29,
            fontWeight: FontWeight.w900,
            height: 1.22,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 11),
        const Text(
          'Бүртгэлээ сэргээгээд сайн үйлсийн аяллаа үргэлжлүүлээрэй.',
          style: TextStyle(color: Color(0xFF647D9F), fontSize: 13, height: 1.7),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    color: authBlue,
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _sent ? 'Шинэ нууц үг' : 'Имэйл баталгаажуулах',
                    style: const TextStyle(
                      color: authDarkBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            const Icon(Icons.lock_reset_rounded, color: authBlue, size: 37),
          ],
        ),
      ],
    ),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text.rich(
      TextSpan(
        text: text,
        style: const TextStyle(
          color: authDarkBlue,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(color: Color(0xFFFF7596)),
          ),
        ],
      ),
    ),
  );

  Widget _visibility(bool hidden, VoidCallback toggle) => IconButton(
    tooltip: hidden ? 'Нууц үг харах' : 'Нууц үг нуух',
    onPressed: _busy ? null : toggle,
    icon: Icon(
      hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      color: const Color(0xFF8295B2),
    ),
  );

  Widget _notice(String text, bool error) => Container(
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: error ? const Color(0xFFFFF2F3) : AppColors.softGreen,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          error ? Icons.error_outline_rounded : Icons.info_outline_rounded,
          color: error ? const Color(0xFFD94A5A) : authBlue,
          size: 20,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: error ? const Color(0xFFB63E4D) : authDarkBlue,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );

  InputDecoration _decoration(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF9AAAC2), fontSize: 12),
    prefixIcon: Icon(icon, color: authBlue, size: 21),
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(17),
      borderSide: const BorderSide(color: authBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(17),
      borderSide: const BorderSide(color: authBorder),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(17),
      borderSide: const BorderSide(color: authBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(17),
      borderSide: const BorderSide(color: authBlue, width: 1.6),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(17),
      borderSide: const BorderSide(color: Color(0xFFE76F7D)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(17),
      borderSide: const BorderSide(color: Color(0xFFE76F7D), width: 1.5),
    ),
    errorStyle: const TextStyle(fontSize: 11),
  );
}
