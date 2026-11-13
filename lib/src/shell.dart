import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'admin_page.dart';
import 'countries.dart';
import 'guide.dart';
import 'photo.dart';
import 'store.dart';
import 'theme.dart';
import 'trips/screens/trips_list_screen.dart';

const List<String> _preferenceCatalog = <String>[
  'Beach',
  'Mountains',
  'City',
  'Culture',
  'Food',
  'Adventure',
  'Nature',
  'Road trip',
];

const TextStyle _display = TextStyle(
  fontFamily: kFont,
  fontVariations: kReading,
  color: kInk,
  fontSize: 32,
  height: 1.15,
  fontWeight: FontWeight.w700,
);

const TextStyle _quiet = TextStyle(
  fontFamily: kFont,
  fontVariations: kReading,
  color: kMute,
  fontSize: 15,
  height: 1.35,
);

const TextStyle _huge = TextStyle(
  fontFamily: kFont,
  fontVariations: kReading,
  color: kInk,
  fontSize: 48,
  height: 1.05,
  fontWeight: FontWeight.w700,
);

const EdgeInsets _pagePadding = EdgeInsets.fromLTRB(22, 8, 48, 128);

String _greeting(DateTime now) {
  final int hour = now.hour;
  if (hour < 12) {
    return 'Good morning';
  }
  if (hour < 18) {
    return 'Good afternoon';
  }
  return 'Good evening';
}

IconData _greetingIcon(DateTime now) {
  final int hour = now.hour;
  if (hour < 12) {
    return Icons.wb_sunny_outlined;
  }
  if (hour < 18) {
    return Icons.wb_twilight;
  }
  return Icons.dark_mode_outlined;
}

/// Stable bar heights for one account. Week and month use different seeds.
List<double> _barHeights(int id, {required bool month}) {
  final List<double> heights = <double>[];
  int seed = (id.abs() + 1) * (month ? 48 : 13);
  for (int i = 0; i < 7; i++) {
    seed = (seed * 1103515245 + 12345 + i * (month ? 53 : 19)) & 0x7fffffff;
    final double unit = (seed % 1000) / 1000;
    final double wave = month ? (i % 3) * 0.08 : (i - 3).abs() * 0.04;
    double value = 0.22 + unit * 0.7 + wave;
    if (value > 1) {
      value = 1;
    }
    heights.add(value);
  }
  return heights;
}

Color? _tryParseHex(String raw) {
  String text = raw.trim();
  if (text.isEmpty) {
    return null;
  }
  if (text.startsWith('#')) {
    text = text.substring(1);
  } else if (text.startsWith('0x') || text.startsWith('0X')) {
    text = text.substring(2);
  } else {
    return null;
  }
  if (text.length == 3) {
    final StringBuffer buffer = StringBuffer();
    for (final String glyph in text.split('')) {
      buffer
        ..write(glyph)
        ..write(glyph);
    }
    text = buffer.toString();
  }
  if (text.length == 6) {
    text = 'FF$text';
  }
  if (text.length != 8) {
    return null;
  }
  final int? value = int.tryParse(text, radix: 16);
  if (value == null) {
    return null;
  }
  return Color(value);
}

Color _avatarColor(String raw) {
  return _tryParseHex(raw) ?? kGold;
}

String _hexKey(String raw) {
  String text = raw.trim().toLowerCase();
  if (text.startsWith('#')) {
    text = text.substring(1);
  } else if (text.startsWith('0x')) {
    text = text.substring(2);
  }
  if (text.length == 8 && text.startsWith('ff')) {
    text = text.substring(2);
  }
  return text;
}

String _encodePreferences(Set<String> selected) {
  final List<String> ordered = <String>[];
  for (final String item in _preferenceCatalog) {
    if (selected.contains(item)) {
      ordered.add(item);
    }
  }
  final List<String> extras =
      selected
          .where((String item) => !_preferenceCatalog.contains(item))
          .toList()
        ..sort();
  ordered.addAll(extras);
  return ordered.join(', ');
}

class _Badge {
  const _Badge(this.title, this.detail, this.icon, this.tint);

  final String title;
  final String detail;
  final IconData icon;
  final Color tint;
}

