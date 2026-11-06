import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'countries.dart';
import 'store.dart';
import 'theme.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({
    super.key,
    required this.sessionUserId,
    required this.onSessionUser,
    required this.onSessionDeleted,
  });

  final int sessionUserId;
  final ValueChanged<AppUser> onSessionUser;
  final VoidCallback onSessionDeleted;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<AppUser> _users = const <AppUser>[];
  List<Trip> _trips = const <Trip>[];
  List<String> _audit = const <String>[];
  final TextEditingController _query = TextEditingController();
  String _sort = 'newest';
  int _page = 0;
  int _tripPage = 0;
  bool _loading = true;
  String? _error;

  static const int _pageSize = 6;

  @override
  void initState() {
    super.initState();
    _query.addListener(() {
      if (mounted) {
        setState(() => _page = 0);
      }
    });
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final List<AppUser> users = await UserStore.instance.listUsers();
      final List<Trip> trips = await UserStore.instance.listTrips();
      final List<String> audit = await UserStore.instance.recentAudit();
      if (!mounted) {
        return;
      }
      setState(() {
        _users = users;
        _trips = trips;
        _audit = audit;
        _loading = false;
        _error = null;
        _page = _clampPage(_page, _pageCount);
        _tripPage = _clampPage(_tripPage, _tripPageCount);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  AppUser? _owner(int id) {
    for (final AppUser user in _users) {
      if (user.id == id) {
        return user;
      }
    }
    return null;
  }

  Future<void> _editUser(AppUser person) async {
    final AppUser? updated = await showDialog<AppUser>(
      context: context,
      useRootNavigator: false,
      builder: (BuildContext context) => _UserEditor(person: person),
    );
    if (updated == null) {
      return;
    }
    if (updated.id == widget.sessionUserId) {
      widget.onSessionUser(updated);
    }
    await _load();
  }

  Future<void> _deleteUser(AppUser person) async {
    final bool? ok = await _ask(
      'Delete ${person.name}?',
      'This removes the profile and every trip linked to it.',
    );
    if (ok != true) {
      return;
    }
    final String? error = await UserStore.instance.adminDeleteUser(
      actorId: widget.sessionUserId,
      targetId: person.id,
    );
    if (!mounted) {
      return;
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    await _load();
  }

  Future<void> _editTrip([Trip? trip]) async {
    if (_users.isEmpty) {
      return;
    }
    final Trip? saved = await showDialog<Trip>(
      context: context,
      useRootNavigator: false,
      builder: (BuildContext context) => _TripEditor(trip: trip, users: _users),
    );
    if (saved == null) {
      return;
    }
    await _load();
  }

  Future<void> _deleteTrip(Trip trip) async {
    final bool? ok = await _ask(
      'Delete ${trip.titre}?',
      'This trip will be removed for its traveller.',
    );
    if (ok != true) {
      return;
    }
    await UserStore.instance.deleteTrip(trip.id);
    await _load();
  }

  Future<bool?> _ask(String title, String message) {
    return showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (BuildContext context) {
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
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Delete',
                style: TextStyle(color: kEmber),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kInk));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 12, 48, 128),
      children: <Widget>[
        const Text(
          'Dashboard',
          style: TextStyle(
            fontFamily: kFont,
            fontVariations: kReading,
            color: kInk,
            fontSize: 32,
            height: 1.15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Manage every profile and trip.',
          style: TextStyle(color: kMute, fontSize: 15, fontWeight: FontWeight.w500),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: kEmber)),
        ],
        const SizedBox(height: 18),
        Row(
          children: <Widget>[
            Expanded(
              child: _Stat(
                label: 'Profiles',
                value: '${_users.length}',
                color: kMint,
                ink: kInk,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Stat(
                label: 'Trips',
                value: '${_trips.length}',
                color: kInk,
                ink: kPaper,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: _Stat(
                label: 'Email',
                icon: Icons.verified,
                iconColor: kVerified,
                value: '${_users.where((AppUser user) => user.emailVerified).length}',
                color: kLilac,
                ink: kInk,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Stat(
                label: 'Active',
                value: '${_users.where((AppUser user) => user.active).length}',
                color: kGold,
                ink: kInk,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${_users.where((AppUser user) => !user.emailVerified).length} email pending · ${_users.where((AppUser user) => !user.active).length} suspended · $_recentCount joined in 7 days',
          style: const TextStyle(color: kMute, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 22),
        _SectionTitle(
          title: 'Profiles',
          trailing: _Pager(
            page: _clampPage(_page, _pageCount),
            count: _pageCount,
            onChanged: (int page) => setState(() => _page = page),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _query,
          decoration: const InputDecoration(
            hintText: 'Search name, email, or phone',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            const Text(
              'Sort',
              style: TextStyle(color: kMute, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _sort,
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(value: 'newest', child: Text('Newest')),
                DropdownMenuItem<String>(value: 'name', child: Text('Name')),
              ],
              onChanged: (String? value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _sort = value;
                  _page = 0;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        _PagedList(
          page: _clampPage(_page, _pageCount),
          children: _visible.isEmpty
              ? <Widget>[
                  Text(
                    _query.text.trim().isEmpty
                        ? 'No profiles yet.'
                        : 'No profiles match that search.',
                    style: const TextStyle(
                      color: kMute,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ]
              : <Widget>[
                  for (final AppUser person in _visible)
                    _ManageCard(
                      title: person.name,
                      subtitle: person.isAdmin
                          ? 'Admin · ${person.active ? 'Active' : 'Suspended'} · ${person.email}'
                          : '${person.active ? 'Active' : 'Suspended'} · ${person.email}',
                      verified: person.emailVerified,
                      onEdit: () => _editUser(person),
                      onDelete: person.isAdmin ? null : () => _deleteUser(person),
                      onSuspend: person.isAdmin
                          ? null
                          : () => _toggleActive(person),
                      suspendLabel: person.active ? 'Suspend' : 'Restore',
                      onRecover: () => _issueReset(person),
                    ),
                ],
        ),
        const SizedBox(height: 18),
        _SectionTitle(
          title: 'Trips',
          action: () => _editTrip(),
          trailing: _Pager(
            page: _clampPage(_tripPage, _tripPageCount),
            count: _tripPageCount,
            onChanged: (int page) => setState(() => _tripPage = page),
          ),
        ),
        const SizedBox(height: 10),
        _PagedList(
          page: _clampPage(_tripPage, _tripPageCount),
          children: _visibleTrips.isEmpty
              ? const <Widget>[
                  Text(
                    'No trips yet. Add one for a traveller.',
                    style: TextStyle(color: kMute, fontWeight: FontWeight.w600),
                  ),
                ]
              : <Widget>[
                  for (final Trip trip in _visibleTrips)
                    _ManageCard(
                      title: trip.titre,
                      subtitle:
                          '${trip.destination} · ${_owner(trip.userId)?.name ?? 'Unknown'} · ${trip.statut}',
                      onEdit: () => _editTrip(trip),
                      onDelete: () => _deleteTrip(trip),
                    ),
                ],
        ),
        const SizedBox(height: 18),
        const _SectionTitle(title: 'Audit', action: null),
        const SizedBox(height: 8),
        if (_audit.isEmpty)
          const Text(
            'No administrative actions yet.',
            style: TextStyle(color: kMute, fontWeight: FontWeight.w600),
          ),
        for (final String line in _audit)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(line, style: const TextStyle(color: kMute, fontSize: 12)),
          ),
      ],
    );
  }

  int get _recentCount {
    final DateTime cutoff = DateTime.now().subtract(const Duration(days: 7));
    return _users.where((AppUser user) => user.dateCreation.isAfter(cutoff)).length;
  }

  int get _pageCount {
    final int count = _filtered.length;
    if (count == 0) {
      return 1;
    }
    return (count + _pageSize - 1) ~/ _pageSize;
  }

  int get _tripPageCount {
    if (_trips.isEmpty) {
      return 1;
    }
    return (_trips.length + _pageSize - 1) ~/ _pageSize;
  }

  int _clampPage(int page, int count) {
    final int last = count <= 1 ? 0 : count - 1;
    if (page < 0) {
      return 0;
    }
    if (page > last) {
      return last;
    }
    return page;
  }

  List<AppUser> get _filtered {
    final String query = _query.text.trim().toLowerCase();
    final List<AppUser> matched = query.isEmpty
        ? List<AppUser>.of(_users)
        : _users.where((AppUser user) {
            return user.name.toLowerCase().contains(query) ||
                user.email.toLowerCase().contains(query) ||
                user.phone.contains(query);
          }).toList();
    if (_sort == 'name') {
      matched.sort(
        (AppUser a, AppUser b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }
    return matched;
  }

  List<AppUser> get _visible {
    final List<AppUser> matched = _filtered;
    final int start = _clampPage(_page, _pageCount) * _pageSize;
    if (start >= matched.length) {
      return const <AppUser>[];
    }
    final int end = start + _pageSize;
    return matched.sublist(start, end > matched.length ? matched.length : end);
  }

  List<Trip> get _visibleTrips {
    final int start = _clampPage(_tripPage, _tripPageCount) * _pageSize;
    if (start >= _trips.length) {
      return const <Trip>[];
    }
    final int end = start + _pageSize;
    return _trips.sublist(start, end > _trips.length ? _trips.length : end);
  }

  Future<void> _issueReset(AppUser person) async {
    final AuthResult result = await UserStore.instance.adminIssueReset(
      actorId: widget.sessionUserId,
      targetId: person.id,
    );
    if (!mounted) {
      return;
    }
    final String message = result.error ??
        'A reset code was emailed to ${person.email}. It expires in 10 minutes.';
    await showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: kBg,
          title: const Text('Reset code'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
    await _load();
  }

  Future<void> _toggleActive(AppUser person) async {
    final String? error = await UserStore.instance.setAccountActive(
      actorId: widget.sessionUserId,
      targetId: person.id,
      active: !person.active,
    );
    if (!mounted) {
      return;
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    await _load();
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.count,
    required this.onChanged,
  });

  final int page;
  final int count;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _PagerButton(
          icon: Icons.chevron_left,
          enabled: page > 0,
          onTap: () => onChanged(page - 1),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 52,
          child: Text(
            '${page + 1} / $count',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 4),
        _PagerButton(
          icon: Icons.chevron_right,
          enabled: page + 1 < count,
          onTap: () => onChanged(page + 1),
        ),
      ],
    );
  }
}

class _PagerButton extends StatelessWidget {
  const _PagerButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: enabled ? kInk : kNavy.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Icon(icon, size: 20, color: kPaper),
        ),
      ),
    );
  }
}

class _PagedList extends StatefulWidget {
  const _PagedList({required this.page, required this.children});

  final int page;
  final List<Widget> children;

  @override
  State<_PagedList> createState() => _PagedListState();
}

class _PagedListState extends State<_PagedList> {
  bool _forward = true;

  @override
  void didUpdateWidget(covariant _PagedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.page != oldWidget.page) {
      _forward = widget.page > oldWidget.page;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (Widget? current, List<Widget> previous) {
        return Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.hardEdge,
          children: <Widget>[
            ...previous,
            ?current,
          ],
        );
      },
      transitionBuilder: (Widget child, Animation<double> animation) {
        final bool incoming = child.key == ValueKey<int>(widget.page);
        final double dx = _forward ? 0.18 : -0.18;
        final Animation<Offset> offset = Tween<Offset>(
          begin: Offset(incoming ? dx : -dx, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: Column(
        key: ValueKey<int>(widget.page),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widget.children,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.action,
    this.trailing,
  });

  final String title;
  final VoidCallback? action;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: kFont,
              fontVariations: kReading,
              color: kInk,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ?trailing,
        if (action != null)
          TextButton(onPressed: action, child: const Text('Add')),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
    required this.ink,
    this.icon,
    this.iconColor,
  });

  final String label;
  final String value;
  final Color color;
  final Color ink;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: _wash(color),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: color == kInk ? const Color(0x2EB2A4A1) : const Color(0xB3B2A4A1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          icon == null
              ? Text(label, style: TextStyle(color: ink.withValues(alpha: 0.7)))
              : Icon(icon, color: iconColor ?? ink, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: kFont,
              fontVariations: kReading,
              color: ink,
              fontSize: 32,
              height: 1.05,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

LinearGradient _wash(Color color) => gradientFor(color);

class _ManageCard extends StatelessWidget {
  const _ManageCard({
    required this.title,
    required this.subtitle,
    required this.onEdit,
    required this.onDelete,
    this.onSuspend,
    this.suspendLabel,
    this.onRecover,
    this.verified,
  });

  final String title;
  final String subtitle;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onSuspend;
  final String? suspendLabel;
  final VoidCallback? onRecover;
  final bool? verified;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: kPaper,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kNavy),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: kInk,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (verified != null) ...<Widget>[
                      const SizedBox(width: 6),
                      verified!
                          ? const Icon(Icons.verified, color: kVerified, size: 16)
                          : const UnverifiedBadge(size: 18),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: kMute, fontSize: 13),
                ),
              ],
            ),
          ),
          if (onRecover != null)
            IconButton(
              tooltip: 'Issue reset code',
              onPressed: onRecover,
              icon: const Icon(Icons.lock_reset, color: kInk),
            ),
          if (onSuspend != null)
            IconButton(
              tooltip: suspendLabel,
              onPressed: onSuspend,
              icon: Icon(
                suspendLabel == 'Restore'
                    ? Icons.play_circle_outline
                    : Icons.pause_circle_outline,
                color: kInk,
              ),
            ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, color: kInk),
          ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: kEmber),
            ),
        ],
      ),
    );
  }
}

class _UserEditor extends StatefulWidget {
  const _UserEditor({required this.person});

  final AppUser person;

  @override
  State<_UserEditor> createState() => _UserEditorState();
}

class _UserEditorState extends State<_UserEditor> {
  late final TextEditingController _prenom;
  late final TextEditingController _nom;
  late final TextEditingController _pays;
  late final TextEditingController _langue;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final AppUser person = widget.person;
    _prenom = TextEditingController(text: person.prenom);
    _nom = TextEditingController(text: person.nom);
    _pays = TextEditingController(text: person.pays);
    _langue = TextEditingController(text: person.langue);
  }

  @override
  void dispose() {
    _prenom.dispose();
    _nom.dispose();
    _pays.dispose();
    _langue.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_prenom.text.trim().isEmpty || _nom.text.trim().isEmpty) {
      setState(() => _error = 'Prénom and nom are required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final AppUser updated = await UserStore.instance.updateProfile(
        id: widget.person.id,
        prenom: _prenom.text.trim(),
        nom: _nom.text.trim(),
        pays: _pays.text.trim(),
        langue: _langue.text.trim(),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(updated);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _EditorFrame(
      title: 'Edit profile',
      saving: _saving,
      error: _error,
      onSave: _save,
      children: <Widget>[
        _Field(label: 'Prénom', controller: _prenom),
        _Field(label: 'Nom', controller: _nom),
        CountryField(
          value: _pays.text,
          onChanged: (String value) => setState(() => _pays.text = value),
        ),
        _Field(label: 'Langue', controller: _langue),
        if (widget.person.isAdmin)
          Text('Rôle: ${widget.person.roleLabel}'),
      ],
    );
  }
}

class _TripEditor extends StatefulWidget {
  const _TripEditor({required this.trip, required this.users});

  final Trip? trip;
  final List<AppUser> users;

  @override
  State<_TripEditor> createState() => _TripEditorState();
}

class _TripEditorState extends State<_TripEditor> {
  late final TextEditingController _titre;
  late final TextEditingController _destination;
  late final TextEditingController _pays;
  late final TextEditingController _depart;
  late final TextEditingController _retour;
  late final TextEditingController _budget;
  late final TextEditingController _people;
  late String _type;
  late String _statut;
  late int _userId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final Trip? trip = widget.trip;
    final DateTime today = DateTime.now();
    String day(DateTime value) {
      final String month = value.month.toString().padLeft(2, '0');
      final String date = value.day.toString().padLeft(2, '0');
      return '${value.year}-$month-$date';
    }

    _titre = TextEditingController(text: trip?.titre ?? '');
    _destination = TextEditingController(text: trip?.destination ?? '');
    _pays = TextEditingController(text: trip?.pays ?? '');
    _depart = TextEditingController(text: trip?.dateDepart ?? day(today));
    _retour = TextEditingController(
      text: trip?.dateRetour ?? day(today.add(const Duration(days: 7))),
    );
    _budget = TextEditingController(
      text: trip == null ? '' : trip.budget.toStringAsFixed(0),
    );
    _people = TextEditingController(
      text: trip == null ? '1' : '${trip.nombreVoyageurs}',
    );
    _type = trip?.typeVoyage ?? 'City';
    _statut = trip?.statut ?? 'Planned';
    final bool ownerExists = widget.users.any(
      (AppUser user) => user.id == trip?.userId,
    );
    _userId = ownerExists ? trip!.userId : widget.users.first.id;
  }

  @override
  void dispose() {
    _titre.dispose();
    _destination.dispose();
    _pays.dispose();
    _depart.dispose();
    _retour.dispose();
    _budget.dispose();
    _people.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final double? budget = double.tryParse(_budget.text.trim());
    final int? people = int.tryParse(_people.text.trim());
    if (_titre.text.trim().isEmpty ||
        _destination.text.trim().isEmpty ||
        _pays.text.trim().isEmpty ||
        budget == null ||
        people == null ||
        people < 1) {
      setState(() => _error = 'Fill the trip fields with a valid budget.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final Trip saved = await UserStore.instance.saveTrip(
        id: widget.trip?.id,
        titre: _titre.text,
        destination: _destination.text,
        pays: _pays.text,
        dateDepart: _depart.text,
        dateRetour: _retour.text,
        budget: budget,
        nombreVoyageurs: people,
        typeVoyage: _type,
        statut: _statut,
        userId: _userId,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _EditorFrame(
      title: widget.trip == null ? 'Add trip' : 'Edit trip',
      saving: _saving,
      error: _error,
      onSave: _save,
      children: <Widget>[
        _Field(label: 'Titre', controller: _titre),
        _Field(label: 'Destination', controller: _destination),
        CountryField(
          label: 'Pays',
          value: _pays.text,
          onChanged: (String value) => setState(() => _pays.text = value),
        ),
        _Field(label: 'Date départ', controller: _depart),
        _Field(label: 'Date retour', controller: _retour),
        _Field(
          label: 'Budget',
          controller: _budget,
          keyboard: TextInputType.number,
          formatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
        ),
        _Field(
          label: 'Nombre de voyageurs',
          controller: _people,
          keyboard: TextInputType.number,
          formatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
        ),
        DropdownButtonFormField<String>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Type de voyage'),
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem<String>(value: 'City', child: Text('City')),
            DropdownMenuItem<String>(value: 'Beach', child: Text('Beach')),
            DropdownMenuItem<String>(value: 'Adventure', child: Text('Adventure')),
          ],
          onChanged: (String? value) {
            if (value != null) {
              setState(() => _type = value);
            }
          },
        ),
        DropdownButtonFormField<String>(
          initialValue: _statut,
          decoration: const InputDecoration(labelText: 'Statut'),
          items: const <DropdownMenuItem<String>>[
            DropdownMenuItem<String>(value: 'Planned', child: Text('Planned')),
            DropdownMenuItem<String>(value: 'Active', child: Text('Active')),
            DropdownMenuItem<String>(value: 'Done', child: Text('Done')),
          ],
          onChanged: (String? value) {
            if (value != null) {
              setState(() => _statut = value);
            }
          },
        ),
        DropdownButtonFormField<int>(
          initialValue: _userId,
          decoration: const InputDecoration(labelText: 'Traveller'),
          items: <DropdownMenuItem<int>>[
            for (final AppUser user in widget.users)
              DropdownMenuItem<int>(value: user.id, child: Text(user.name)),
          ],
          onChanged: (int? value) {
            if (value != null) {
              setState(() => _userId = value);
            }
          },
        ),
      ],
    );
  }
}

class _EditorFrame extends StatelessWidget {
  const _EditorFrame({
    required this.title,
    required this.children,
    required this.saving,
    required this.error,
    required this.onSave,
  });

  final String title;
  final List<Widget> children;
  final bool saving;
  final String? error;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  color: kInk,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              ...children,
              if (error != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: kEmber)),
              ],
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: kInk,
                  foregroundColor: kPaper,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: saving ? null : onSave,
                child: Text(saving ? 'Saving' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.keyboard,
    this.formatters,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? formatters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        inputFormatters: formatters,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
