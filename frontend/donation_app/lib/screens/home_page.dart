import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'auth_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.authService});
  final AuthService? authService;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final AuthService _service = widget.authService ?? AuthService();
  AuthSession? _session;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    if (widget.authService == null) _service.close();
    super.dispose();
  }

  Future<void> _openAuth(bool register) async {
    final session = await Navigator.of(context).push<AuthSession>(
      MaterialPageRoute(
        builder: (_) => AuthPage(authService: _service, register: register),
      ),
    );
    if (mounted && session != null) {
      setState(() {
        _session = session;
        _error = null;
      });
    }
  }

  Future<void> _logout() async {
    if (_busy || _session == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.logout(_session!.token);
      if (mounted) setState(() => _session = null);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Хандив'), centerTitle: false),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.volunteer_activism,
                      size: 72,
                      color: Color(0xFF087F6B),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _session == null
                          ? 'Сайн үйлсэд хамтдаа'
                          : 'Тавтай морил!',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _session == null
                          ? 'Сайн дурын оролцоогоор нийгэмдээ хувь нэмэр оруулах эхний алхмаа хийгээрэй.'
                          : '${_session!.name}\n${_session!.email}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 32),
                    if (_session == null) ...[
                      FilledButton(
                        onPressed: () => _openAuth(false),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Нэвтрэх'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => _openAuth(true),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Бүртгүүлэх'),
                        ),
                      ),
                    ] else
                      FilledButton(
                        onPressed: _busy ? null : _logout,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Гарах'),
                        ),
                      ),
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
