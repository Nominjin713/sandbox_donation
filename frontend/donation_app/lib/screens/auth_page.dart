
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

const Color authBlue = Color(0xFF4389F5);
const Color authDarkBlue = Color(0xFF19345C);
const Color authBackground = Color(0xFFF4F8FF);
const Color authBorder = Color(0xFFE3EDFC);

class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    this.authService,
    this.register = false,
  });

  final AuthService? authService;
  final bool register;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late final AuthService _authService =
      widget.authService ?? AuthService();

  final _form = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  late bool _register = widget.register;

  bool _busy = false;
  bool _hide = true;
  bool _hideConfirm = true;

  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _email,
      _password,
      _confirm,
    ]) {
      controller.dispose();
    }

    if (widget.authService == null) {
      _authService.close();
    }

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
              name: _name.text.trim(),
              email: _email.text.trim(),
              password: _password.text,
            )
          : await _authService.login(
              email: _email.text.trim(),
              password: _password.text,
            );

      if (!mounted) return;

      Navigator.of(context).pop(session);
    } on AuthException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Алдаа гарлаа. Дахин оролдоно уу.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: authBackground,
      appBar: AppBar(
        backgroundColor: authBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: IconButton(
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
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 470),
                  child: Column(
                    children: [
                      _buildWelcomeBanner(),
                      const SizedBox(height: 20),
                      _buildAuthCard(),
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(23, 24, 23, 23),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE0EDFF),
            Color(0xFFF0F6FF),
            Color(0xFFE5F5FF),
          ],
        ),
        borderRadius: BorderRadius.circular(29),
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.88),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: authBlue,
                  size: 16,
                ),
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
            _register
                ? 'Сайн үйлсэд\nнэгдээрэй! 💙'
                : 'Тавтай морил!\nДахин уулзлаа.',
            style: const TextStyle(
              color: authDarkBlue,
              fontSize: 29,
              fontWeight: FontWeight.w900,
              height: 1.22,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 11),
          Text(
            _register
                ? 'Шинэ бүртгэл үүсгээд бусдад туслах аяллаа эхлүүлээрэй.'
                : 'Нэвтэрч, өөрийн сонирхолд тохирох сайн дурын ажлуудаа олоорой.',
            style: const TextStyle(
              color: Color(0xFF647D9F),
              fontSize: 13,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _welcomeTag(
                Icons.favorite_rounded,
                'Сайн үйлс',
              ),
              const SizedBox(width: 9),
              _welcomeTag(
                Icons.groups_rounded,
                'Нэгдэл',
              ),
              const Spacer(),
              const Icon(
                Icons.volunteer_activism_rounded,
                color: authBlue,
                size: 37,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _welcomeTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: authBlue, size: 15),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: authDarkBlue,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(29),
        border: Border.all(color: authBorder),
        boxShadow: [
          BoxShadow(
            color: authDarkBlue.withOpacity(0.045),
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
              _buildModeSelector(),
              const SizedBox(height: 23),

              Text(
                _register
                    ? 'Шинэ бүртгэл үүсгэх'
                    : 'Бүртгэлдээ нэвтрэх',
                style: const TextStyle(
                  color: authDarkBlue,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                _register
                    ? 'Мэдээллээ оруулаад бүртгэлээ үүсгээрэй.'
                    : 'Имэйл болон нууц үгээ оруулна уу.',
                style: const TextStyle(
                  color: Color(0xFF7C8EAA),
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 22),

              if (_register) ...[
                _fieldLabel('Таны нэр'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _name,
                  enabled: !_busy,
                  maxLength: 100,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: _decoration(
                    hint: 'Нэрээ оруулна уу',
                    icon: Icons.person_outline_rounded,
                  ).copyWith(
                    counterText: '',
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Нэрээ оруулна уу.'
                          : null,
                ),
                const SizedBox(height: 17),
              ],

              _fieldLabel('Имэйл хаяг'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _email,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.email],
                decoration: _decoration(
                  hint: 'example@email.com',
                  icon: Icons.mail_outline_rounded,
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().length > 254 ||
                      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                          .hasMatch(value.trim())) {
                    return 'Зөв имэйл хаяг оруулна уу.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 17),

              _fieldLabel('Нууц үг'),
              const SizedBox(height: 8),
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
                decoration: _decoration(
                  hint: '8-аас дээш тэмдэгт',
                  icon: Icons.lock_outline_rounded,
                ).copyWith(
                  suffixIcon: IconButton(
                    tooltip: _hide
                        ? 'Нууц үг харах'
                        : 'Нууц үг нуух',
                    onPressed: () {
                      setState(() => _hide = !_hide);
                    },
                    icon: Icon(
                      _hide
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: const Color(0xFF8295B2),
                    ),
                  ),
                ),
                validator: (value) =>
                    value == null ||
                            value.length < 8 ||
                            value.length > 128
                        ? '8–128 тэмдэгттэй нууц үг оруулна уу.'
                        : null,
                onFieldSubmitted: (_) {
                  if (!_busy && !_register) _submit();
                },
              ),

              if (_register) ...[
                const SizedBox(height: 17),
                _fieldLabel('Нууц үг давтах'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirm,
                  enabled: !_busy,
                  obscureText: _hideConfirm,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: _decoration(
                    hint: 'Нууц үгээ дахин оруулна уу',
                    icon: Icons.verified_user_outlined,
                  ).copyWith(
                    suffixIcon: IconButton(
                      tooltip: _hideConfirm
                          ? 'Нууц үг харах'
                          : 'Нууц үг нуух',
                      onPressed: () {
                        setState(() {
                          _hideConfirm = !_hideConfirm;
                        });
                      },
                      icon: Icon(
                        _hideConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: const Color(0xFF8295B2),
                      ),
                    ),
                  ),
                  validator: (value) => value != _password.text
                      ? 'Нууц үг таарахгүй байна.'
                      : null,
                  onFieldSubmitted: (_) {
                    if (!_busy) _submit();
                  },
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F0),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: const Color(0xFFFFD6D6),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFD94A5A),
                        size: 20,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFB63E4D),
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              _buildSubmitButton(),
              const SizedBox(height: 15),

              Center(
                child: TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          setState(() {
                            _register = !_register;
                            _hide = true;
                            _hideConfirm = true;
                            _error = null;
                            _name.clear();
                            _email.clear();
                            _password.clear();
                            _confirm.clear();
                            _form.currentState?.reset();
                          });
                        },
                  style: TextButton.styleFrom(
                    foregroundColor: authBlue,
                  ),
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 12),
                      children: [
                        TextSpan(
                          text: _register
                              ? 'Бүртгэлтэй юу? '
                              : 'Бүртгэлгүй юу? ',
                          style: const TextStyle(
                            color: Color(0xFF7C8EAA),
                          ),
                        ),
                        TextSpan(
                          text: _register
                              ? 'Нэвтрэх'
                              : 'Бүртгүүлэх',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: authBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5FF),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          _modeButton('Нэвтрэх', false),
          _modeButton('Бүртгүүлэх', true),
        ],
      ),
    );
  }

  Widget _modeButton(String label, bool registerMode) {
    final selected = _register == registerMode;

    return Expanded(
      child: GestureDetector(
        onTap: _busy
            ? null
            : () {
                if (_register == registerMode) return;

                setState(() {
                  _register = registerMode;
                  _hide = true;
                  _hideConfirm = true;
                  _error = null;
                  _name.clear();
                  _email.clear();
                  _password.clear();
                  _confirm.clear();
                  _form.currentState?.reset();
                });
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: authDarkBlue.withOpacity(0.06),
                      blurRadius: 9,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected
                  ? authBlue
                  : const Color(0xFF8295B2),
              fontSize: 12,
              fontWeight:
                  selected ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: authDarkBlue,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            '*',
            style: TextStyle(
              color: Color(0xFFFF7596),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF9AAAC2),
        fontSize: 12,
      ),
      prefixIcon: Icon(
        icon,
        color: authBlue,
        size: 21,
      ),
      filled: true,
      fillColor: const Color(0xFFFAFCFF),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: authBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: authBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(
          color: authBlue,
          width: 1.6,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(
          color: Color(0xFFE76F7D),
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(
          color: Color(0xFFE76F7D),
          width: 1.5,
        ),
      ),
      errorStyle: const TextStyle(fontSize: 11),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF68A6FF),
            Color(0xFF4389F5),
            Color(0xFF326EF0),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: authBlue.withOpacity(0.24),
            blurRadius: 15,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _busy ? null : _submit,
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _register
                        ? Icons.person_add_alt_1_rounded
                        : Icons.login_rounded,
                    size: 20,
                  ),
                  const SizedBox(width: 9),
                  Text(
                    _register ? 'Бүртгэл үүсгэх' : 'Нэвтрэх',
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
    );
  }
}
