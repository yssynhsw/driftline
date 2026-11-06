import 'package:flutter/material.dart';

import 'src/auth_page.dart';
import 'src/relay_host.dart';
import 'src/shell.dart';
import 'src/store.dart';
import 'src/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ensureRelay();
  runApp(const DriftlineApp());
}

class DriftlineApp extends StatefulWidget {
  const DriftlineApp({super.key});

  @override
  State<DriftlineApp> createState() => _DriftlineAppState();
}

class _DriftlineAppState extends State<DriftlineApp> {
  AppUser? _user;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    AppUser? user;
    try {
      await UserStore.instance.open();
      user = await UserStore.instance.restore();
    } catch (_) {
      user = null;
    }
    if (!mounted) return;
    setState(() {
      _user = user;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget home;
    if (!_ready) {
      home = const _Boot();
    } else if (_user == null) {
      home = AuthPage(onSignedIn: (AppUser user) => setState(() => _user = user));
    } else {
      home = AppShell(
        user: _user!,
        onUser: (AppUser user) => setState(() => _user = user),
        onSignedOut: () => setState(() => _user = null),
      );
    }

    return MaterialApp(
      title: 'Driftline',
      debugShowCheckedModeBanner: false,
      theme: driftTheme(),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(
          key: ValueKey<String>(_ready ? (_user == null ? 'auth' : 'app') : 'boot'),
          child: home,
        ),
      ),
    );
  }
}

class _Boot extends StatelessWidget {
  const _Boot();

  @override
  Widget build(BuildContext context) {
    return const Stage(
      child: Center(child: DriftlineMark(size: 64)),
    );
  }
}
