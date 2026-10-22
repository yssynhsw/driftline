import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'countries.dart';
import 'photo.dart';
import 'store.dart';
import 'theme.dart';

const Color _danger = Color(0xFFD92D20);

const List<String> _languages = <String>[
  'English',
  'French',
  'Arabic',
  'Spanish',
];

const List<String> _tastes = <String>[
  'Beach',
  'City',
  'Mountains',
  'Food',
  'Culture',
];

const List<String> _photos = <String>[
  '#121212',
  '#D7EFE6',
  '#F3D392',
  '#E8DDF6',
  '#1F9D62',
];

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.onSignedIn});

  final ValueChanged<AppUser> onSignedIn;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

enum _Step { signIn, signUp, verify, forgot, pin, reactivate }

class _AuthPageState extends State<AuthPage> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _prenom = TextEditingController();
  final TextEditingController _nom = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _code = TextEditingController();
  final TextEditingController _pin = TextEditingController();
  final TextEditingController _newPassword = TextEditingController();

  _Step _step = _Step.signIn;
  bool _remember = false;
  bool _busy = false;
  bool _hideSecret = true;
  bool _inboxOpen = false;
  String? _pending;
  String? _error;
  String? _errorAt;
  String? _notice;
  String? _inboxCode;
  String? _resetCode;
  String _pays = 'Morocco';
  String _langue = 'English';
  String _photo = '#F3D392';
  final Set<String> _prefs = <String>{};

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _prenom.dispose();
    _nom.dispose();
    _phone.dispose();
    _code.dispose();
    _pin.dispose();
    _newPassword.dispose();
    super.dispose();
  }

  String _partOfDay() {
    final int hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning.';
    }
    if (hour < 18) {
      return 'Good afternoon.';
    }
    return 'Good evening.';
  }

  void _go(_Step step) {
    if (_busy) {
      return;
    }
    setState(() {
      _step = step;
      _error = null;
      _errorAt = null;
      _notice = null;
      if (step != _Step.forgot) {
        _resetCode = null;
        _newPassword.clear();
      }
    });
  }

  Future<void> _run(String key, Future<void> Function() body) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _pending = key;
      _error = null;
      _errorAt = key;
      _notice = null;
    });
    try {
      await body();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _pending = null;
        });
      }
    }
  }

  void _fail(String anchor, String message) {
    setState(() {
      _error = message;
      _errorAt = anchor;
    });
  }

  void _consume(AuthResult result) {
    final String? error = result.error;
    if (error == null) {
      final AppUser? user = result.user;
      if (user == null) {
        _fail('signIn', 'Could not sign in.');
        return;
      }
      widget.onSignedIn(user);
      return;
    }
    setState(() {
      _errorAt = _pending ?? 'signIn';
      if (error == '2fa') {
        _step = _Step.pin;
        _pin.clear();
        _error = null;
        return;
      }
      if (error == 'unverified') {
        _step = _Step.verify;
        _code.clear();
        final String? code = result.code;
        if (code != null && code.isNotEmpty) {
          _inboxCode = code;
          _inboxOpen = true;
        } else {
          _inboxOpen = false;
        }
        _error = null;
        return;
      }
      if (error == 'deactivated') {
        _step = _Step.reactivate;
        _error = null;
        return;
      }
      _error = error;
    });
  }

  Future<void> _submitSignIn() async {
    final String email = _email.text.trim();
    if (!email.contains('@') || _password.text.isEmpty) {
      _fail('signIn', 'Enter your email and password.');
      return;
    }
    await _run('signIn', () async {
      final AuthResult result = await UserStore.instance.signIn(
        email: _email.text.trim(),
        password: _password.text,
        remember: _remember,
        pin: null,
      );
      if (!mounted) {
        return;
      }
      _consume(result);
    });
  }

  Future<void> _submitPin() async {
    final String pin = _pin.text.trim();
    if (pin.length != 4) {
      _fail('pin', 'Enter the 4-digit PIN.');
      return;
    }
    await _run('pin', () async {
      final AuthResult result = await UserStore.instance.signIn(
        email: _email.text.trim(),
        password: _password.text,
        remember: _remember,
        pin: pin,
      );
      if (!mounted) {
        return;
      }
      _consume(result);
    });
  }

  Future<void> _submitRegister() async {
    if (_prenom.text.trim().isEmpty || _nom.text.trim().isEmpty) {
      _fail('register', 'Enter your prénom and nom.');
      return;
    }
    if (!_email.text.trim().contains('@')) {
      _fail('register', 'Enter a valid email.');
      return;
    }
    if (_password.text.length < 8) {
      _fail('register', 'Password must be at least 8 characters.');
      return;
    }
    if (_phone.text.trim().replaceAll(RegExp(r'\D'), '').length < 8) {
      _fail('register', 'Enter a valid phone number.');
      return;
    }
    if (_prefs.isEmpty) {
      _fail('register', 'Choose at least one travel preference.');
      return;
    }
    await _run('register', () async {
      final AuthResult result = await UserStore.instance.register(
        nom: _nom.text.trim(),
        prenom: _prenom.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        pays: _pays,
        langue: _langue,
        preferences: _prefs.join(', '),
        photoProfil: _photo,
        phone: _phone.text.trim(),
      );
      if (!mounted) {
        return;
      }
      if (result.error == 'unverified') {
        setState(() {
          _step = _Step.verify;
          _code.clear();
          _inboxCode = result.code;
          _inboxOpen = result.code != null && result.code!.isNotEmpty;
          _error = null;
        });
        return;
      }
      if (result.error != null) {
        setState(() => _error = result.error);
        return;
      }
      final AppUser? user = result.user;
      if (user != null) {
        widget.onSignedIn(user);
      }
    });
  }

  Future<void> _submitVerify() async {
    final String code = _code.text.trim();
    if (code.length != 6) {
      _fail('verify', 'Enter the 6-digit code.');
      return;
    }
    await _run('verify', () async {
      final AuthResult result = await UserStore.instance.verifyEmail(
        email: _email.text.trim(),
        code: code,
      );
      if (!mounted) {
        return;
      }
      if (result.error != null) {
        setState(() => _error = result.error);
        return;
      }
      final AuthResult signed = await UserStore.instance.signIn(
        email: _email.text.trim(),
        password: _password.text,
        remember: _remember,
      );
      if (!mounted) {
        return;
      }
      _consume(signed);
    });
  }

  Future<void> _resend() async {
    await _run('resend', () async {
      final AuthResult result = await UserStore.instance.resendEmailCode(
        _email.text.trim(),
      );
      if (!mounted) {
        return;
      }
      if (result.code == null || result.code!.isEmpty) {
        setState(() => _error = result.error ?? 'Could not issue a code.');
        return;
      }
      setState(() {
        _inboxCode = result.code;
        _inboxOpen = true;
        _error = null;
      });
    });
  }

  Future<void> _sendReset() async {
    await _run('reset', () async {
      final AuthResult result = await UserStore.instance.requestReset(
        _email.text.trim(),
      );
      if (!mounted) {
        return;
      }
      if (result.error != null) {
        setState(() => _error = result.error);
        return;
      }
      final String? code = result.code;
      if (code == null || code.isEmpty) {
        _fail('reset', 'No code in the local inbox.');
        return;
      }
      setState(() {
        _resetCode = code;
        _error = null;
      });
    });
  }

  Future<void> _submitNewPassword() async {
    final String? code = _resetCode;
    if (code == null) {
      return;
    }
    await _run('reset', () async {
      final AuthResult result = await UserStore.instance.resetPassword(
        email: _email.text.trim(),
        code: code,
        password: _newPassword.text,
      );
      if (!mounted) {
        return;
      }
      if (result.error != null) {
        setState(() => _error = result.error);
        return;
      }
      setState(() {
        _step = _Step.signIn;
        _resetCode = null;
        _newPassword.clear();
        _password.clear();
        _notice = 'Password updated. Sign in to continue.';
        _error = null;
      });
    });
  }

  Future<void> _submitReactivate() async {
    await _run('reactivate', () async {
      final AuthResult result = await UserStore.instance.reactivate(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) {
        return;
      }
      if (result.error != null) {
        setState(() => _error = result.error);
        return;
      }
      setState(() {
        _step = _Step.signIn;
        _notice = 'Account reactivated. Sign in to continue.';
        _error = null;
      });
    });
  }

  Future<void> _pendingProvider(String provider) async {
    final AuthResult result = await UserStore.instance.signInWithProvider(
      provider,
    );
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: kBg,
          title: Text(provider),
          content: Text(result.error ?? 'This provider is not configured.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _toggleSecret() {
    setState(() => _hideSecret = !_hideSecret);
  }

  void _toggleTaste(String taste) {
    if (_busy) {
      return;
    }
    setState(() {
      if (_prefs.contains(taste)) {
        _prefs.remove(taste);
      } else {
        _prefs.add(taste);
      }
    });
  }

  Future<void> _pickSignupPhoto(ImageSource source) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _pending = 'photo';
      _error = null;
    });
    try {
      final String? next = await captureProfilePhoto(context, source);
      if (!mounted || next == null) {
        return;
      }
      setState(() => _photo = next);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error is StateError ? error.message : 'Could not use that photo.';
        _errorAt = 'register';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _pending = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: driftTheme(),
      child: Scaffold(
        backgroundColor: kCanvas,
        body: Stage(
          child: SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 340),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final Animation<Offset> slide = Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<_Step>(_step),
                  child: _stepBody(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case _Step.signIn:
        return _signIn();
      case _Step.signUp:
        return _signUp();
      case _Step.verify:
        return _verify();
      case _Step.forgot:
        return _forgot();
      case _Step.pin:
        return _pinStep();
      case _Step.reactivate:
        return _reactivate();
    }
  }

  Widget _signIn() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _top(),
        _heading('Hey there', _partOfDay()),
        const SizedBox(height: 22),
        _Panel(
          color: kMint,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _plainField(
                controller: _email,
                label: 'Email',
                hint: 'name@email.com',
                keyboard: TextInputType.emailAddress,
              ),
              const _Hairline(),
              _plainField(
                controller: _password,
                label: 'Password',
                hint: 'At least 8 characters',
                secret: true,
                obscure: _hideSecret,
                onToggle: _toggleSecret,
                keyboard: TextInputType.visiblePassword,
                action: TextInputAction.done,
                onSubmitted: (_) {
                  _submitSignIn();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _rememberRow(),
        Align(
          alignment: Alignment.centerRight,
          child: _link('Forgot password', () => _go(_Step.forgot)),
        ),
        const SizedBox(height: 6),
        _Pill(
          label: 'Sign in',
          background: kInk,
          foreground: kBg,
          busy: _pending == 'signIn',
          onTap: _busy ? null : _submitSignIn,
        ),
        _errorUnder('signIn'),
        const SizedBox(height: 12),
        const Text(
          'Social sign-in',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: kMute,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final String provider in <String>[
              'Google',
              'Apple',
              'Facebook',
              'Microsoft',
            ])
              _Pill(
                label: provider,
                background: kBg,
                foreground: kInk,
                border: const BorderSide(color: kLine),
                onTap: _busy ? null : () => _pendingProvider(provider),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Center(
          child: _linkRich('New here? ', 'Create account', () {
            _go(_Step.signUp);
          }),
        ),
      ],
    );
  }

  Widget _signUp() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _top(back: true),
        _heading(
          'Create account',
          'A few details, then a code on this device.',
        ),
        const SizedBox(height: 22),
        _Panel(
          color: kMint,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _plainField(
                      controller: _prenom,
                      label: 'Prénom',
                      hint: 'Sara',
                      capitalization: TextCapitalization.words,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _plainField(
                      controller: _nom,
                      label: 'Nom',
                      hint: 'Benali',
                      capitalization: TextCapitalization.words,
                    ),
                  ),
                ],
              ),
              const _Hairline(),
              _plainField(
                controller: _email,
                label: 'Email',
                hint: 'name@email.com',
                keyboard: TextInputType.emailAddress,
              ),
              const _Hairline(),
              _plainField(
                controller: _phone,
                label: 'Phone',
                hint: '+212 600 000 000',
                keyboard: TextInputType.phone,
              ),
              const _Hairline(),
              _plainField(
                controller: _password,
                label: 'Password',
                hint: 'At least 8 characters',
                secret: true,
                obscure: _hideSecret,
                onToggle: _toggleSecret,
                keyboard: TextInputType.visiblePassword,
                action: TextInputAction.done,
                onSubmitted: (_) {
                  _submitRegister();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Panel(
          color: kMint,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CountryField(
                value: _pays,
                onChanged: (String value) => setState(() => _pays = value),
              ),
              const _Hairline(),
              _menu(
                label: 'Langue',
                value: _langue,
                options: _languages,
                onChanged: (String value) => setState(() => _langue = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Préférences de voyage',
          style: TextStyle(
            color: kMute,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[for (final String taste in _tastes) _taste(taste)],
        ),
        const SizedBox(height: 18),
        const Text(
          'Photo de profil',
          style: TextStyle(
            color: kMute,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            ProfileAvatar(
              photo: _photo,
              initials: _prenom.text.trim().isEmpty
                  ? '?'
                  : _prenom.text.trim().substring(0, 1).toUpperCase(),
              radius: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _PhotoChoice(
                    label: 'Gallery',
                    onTap: _busy ? null : () => _pickSignupPhoto(ImageSource.gallery),
                  ),
                  _PhotoChoice(
                    label: 'Camera',
                    onTap: _busy ? null : () => _pickSignupPhoto(ImageSource.camera),
                  ),
                  if (isStoredPhoto(_photo))
                    _PhotoChoice(
                      label: 'Remove',
                      onTap: _busy
                          ? null
                          : () => setState(() => _photo = '#F3D392'),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            for (final String color in _photos) ...<Widget>[
              _PhotoDot(
                color: color,
                selected: _photo == color,
                onTap: _busy ? null : () => setState(() => _photo = color),
              ),
              const SizedBox(width: 10),
            ],
          ],
        ),
        const SizedBox(height: 18),
        _Pill(
          label: 'Create account',
          background: kInk,
          foreground: kBg,
          busy: _pending == 'register',
          onTap: _busy ? null : _submitRegister,
        ),
        _errorUnder('register'),
        const SizedBox(height: 14),
        Center(
          child: _linkRich('Already have an account? ', 'Sign in', () {
            _go(_Step.signIn);
          }),
        ),
      ],
    );
  }

  Widget _verify() {
    final String email = _email.text.trim();
    final String subtitle = email.isEmpty
        ? 'No email provider is configured. Enter the code issued by the local database.'
        : 'Enter the 6-digit code for $email.';
    final String? inbox = _inboxCode;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _top(back: true),
        _heading('Check inbox', subtitle),
        const SizedBox(height: 22),
        if (_inboxOpen && inbox != null && inbox.isNotEmpty) ...<Widget>[
          Center(child: _InboxPill(inbox)),
          const SizedBox(height: 16),
        ],
        _Panel(
          color: kMint,
          child: _plainField(
            controller: _code,
            label: 'Code',
            align: TextAlign.center,
            fontSize: 32,
            maxLength: 6,
            keyboard: TextInputType.number,
            action: TextInputAction.done,
            formatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            onSubmitted: (_) {
              _submitVerify();
            },
          ),
        ),
        const SizedBox(height: 16),
        _Pill(
          label: 'Confirm',
          background: kInk,
          foreground: kBg,
          busy: _pending == 'verify',
          onTap: _busy ? null : _submitVerify,
        ),
        _errorUnder('verify'),
        const SizedBox(height: 8),
        Center(child: _link('Resend', _resend)),
        _errorUnder('resend'),
      ],
    );
  }

  Widget _forgot() {
    final String? code = _resetCode;
    final String email = _email.text.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _top(back: true),
        _heading(
          'Forgot password',
          code == null
              ? 'No email provider is configured. A reset code is issued by the local database when the account exists.'
              : 'Choose a new password for $email.',
        ),
        const SizedBox(height: 22),
        if (code == null) ...<Widget>[
          _Panel(
            color: kMint,
            child: _plainField(
              controller: _email,
              label: 'Email',
              hint: 'name@email.com',
              keyboard: TextInputType.emailAddress,
              action: TextInputAction.done,
              onSubmitted: (_) {
                _sendReset();
              },
            ),
          ),
          const SizedBox(height: 16),
          _Pill(
            label: 'Send code',
            background: kInk,
            foreground: kBg,
            busy: _pending == 'reset',
            onTap: _busy ? null : _sendReset,
          ),
          _errorUnder('reset'),
        ] else ...<Widget>[
          Center(child: _InboxPill(code)),
          const SizedBox(height: 16),
          _Panel(
            color: kMint,
            child: _plainField(
              controller: _newPassword,
              label: 'New password',
              hint: 'At least 6 characters',
              secret: true,
              obscure: _hideSecret,
              onToggle: _toggleSecret,
              keyboard: TextInputType.visiblePassword,
              action: TextInputAction.done,
              onSubmitted: (_) {
                _submitNewPassword();
              },
            ),
          ),
          const SizedBox(height: 16),
          _Pill(
            label: 'Reset password',
            background: kInk,
            foreground: kBg,
            busy: _pending == 'reset',
            onTap: _busy ? null : _submitNewPassword,
          ),
          _errorUnder('reset'),
        ],
      ],
    );
  }

  Widget _pinStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _top(back: true, pill: '2FA'),
        _heading('Security code', 'Enter the 4-digit PIN for this account.'),
        const SizedBox(height: 22),
        _Panel(
          color: kInk,
          child: _plainField(
            controller: _pin,
            label: 'PIN',
            color: kBg,
            labelColor: const Color(0xB3F7F7F5),
            align: TextAlign.center,
            fontSize: 32,
            maxLength: 4,
            keyboard: TextInputType.number,
            action: TextInputAction.done,
            formatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            onSubmitted: (_) {
              _submitPin();
            },
          ),
        ),
        const SizedBox(height: 16),
        _Pill(
          label: 'Confirm',
          background: kInk,
          foreground: kBg,
          busy: _pending == 'pin',
          onTap: _busy ? null : _submitPin,
        ),
        _errorUnder('pin'),
      ],
    );
  }

  Widget _reactivate() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _top(back: true, pill: 'Paused'),
        _heading(
          'Welcome back',
          'This account is paused. Reactivate, then sign in.',
        ),
        const SizedBox(height: 22),
        _Panel(
          color: kMint,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _plainField(
                controller: _email,
                label: 'Email',
                hint: 'name@email.com',
                keyboard: TextInputType.emailAddress,
              ),
              const _Hairline(),
              _plainField(
                controller: _password,
                label: 'Password',
                secret: true,
                obscure: _hideSecret,
                onToggle: _toggleSecret,
                keyboard: TextInputType.visiblePassword,
                action: TextInputAction.done,
                onSubmitted: (_) {
                  _submitReactivate();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _Pill(
          label: 'Reactivate',
          background: kGold,
          foreground: kInk,
          busy: _pending == 'reactivate',
          onTap: _busy ? null : _submitReactivate,
        ),
        _errorUnder('reactivate'),
      ],
    );
  }

  Widget _top({bool back = false, String? pill}) {
    return Row(
      children: <Widget>[
        if (back) ...<Widget>[_backButton(), const SizedBox(width: 12)],
        const _Wordmark(),
        const Spacer(),
        if (pill != null) _GoldPill(pill),
      ],
    );
  }

  Widget _backButton() {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: kInk.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: kBg,
        shape: const CircleBorder(side: BorderSide(color: kLine)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _busy ? null : () => _go(_Step.signIn),
          child: const SizedBox(
            width: 42,
            height: 42,
            child: Icon(Icons.arrow_back_rounded, color: kInk, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _heading(String title, String subtitle) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 26),
        Text(
          title,
          style: const TextStyle(
            color: kInk,
            fontSize: 34,
            height: 1.05,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            color: kMute,
            fontSize: 15,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (_notice != null) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            _notice!,
            style: const TextStyle(
              color: kGreen,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  Widget _rememberRow() {
    return Row(
      children: <Widget>[
        const Expanded(
          child: Text(
            'Remember me',
            style: TextStyle(
              color: kInk,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Switch(
          value: _remember,
          activeThumbColor: kBg,
          activeTrackColor: kInk,
          inactiveThumbColor: kBg,
          inactiveTrackColor: kLine,
          onChanged: _busy
              ? null
              : (bool value) => setState(() => _remember = value),
        ),
      ],
    );
  }

  Widget _menu({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: kMute,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            borderRadius: BorderRadius.circular(20),
            dropdownColor: kBg,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kInk),
            style: const TextStyle(
              color: kInk,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            items: <DropdownMenuItem<String>>[
              for (final String option in options)
                DropdownMenuItem<String>(value: option, child: Text(option)),
            ],
            onChanged: _busy
                ? null
                : (String? next) {
                    if (next != null) {
                      onChanged(next);
                    }
                  },
          ),
        ),
      ],
    );
  }

  Widget _taste(String taste) {
    final bool selected = _prefs.contains(taste);
    return Material(
      color: selected ? kLilac : kBg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: _busy ? null : () => _toggleTaste(taste),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? kLilac : kLine),
          ),
          child: Text(
            taste,
            style: const TextStyle(
              color: kInk,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _link(String label, VoidCallback onTap) {
    return TextButton(
      onPressed: _busy ? null : onTap,
      style: TextButton.styleFrom(
        foregroundColor: kInk,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _linkRich(String prefix, String action, VoidCallback onTap) {
    return TextButton(
      onPressed: _busy ? null : onTap,
      style: TextButton.styleFrom(
        foregroundColor: kInk,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 14, color: kMute),
          children: <InlineSpan>[
            TextSpan(text: prefix),
            TextSpan(
              text: action,
              style: const TextStyle(color: kInk, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorUnder(String anchor) {
    final String? error = _error;
    if (error == null || _errorAt != anchor) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        error,
        style: const TextStyle(
          color: _danger,
          fontSize: 13,
          height: 1.3,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return const DriftlineMark();
  }
}

class _GoldPill extends StatelessWidget {
  const _GoldPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: kGold,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: kInk,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InboxPill extends StatelessWidget {
  const _InboxPill(this.code);

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kLilac,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text(
            'Local inbox',
            style: TextStyle(
              color: kInk,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            code,
            style: const TextStyle(
              color: kInk,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: gradientFor(color),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: color == kInk ? const Color(0x2EFFFFFF) : const Color(0xB3FFFFFF),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: kInk.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.only(bottom: 8),
      color: kInk.withValues(alpha: 0.08),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.onTap,
    required this.background,
    required this.foreground,
    this.busy = false,
    this.border,
  });

  final String label;
  final VoidCallback? onTap;
  final Color background;
  final Color foreground;
  final bool busy;
  final BorderSide? border;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null && !busy;
    return Opacity(
      opacity: enabled || busy ? 1 : 0.42,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Ink(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: border == null ? null : Border.fromBorderSide(border!),
            ),
            child: Center(
              child: busy
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: foreground,
                      ),
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _plainField({
  required TextEditingController controller,
  required String label,
  String hint = '',
  bool secret = false,
  bool obscure = false,
  VoidCallback? onToggle,
  TextInputType keyboard = TextInputType.text,
  TextInputAction action = TextInputAction.next,
  ValueChanged<String>? onSubmitted,
  List<TextInputFormatter>? formatters,
  int? maxLength,
  TextAlign align = TextAlign.start,
  double fontSize = 18,
  Color color = kInk,
  Color labelColor = kMute,
  TextCapitalization capitalization = TextCapitalization.none,
}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        label,
        style: TextStyle(
          color: labelColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      TextField(
        controller: controller,
        obscureText: secret && obscure,
        keyboardType: keyboard,
        textInputAction: action,
        textCapitalization: capitalization,
        textAlign: align,
        onSubmitted: onSubmitted,
        inputFormatters: formatters,
        maxLength: maxLength,
        autocorrect: false,
        enableSuggestions: !secret,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        cursorColor: color,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: maxLength == null ? 0 : 6,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: labelColor.withValues(alpha: 0.85),
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
            fontSize: 16,
          ),
          counterText: '',
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          suffixIcon: onToggle == null
              ? null
              : IconButton(
                  onPressed: onToggle,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    secret && obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: labelColor,
                    size: 20,
                  ),
                ),
        ),
      ),
    ],
  );
}

class _PhotoChoice extends StatelessWidget {
  const _PhotoChoice({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kLine),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: kInk,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoDot extends StatelessWidget {
  const _PhotoDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color fill = _parse(color);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? kInk : kLine,
            width: selected ? 2.5 : 1,
          ),
        ),
      ),
    );
  }

  Color _parse(String hex) {
    final String raw = hex.replaceFirst('#', '');
    return Color(int.parse('FF$raw', radix: 16));
  }
}
