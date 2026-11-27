import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'auth_controller.dart';
import 'auth_models.dart';
import 'auth_validation.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  String? _notice;
  String? _error;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthController>();
    if (auth.busy || !_form.currentState!.validate()) return;
    setState(() {
      _error = null;
      _notice = null;
    });
    try {
      await auth.login(_identifier.text.trim(), _password.text);
      if (auth.phase == AuthPhase.signedIn) {
        TextInput.finishAutofillContext(shouldSave: true);
      }
    } on Exception catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    }
  }

  Future<void> _register() async {
    final email = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const RegisterScreen()));
    if (!mounted || email == null) return;
    _identifier.text = email;
    _password.clear();
    setState(() {
      _error = null;
      _notice = 'Tạo tài khoản thành công. Bạn có thể đăng nhập.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return _AuthPage(
      title: 'Đăng nhập',
      child: AutofillGroup(
        onDisposeAction: AutofillContextAction.cancel,
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if ((_error ?? _notice ?? auth.message) case final status?)
                _FormMessage(status, isError: _error != null),
              TextFormField(
                controller: _identifier,
                decoration: const InputDecoration(
                  labelText: 'Email hoặc username',
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                enabled: !auth.busy,
                autocorrect: false,
                validator: validateIdentifier,
              ),
              const SizedBox(height: 16),
              _PasswordField(
                controller: _password,
                enabled: !auth.busy,
                autofillHint: AutofillHints.password,
                validator: validatePassword,
                onSubmit: _submit,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: auth.busy ? null : _submit,
                child: Text(auth.busy ? 'Đang đăng nhập…' : 'Đăng nhập'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: auth.busy ? null : _register,
                child: const Text('Tạo tài khoản'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _displayName = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _displayName.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_form.currentState!.validate()) return;
    final api = context.read<AuthController>().api;
    final email = _email.text.trim().toLowerCase();
    final displayName = _displayName.text.trim();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await api.register(
        Registration(
          username: _username.text.trim().toLowerCase(),
          email: email,
          displayName: displayName.isEmpty ? null : displayName,
          password: _password.text,
        ),
      );
      if (mounted) Navigator.of(context).pop(email);
    } on Exception catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthPage(
    title: 'Đăng ký',
    child: AutofillGroup(
      onDisposeAction: AutofillContextAction.cancel,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error case final error?) _FormMessage(error, isError: true),
            TextFormField(
              controller: _username,
              decoration: const InputDecoration(labelText: 'Username'),
              textInputAction: TextInputAction.next,
              enabled: !_submitting,
              autocorrect: false,
              autofillHints: const [AutofillHints.newUsername],
              validator: validateUsername,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              enabled: !_submitting,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              validator: validateEmail,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _displayName,
              decoration: const InputDecoration(
                labelText: 'Tên hiển thị (tùy chọn)',
              ),
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              enabled: !_submitting,
              validator: validateDisplayName,
            ),
            const SizedBox(height: 16),
            _PasswordField(
              controller: _password,
              enabled: !_submitting,
              autofillHint: AutofillHints.newPassword,
              validator: validatePassword,
              onSubmit: _submit,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? 'Đang tạo tài khoản…' : 'Đăng ký'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AuthPage extends StatelessWidget {
  const _AuthPage({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Neuro Play')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: 24),
                child,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.controller,
    required this.enabled,
    required this.autofillHint,
    required this.validator,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool enabled;
  final String autofillHint;
  final FormFieldValidator<String> validator;
  final VoidCallback onSubmit;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    decoration: InputDecoration(
      labelText: 'Mật khẩu',
      suffixIcon: IconButton(
        tooltip: _hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
        icon: Icon(
          _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
        onPressed: widget.enabled
            ? () => setState(() => _hidden = !_hidden)
            : null,
      ),
    ),
    enabled: widget.enabled,
    obscureText: _hidden,
    autocorrect: false,
    enableSuggestions: false,
    autofillHints: [widget.autofillHint],
    textInputAction: TextInputAction.done,
    onFieldSubmitted: (_) => widget.onSubmit(),
    validator: widget.validator,
  );
}

class _FormMessage extends StatelessWidget {
  const _FormMessage(this.message, {required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Semantics(
        liveRegion: true,
        child: Text(
          message,
          style: TextStyle(color: isError ? colors.error : colors.primary),
        ),
      ),
    );
  }
}