List<_Badge> _badgesFor(AppUser user) {
  final List<_Badge> items = <_Badge>[];
  if (!user.emailVerified) {
    items.add(
      const _Badge(
        'Email',
        '',
        Icons.priority_high_rounded,
        kEmber,
      ),
    );
  } else {
    items.add(
      const _Badge(
        'Email',
        'Confirmed',
        Icons.verified,
        kVerified,
      ),
    );
  }
  if (user.twoFactor) {
    items.add(
      const _Badge('Shield', 'Two-factor on', Icons.shield_outlined, kLilac),
    );
  }
  if (user.trips >= 1) {
    items.add(
      const _Badge(
        'First stamp',
        'Logged a trip',
        Icons.luggage_outlined,
        kGold,
      ),
    );
  }
  if (user.trips >= 3) {
    items.add(const _Badge('Wanderer', 'Three trips', Icons.hiking, kMint));
  }
  if (user.trips >= 8) {
    items.add(const _Badge('Nomad', 'Eight trips', Icons.public, kGold));
  }
  return items;
}

class _Session extends InheritedWidget {
  const _Session({
    required this.user,
    required this.onUser,
    required this.onSignedOut,
    required super.child,
  });

  final AppUser user;
  final ValueChanged<AppUser> onUser;
  final VoidCallback onSignedOut;

  static _Session of(BuildContext context) {
    final _Session? session = context
        .dependOnInheritedWidgetOfExactType<_Session>();
    assert(session != null, 'AppShell session is missing');
    return session!;
  }

  @override
  bool updateShouldNotify(_Session oldWidget) {
    return oldWidget.user != user ||
        oldWidget.onUser != onUser ||
        oldWidget.onSignedOut != onSignedOut;
  }
}

class _FactorChoice {
  const _FactorChoice({required this.enabled, this.pin});

  final bool enabled;
  final String? pin;
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.user,
    required this.onUser,
    required this.onSignedOut,
  });

  final AppUser user;
  final ValueChanged<AppUser> onUser;
  final VoidCallback onSignedOut;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: driftTheme(),
      child: Stage(
        child: ScaffoldMessenger(
          child: _Session(
            user: widget.user,
            onUser: widget.onUser,
            onSignedOut: widget.onSignedOut,
            child: Navigator(
              onGenerateRoute: (RouteSettings settings) {
                return MaterialPageRoute<void>(
                  settings: settings,
                  builder: (BuildContext context) => const _Deck(),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Deck extends StatefulWidget {
  const _Deck();

  @override
  State<_Deck> createState() => _DeckState();
}

class _DeckState extends State<_Deck> {
  int _tab = 0;
  bool _month = false;
  bool _busy = false;

  void _selectTab(int index) {
    setState(() {
      _tab = index;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) {
      return;
    }
    _busy = true;
    setState(() {});
    try {
      await action();
    } catch (error) {
      if (!mounted) {
        return;
      }
      _message('$error');
    } finally {
      _busy = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: kInk,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 108),
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
    required bool danger,
  }) async {
    final bool? answer = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: kBg,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: kMute, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                action,
                style: TextStyle(
                  color: danger ? kEmber : kInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
    return answer == true;
  }

  Future<void> _logTrip() async {
    final _Session session = _Session.of(context);
    final int id = session.user.id;
    final ValueChanged<AppUser> onUser = session.onUser;
    await _run(() async {
      final AppUser updated = await UserStore.instance.logTrip(id);
      onUser(updated);
    });
  }

  Future<void> _edit() async {
    final _Session session = _Session.of(context);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return _EditProfile(user: session.user, onUser: session.onUser);
        },
      ),
    );
    if (!mounted) {
      return;
    }
  }

  Future<void> _security() async {
    final _Session session = _Session.of(context);
    final int id = session.user.id;
    final ValueChanged<AppUser> onUser = session.onUser;
    final _FactorChoice? choice = await showDialog<_FactorChoice>(
      context: context,
      useRootNavigator: false,
      barrierColor: const Color(0x731B1C1E),
      builder: (BuildContext context) {
        return _SecurityDialog(enabled: session.user.twoFactor);
      },
    );
    if (choice == null || !mounted) {
      return;
    }
    if (choice.enabled) {
      final String pin = choice.pin ?? '';
      if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
        _message('Enter a 4-digit PIN');
        return;
      }
    }
    await _run(() async {
      final AppUser updated = await UserStore.instance.setTwoFactor(
        id: id,
        enabled: choice.enabled,
        pin: choice.enabled ? choice.pin : null,
      );
      onUser(updated);
    });
  }

  Future<void> _changePassword() async {
    final _Session session = _Session.of(context);
    final TextEditingController current = TextEditingController();
    final TextEditingController next = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: kBg,
          title: const Text('Change password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password'),
              ),
              TextField(
                controller: next,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password (8+ characters)',
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
    final String currentText = current.text;
    final String nextText = next.text;
    current.dispose();
    next.dispose();
    if (ok != true || !mounted) {
      return;
    }
    final String? error = await UserStore.instance.changePassword(
      id: session.user.id,
      currentPassword: currentText,
      nextPassword: nextText,
    );
    if (!mounted) {
      return;
    }
    _message(error ?? 'Password updated.');
  }

  Future<void> _verifyPhone() async {
    final _Session session = _Session.of(context);
    final AuthResult issued = await UserStore.instance.requestPhoneCode(
      session.user.id,
    );
    if (!mounted) {
      return;
    }
    if (issued.error != null || !issued.mailed) {
      _message(issued.error ?? issued.notice ?? 'The text could not be sent.');
      return;
    }
    const String prompt =
        'We sent a 6-digit code by SMS. It expires in 10 minutes.';
    final TextEditingController code = TextEditingController();
    final String? entered = await showDialog<String>(
      context: context,
      useRootNavigator: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: kBg,
          title: const Text('Verify phone'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(prompt),
              TextField(
                controller: code,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '6-digit code'),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(code.text.trim()),
              child: const Text('Verify'),
            ),
          ],
        );
      },
    );
    final String typed = entered ?? '';
    code.dispose();
    if (typed.isEmpty || !mounted) {
      return;
    }
    final AuthResult result = await UserStore.instance.verifyPhone(
      id: session.user.id,
      code: typed,
    );
    if (!mounted) {
      return;
    }
    if (result.error != null || result.user == null) {
      _message(result.error ?? 'Could not verify the phone number.');
      return;
    }
    session.onUser(result.user!);
    _message('Phone number verified.');
  }

  Future<void> _deactivate() async {
    final bool ok = await _confirm(
      title: 'Deactivate account',
      message: 'You will be signed out and this account will be deactivated.',
      action: 'Deactivate',
      danger: false,
    );
    if (!ok || !mounted) {
      return;
    }
    final _Session session = _Session.of(context);
    final int id = session.user.id;
    final VoidCallback signedOut = session.onSignedOut;
    await _run(() async {
      await UserStore.instance.deactivate(id);
      signedOut();
    });
  }

  Future<void> _delete() async {
    final bool ok = await _confirm(
      title: 'Delete account',
      message: 'This permanently deletes the account and its trips.',
      action: 'Delete',
      danger: true,
    );
    if (!ok || !mounted) {
      return;
    }
    final _Session session = _Session.of(context);
    final int id = session.user.id;
    final VoidCallback signedOut = session.onSignedOut;
    final TextEditingController password = TextEditingController();
    final String? confirmed = await showDialog<String>(
      context: context,
      useRootNavigator: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: kBg,
          title: const Text('Confirm password'),
          content: TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current password'),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(password.text),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    final String typed = password.text;
    password.dispose();
    if (confirmed == null || !mounted) {
      return;
    }
    await _run(() async {
      final String? error = await UserStore.instance.deleteOwnAccount(
        id: id,
        password: typed,
      );
      if (error != null) {
        throw StateError(error);
      }
      signedOut();
    });
  }

  Future<void> _logout() async {
    final VoidCallback signedOut = _Session.of(context).onSignedOut;
    await _run(() async {
      await UserStore.instance.logout();
      signedOut();
    });
  }

  @override
  Widget build(BuildContext context) {
    final _Session session = _Session.of(context);
    final AppUser user = session.user;
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: kAppWash),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _FadePane(
                    visible: _tab == 0,
                    child: _HomePage(
                    user: user,
                    month: _month,
                    admin: user.isAdmin,
                    tab: _tab,
                    onTab: _selectTab,
                    onMonth: (bool month) {
                      setState(() {
                        _month = month;
                      });
                    },
                    onLog: _logTrip,
                    onProfile: () => _selectTab(2),
                  ),
                  ),
                  _FadePane(
                    visible: _tab == 1,
                    child: user.isAdmin
                        ? AdminDashboard(
                            sessionUserId: user.id,
                            onSessionUser: session.onUser,
                            onSessionDeleted: session.onSignedOut,
                          )
                        : TripsListScreen(userId: user.id),
                  ),
                  _FadePane(
                    visible: _tab == 2,
                    child: _ProfilePage(
                      user: user,
                      onEdit: _edit,
                      onLog: _logTrip,
                      onSecurity: _security,
                      onPassword: _changePassword,
                      onPhone: _verifyPhone,
                      onDeactivate: _deactivate,
                      onDelete: _delete,
                      onLogout: _logout,
                    ),
                  ),
                ],
              ),
            ),
            if (_tab != 0)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                  child: _BottomNav(
                    tab: _tab,
                    admin: user.isAdmin,
                    onChanged: _selectTab,
                  ),
                ),
              ),
            Align(
              alignment: const Alignment(1, -0.22),
              child: GuideHandle(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => TripGuide(user: user),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _FadePane extends StatelessWidget {
  const _FadePane({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        child: child,
      ),
    );
  }
}

class _HomePage extends StatelessWidget {
  const _HomePage({
    required this.user,
    required this.month,
    required this.admin,
    required this.tab,
    required this.onTab,
    required this.onMonth,
    required this.onLog,
    required this.onProfile,
  });

  final AppUser user;
  final bool month;
  final bool admin;
  final int tab;
  final ValueChanged<int> onTab;
  final ValueChanged<bool> onMonth;
  final VoidCallback onLog;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final List<_Badge> badges = _badgesFor(user);
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 48, 18),
      children: <Widget>[
        const WeatherToday(),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Hey, ${user.prenom}!', style: _display),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      Text(_greeting(now), style: _quiet),
                      const SizedBox(width: 6),
                      Icon(_greetingIcon(now), size: 16, color: kGold),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _Avatar(user: user, radius: 26),
          ],
        ),
        const SizedBox(height: 26),
        const Text(
          'Current trips',
          style: TextStyle(
            color: kMute,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Text('${user.trips}', style: _huge),
            const SizedBox(width: 12),
            Flexible(child: _LevelPill(label: user.niveauVoyageur)),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: <Widget>[
            Expanded(
              child: _Pill(
                label: 'Log a trip',
                icon: Icons.flight_takeoff,
                background: kInk,
                foreground: kPaper,
                onTap: onLog,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Pill(
                label: 'Profile',
                icon: Icons.person_outline,
                background: kOrange,
                foreground: kInk,
                onTap: onProfile,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Pill(
          label: 'Mes voyages',
          icon: Icons.luggage_outlined,
          background: kInk,
          foreground: kPaper,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) =>
                    TripsListScreen(userId: user.id),
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        _WeekCard(
          heights: _barHeights(user.id, month: month),
          month: month,
          onMonth: onMonth,
        ),
        const SizedBox(height: 14),
        _BadgeDock(
          badges: badges,
          admin: admin,
          tab: tab,
          onTab: onTab,
        ),
      ],
    );
  }
}

class _LevelPill extends StatelessWidget {
  const _LevelPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: kGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: kInk,
          fontFamily: kDisplay,
          fontVariations: kReading,
          fontSize: 14,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.heights,
    required this.month,
    required this.onMonth,
  });

  final List<double> heights;
  final bool month;
  final ValueChanged<bool> onMonth;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        gradient: kMintGradient,
        borderRadius: kCardRadius,
        border: Border.all(color: kNavy),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'This week',
                  style: TextStyle(
                    color: kInk,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              _MintChip(
                label: '7 days',
                selected: !month,
                idle: const Color(0xB3B2A4A1),
                onTap: () => onMonth(false),
              ),
              const SizedBox(width: 6),
              _MintChip(
                label: '1 month',
                selected: month,
                idle: kLilac,
                onTap: () => onMonth(true),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 132,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (final double height in heights)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        height: 124 * height,
                        decoration: BoxDecoration(
                          gradient: kBlackGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MintChip extends StatelessWidget {
  const _MintChip({
    required this.label,
    required this.selected,
    required this.idle,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color idle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? kPaper : idle,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: const TextStyle(
              color: kInk,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgeDock extends StatelessWidget {
  const _BadgeDock({
    required this.badges,
    required this.admin,
    required this.tab,
    required this.onTab,
  });

  final List<_Badge> badges;
  final bool admin;
  final int tab;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const DockClipper(),
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: kBlackGradient),
        child: CustomPaint(
          painter: const DockOutlinePainter(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 18, 18, 0),
                child: Text(
                  'Badges',
                  style: TextStyle(
                    fontFamily: kDisplay,
                    fontVariations: kReading,
                    color: kPaper,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (badges.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 6, 18, 8),
                  child: Text(
                    'No badges yet',
                    style: TextStyle(
                      fontFamily: kFont,
                      fontVariations: kReading,
                      color: kPaper,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    children: <Widget>[
                      for (int i = 0; i < badges.length; i++)
                        _BadgeRow(badge: badges[i], last: i == badges.length - 1),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                height: 86,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
                  child: _BottomNav(
                    tab: tab,
                    admin: admin,
                    onChanged: onTab,
                    embedded: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.badge, required this.last});

  final _Badge badge;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: kBlue)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: badge.tint,
              shape: BoxShape.circle,
            ),
            child: Icon(
              badge.icon,
              color: badge.tint == kBlue ||
                      badge.tint == kVerified ||
                      badge.tint == kEmber
                  ? kPaper
                  : kInk,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  badge.title,
                  style: const TextStyle(
                    color: kPaper,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  badge.detail,
                  style: const TextStyle(
                    color: kPaper,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_rounded, color: kOrange, size: 20),
        ],
      ),
    );
  }
}


class _ProfilePage extends StatelessWidget {
  const _ProfilePage({
    required this.user,
    required this.onEdit,
    required this.onLog,
    required this.onSecurity,
    required this.onPassword,
    required this.onPhone,
    required this.onDeactivate,
    required this.onDelete,
    required this.onLogout,
  });

  final AppUser user;
  final VoidCallback onEdit;
  final VoidCallback onLog;
  final VoidCallback onSecurity;
  final VoidCallback onPassword;
  final VoidCallback onPhone;
  final VoidCallback onDeactivate;
  final VoidCallback onDelete;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _pagePadding,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Your level', style: _display),
                  const SizedBox(height: 4),
                  Text(user.niveauVoyageur, style: _quiet),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _Avatar(user: user, radius: 26),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: <Widget>[
            Expanded(
              child: _Pill(
                label: 'Edit',
                icon: Icons.edit_outlined,
                background: kGold,
                foreground: kInk,
                onTap: onEdit,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Pill(
                label: 'Log trip',
                icon: Icons.add,
                background: kInk,
                foreground: kPaper,
                onTap: onLog,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Pill(
                label: 'Security',
                icon: Icons.shield_outlined,
                background: kPaper,
                foreground: kInk,
                borderColor: kLine,
                onTap: onSecurity,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text('${user.trips}', style: _huge.copyWith(fontSize: 56)),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text(
                'trips',
                style: TextStyle(
                  color: kMute,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'Left to reach the goal',
                style: TextStyle(
                  color: kMute,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${user.trips}/${user.goal}',
              style: const TextStyle(
                color: kInk,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _GoalBar(progress: user.levelProgress),
        const SizedBox(height: 18),
        _BlackPanel(
          title: 'Preferences',
          child: user.preferences.isEmpty
              ? const Text(
                  'None yet',
                  style: TextStyle(
                    color: kPaper,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (int i = 0; i < user.preferences.length; i++)
                      _PreferenceChip(
                        label: user.preferences[i],
                        color: _chipTint(i),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        _BlackPanel(
          title: 'Account',
          child: Column(
            children: <Widget>[
              _AccountRow(
                icon: Icons.person_outline,
                label: 'Prénom',
                value: user.prenom,
              ),
              _AccountRow(
                icon: Icons.badge_outlined,
                label: 'Nom',
                value: user.nom,
              ),
              _AccountRow(icon: Icons.public, label: 'Pays', value: user.pays),
              _AccountRow(
                icon: Icons.translate,
                label: 'Langue',
                value: user.langue,
              ),
              if (user.isAdmin)
                _AccountRow(
                  icon: Icons.badge_outlined,
                  label: 'Rôle',
                  value: user.roleLabel,
                ),
              _AccountRow(
                icon: Icons.mail_outline,
                label: 'Email',
                value: user.email,
                trailing: user.emailVerified
                    ? const Icon(Icons.verified, color: kVerified, size: 18)
                    : const UnverifiedBadge(size: 20),
              ),
              _AccountRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: user.phone.isEmpty ? '—' : user.phone,
                trailing: user.phoneVerified
                    ? const Icon(Icons.verified, color: kVerified, size: 18)
                    : const UnverifiedBadge(size: 20),
              ),
              _AccountRow(
                icon: Icons.notes_outlined,
                label: 'Bio',
                value: user.bio.isEmpty ? '—' : user.bio,
              ),
              _AccountRow(
                icon: Icons.calendar_today_outlined,
                label: 'Date création',
                value:
                    '${user.dateCreation.year}-${user.dateCreation.month.toString().padLeft(2, '0')}-${user.dateCreation.day.toString().padLeft(2, '0')}',
              ),
              _AccountRow(
                icon: Icons.terrain_outlined,
                label: 'Niveau',
                value: user.niveauVoyageur,
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _Pill(
          label: 'Change password',
          background: kPaper,
          foreground: kInk,
          borderColor: kLine,
          onTap: onPassword,
        ),
        const SizedBox(height: 8),
        _Pill(
          label: user.phoneVerified ? 'Phone verified' : 'Verify phone',
          background: user.phoneVerified ? kMint : kPaper,
          foreground: kInk,
          borderColor: kLine,
          onTap: user.phoneVerified ? () {} : onPhone,
        ),
        const SizedBox(height: 8),
        _Pill(
          label: 'Deactivate',
          background: kPaper,
          foreground: kInk,
          borderColor: kLine,
          onTap: onDeactivate,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onDelete,
          child: const Text(
            'Delete account',
            style: TextStyle(
              color: kEmber,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(height: 4),
        _Pill(
          label: 'Log out',
          background: kInk,
          foreground: kPaper,
          onTap: onLogout,
        ),
      ],
    );
  }
}

Color _chipTint(int index) {
  const List<Color> tints = <Color>[kMint, kGold, kLilac];
  return tints[index % tints.length];
}

class _PreferenceChip extends StatelessWidget {
  const _PreferenceChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: kInk,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BlackPanel extends StatelessWidget {
  const _BlackPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: blackCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: kPaper,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: kBlue)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: kNavy,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: kPaper, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: kPaper,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: kPaper,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 6),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _GoalBar extends StatelessWidget {
  const _GoalBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    double value = progress;
    if (value.isNaN || value < 0) {
      value = 0;
    } else if (value > 1) {
      value = 1;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 10,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                const ColoredBox(color: kLine),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: constraints.maxWidth * value,
                    child: const ColoredBox(color: kInk),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EditProfile extends StatefulWidget {
  const _EditProfile({required this.user, required this.onUser});

  final AppUser user;
  final ValueChanged<AppUser> onUser;

  @override
  State<_EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<_EditProfile> {
  late final TextEditingController _prenom;
  late final TextEditingController _nom;
  late final TextEditingController _pays;
  late final TextEditingController _langue;
  late final TextEditingController _phone;
  late final TextEditingController _bio;
  late final Set<String> _selected;
  late String _photo;
  bool _saving = false;
  bool _photoBusy = false;

  @override
  void initState() {
    super.initState();
    final AppUser user = widget.user;
    _prenom = TextEditingController(text: user.prenom);
    _nom = TextEditingController(text: user.nom);
    _pays = TextEditingController(text: user.pays);
    _langue = TextEditingController(text: user.langue);
    _phone = TextEditingController(text: user.phone);
    _bio = TextEditingController(text: user.bio);
    _selected = user.preferences.toSet();
    _photo = user.photoProfil;
    _prenom.addListener(_refresh);
    _nom.addListener(_refresh);
  }

  void _refresh() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _prenom.removeListener(_refresh);
    _nom.removeListener(_refresh);
    _prenom.dispose();
    _nom.dispose();
    _pays.dispose();
    _langue.dispose();
    _phone.dispose();
    _bio.dispose();
    super.dispose();
  }

  List<String> get _options {
    final List<String> extras =
        _selected
            .where((String item) => !_preferenceCatalog.contains(item))
            .toList()
          ..sort();
    return <String>[..._preferenceCatalog, ...extras];
  }

  String _initials() {
    final String first = _prenom.text.trim();
    final String last = _nom.text.trim();
    final String a = first.isEmpty
        ? ''
        : String.fromCharCode(first.runes.first);
    final String b = last.isEmpty ? '' : String.fromCharCode(last.runes.first);
    final String value = '$a$b'.toUpperCase();
    if (value.isEmpty) {
      return '?';
    }
    return value;
  }

  Future<void> _setPhoto(ImageSource source) async {
    if (_photoBusy || _saving) {
      return;
    }
    setState(() => _photoBusy = true);
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
      final String message = error is StateError
          ? error.message
          : 'Could not use that photo.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: kInk,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _photoBusy = false);
      }
    }
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    setState(() {
      _saving = true;
    });
    final ValueChanged<AppUser> onUser = widget.onUser;
    try {
      final AppUser updated = await UserStore.instance.updateProfile(
        id: widget.user.id,
        nom: _nom.text.trim(),
        prenom: _prenom.text.trim(),
        pays: _pays.text.trim(),
        langue: _langue.text.trim(),
        preferences: _encodePreferences(_selected),
        photoProfil: _photo,
        phone: _phone.text.trim() == widget.user.phone ? null : _phone.text.trim(),
        bio: _bio.text.trim(),
      );
      if (!mounted) {
        return;
      }
      onUser(updated);
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$error'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: kInk,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
              child: Row(
                children: <Widget>[
                  _RoundButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Edit profile', style: _display)),
                  ProfileAvatar(
                    photo: _photo,
                    initials: _initials(),
                    radius: 22,
                    onTap: _photoBusy ? null : () => _setPhoto(ImageSource.gallery),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
                children: <Widget>[
                  _LabeledField(label: 'Prenom', controller: _prenom),
                  const SizedBox(height: 14),
                  _LabeledField(label: 'Nom', controller: _nom),
                  const SizedBox(height: 14),
                  CountryField(
                    value: _pays.text,
                    onChanged: (String value) => setState(() => _pays.text = value),
                  ),
                  const SizedBox(height: 14),
                  _LabeledField(label: 'Langue', controller: _langue),
                  const SizedBox(height: 14),
                  _LabeledField(label: 'Phone', controller: _phone),
                  const SizedBox(height: 14),
                  _LabeledField(label: 'Bio', controller: _bio),
                  const SizedBox(height: 20),
                  const Text(
                    'Preferences',
                    style: TextStyle(
                      color: kMute,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final String option in _options)
                        _ToggleChip(
                          label: option,
                          selected: _selected.contains(option),
                          onTap: () {
                            setState(() {
                              if (_selected.contains(option)) {
                                _selected.remove(option);
                              } else {
                                _selected.add(option);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Profile photo',
                    style: TextStyle(
                      color: kMute,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      ProfileAvatar(
                        photo: _photo,
                        initials: _initials(),
                        radius: 36,
                        onTap: _photoBusy
                            ? null
                            : () => _setPhoto(ImageSource.gallery),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _PhotoAction(
                              label: _photoBusy ? 'Working' : 'Gallery',
                              icon: Icons.photo_outlined,
                              onTap: _photoBusy
                                  ? null
                                  : () => _setPhoto(ImageSource.gallery),
                            ),
                            const SizedBox(height: 8),
                            _PhotoAction(
                              label: 'Camera',
                              icon: Icons.photo_camera_outlined,
                              onTap: _photoBusy
                                  ? null
                                  : () => _setPhoto(ImageSource.camera),
                            ),
                            if (isStoredPhoto(_photo)) ...<Widget>[
                              const SizedBox(height: 8),
                              _PhotoAction(
                                label: 'Remove',
                                icon: Icons.delete_outline,
                                onTap: _photoBusy
                                    ? null
                                    : () => setState(() => _photo = kDefaultPhoto),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Color',
                    style: TextStyle(
                      color: kMute,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      for (final String hex in kProfileColors)
                        _ColorDot(
                          hex: hex,
                          selected: _hexKey(hex) == _hexKey(_photo),
                          onTap: () {
                            setState(() {
                              _photo = hex;
                            });
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
              child: _Pill(
                label: _saving || _photoBusy ? 'Saving' : 'Save',
                background: kInk,
                foreground: kPaper,
                onTap: _saving || _photoBusy ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: kMute,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          cursorColor: kInk,
          style: const TextStyle(color: kInk, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            filled: true,
            fillColor: kPaper,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: _editBorder(kLine),
            enabledBorder: _editBorder(kLine),
            focusedBorder: _editBorder(kInk),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _editBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? kInk : kPaper,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? kInk : kLine),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? kPaper : kInk,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoAction extends StatelessWidget {
  const _PhotoAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kPaper,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kLine),
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 18, color: kInk),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: kInk,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = _avatarColor(hex);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? kInk : Colors.transparent,
            width: 2,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: kLine),
          ),
        ),
      ),
    );
  }
}

class _SecurityDialog extends StatefulWidget {
  const _SecurityDialog({required this.enabled});

  final bool enabled;

  @override
  State<_SecurityDialog> createState() => _SecurityDialogState();
}

class _SecurityDialogState extends State<_SecurityDialog> {
  late bool _on;
  final TextEditingController _pin = TextEditingController();

  @override
  void initState() {
    super.initState();
    _on = widget.enabled;
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  bool get _turningOn => _on && !widget.enabled;

  bool get _turningOff => !_on && widget.enabled;

  void _submit(BuildContext messengerContext) {
    if (_turningOn) {
      final String pin = _pin.text.trim();
      if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
        ScaffoldMessenger.of(messengerContext).showSnackBar(
          const SnackBar(
            content: Text('Enter a 4-digit PIN'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: kInk,
            margin: EdgeInsets.fromLTRB(16, 0, 16, 20),
          ),
        );
        return;
      }
      Navigator.of(messengerContext)
          .pop(_FactorChoice(enabled: true, pin: pin));
      return;
    }
    if (_turningOff) {
      Navigator.of(messengerContext).pop(const _FactorChoice(enabled: false));
      return;
    }
    Navigator.of(messengerContext).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Builder(
          builder: (BuildContext messengerContext) {
            return LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                double cardWidth = constraints.maxWidth - 48;
                if (cardWidth > 360) {
                  cardWidth = 360;
                }
                if (cardWidth < 160) {
                  cardWidth = constraints.maxWidth;
                }
                final double minHeight = constraints.maxHeight - 48;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(messengerContext).pop(),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: minHeight < 0 ? 0 : minHeight,
                      ),
                      child: Center(
                        child: GestureDetector(
                          onTap: () {},
                          excludeFromSemantics: true,
                          child: Material(
                            color: kBg,
                            surfaceTintColor: Colors.transparent,
                            borderRadius: BorderRadius.circular(28),
                            clipBehavior: Clip.antiAlias,
                            child: SizedBox(
                              width: cardWidth,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  22,
                                  22,
                                  22,
                                  16,
                                ),
                                child: _body(messengerContext),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext messengerContext) {
    final String actionLabel;
    if (_turningOn) {
      actionLabel = 'Enable';
    } else if (_turningOff) {
      actionLabel = 'Disable';
    } else {
      actionLabel = 'Close';
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text('Security', style: _display),
        const SizedBox(height: 8),
        Text(
          widget.enabled
              ? 'Two-factor is on. Turn it off to sign in with your password.'
              : 'A 4-digit PIN protects sign-in.',
          style: _quiet,
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'Two-factor',
                style: TextStyle(
                  color: kInk,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Switch(
              value: _on,
              activeThumbColor: kBg,
              activeTrackColor: kInk,
              inactiveThumbColor: kPaper,
              inactiveTrackColor: kLine,
              onChanged: (bool value) {
                setState(() {
                  _on = value;
                });
              },
            ),
          ],
        ),
        if (_turningOn) ...<Widget>[
          const SizedBox(height: 8),
          TextField(
            controller: _pin,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 4,
            obscureText: true,
            cursorColor: kInk,
            style: const TextStyle(
              color: kInk,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 8,
            ),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              counterText: '',
              hintText: '4-digit PIN',
              hintStyle: const TextStyle(
                color: kMute,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
              filled: true,
              fillColor: kPaper,
              border: _pinBorder(kLine),
              enabledBorder: _pinBorder(kLine),
              focusedBorder: _pinBorder(kInk),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(messengerContext).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: kMute, fontWeight: FontWeight.w700),
              ),
            ),
            const Spacer(),
            _Pill(
              label: actionLabel,
              background: kInk,
              foreground: kPaper,
              onTap: () => _submit(messengerContext),
            ),
          ],
        ),
      ],
    );
  }

  OutlineInputBorder _pinBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, required this.radius});

  final AppUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ProfileAvatar(
      photo: user.photoProfil,
      initials: user.initials,
      radius: radius,
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kPaper,
      shape: const CircleBorder(side: BorderSide(color: kLine)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, color: kInk, size: 20),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.icon,
    this.borderColor,
  });

  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final StadiumBorder shape = StadiumBorder(
      side: borderColor == null
          ? BorderSide.none
          : BorderSide(color: borderColor!),
    );
    return Material(
      color: background,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) Icon(icon, size: 18, color: foreground),
                if (icon != null) const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.tab,
    required this.admin,
    required this.onChanged,
    this.embedded = false,
  });

  final int tab;
  final bool admin;
  final ValueChanged<int> onChanged;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final Widget row = SizedBox(
      height: embedded ? 70 : 68,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          _NavButton(
            icon: admin ? Icons.dashboard_outlined : Icons.luggage_outlined,
            label: admin ? 'Dashboard' : 'Voyages',
            selected: tab == 1,
            onTap: () => onChanged(1),
          ),
          _NavButton(
            icon: Icons.home,
            label: 'Home',
            selected: tab == 0,
            onTap: () => onChanged(0),
          ),
          _NavButton(
            icon: Icons.grid_view,
            label: 'Profile',
            selected: tab == 2,
            onTap: () => onChanged(2),
          ),
        ],
      ),
    );
    if (embedded) {
      return row;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: kBlackGradient,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: const Color(0x3DB2A4A1)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: row,
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: SizedBox(
          width: 64,
          height: 64,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: selected ? 46 : 40,
              height: selected ? 46 : 40,
              decoration: BoxDecoration(
                color: selected ? kPaper : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 22, color: selected ? kInk : kPaper),
            ),
          ),
        ),
      ),
    );
  }
}
