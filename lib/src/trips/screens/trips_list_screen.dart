import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../trip.dart';
import '../trip_repository.dart';
import '../trip_stats.dart';
import '../widgets/trip_card.dart';
import '../widgets/trip_chrome.dart';
import 'create_trip_screen.dart';
import 'trip_details_screen.dart';

class TripsListScreen extends StatefulWidget {
  const TripsListScreen({super.key, required this.userId, this.repository});

  final int userId;
  final TripRepository? repository;

  @override
  State<TripsListScreen> createState() => _TripsListScreenState();
}

class _TripsListScreenState extends State<TripsListScreen> {
  TripRepository? _repository;
  List<Trip> _trips = const <Trip>[];
  TripDashboardStats? _stats;
  bool _loading = true;
  String? _error;
  final TextEditingController _search = TextEditingController();
  String _status = 'Tous';
  String _type = 'Tous';
  String _sortBy = 'date';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();
    _load();
  }

  Future<TripRepository> _repo() async {
    return _repository ?? widget.repository ?? await TripRepository.attached();
  }

  Future<void> _load() async {
    try {
      final TripRepository repository = await _repo();
      if (widget.repository == null) {
        await repository.ensureExampleTrips(widget.userId);
      }
      final List<Trip> trips = await repository.getAllTrips(widget.userId);
      final TripDashboardStats stats =
          await repository.dashboardStats(widget.userId);
      if (!mounted) {
        return;
      }
      setState(() {
        _repository = repository;
        _trips = trips;
        _stats = stats;
        _loading = false;
        _error = null;
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

  List<Trip> get _visible {
    final TripRepository? repository = _repository;
    if (repository == null) {
      return _trips;
    }
    return repository.filterAndSortTrips(
      trips: _trips,
      query: _search.text,
      status: _status,
      type: _type,
      sortBy: _sortBy,
    );
  }

  Future<void> _openCreate() async {
    final TripRepository? repository = _repository ?? widget.repository;
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => CreateTripScreen(
          userId: widget.userId,
          repository: repository,
        ),
      ),
    );
    if (saved == true) {
      await _load();
    }
  }

  Future<void> _openDetails(Trip trip) async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => TripDetailsScreen(
          userId: widget.userId,
          tripId: trip.id,
          repository: _repository ?? widget.repository,
        ),
      ),
    );
    if (changed == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TripScaffold(
      title: 'Mes voyages',
      bottom: TripPrimaryButton(
        label: 'Nouveau voyage',
        onPressed: _loading ? null : _openCreate,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kInk));
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
        children: <Widget>[
          TripPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Impossible de charger les voyages.',
                  style: TextStyle(
                    color: kInk,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Color(0xFFB3261E))),
                const SizedBox(height: 12),
                TextButton(onPressed: _load, child: const Text('Réessayer')),
              ],
            ),
          ),
        ],
      );
    }

    final List<Trip> visible = _visible;
    final TripDashboardStats? stats = _stats;

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      children: <Widget>[
        if (stats != null) ...<Widget>[
          TripPanel(
            color: kGold,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Tableau de bord',
                  style: TextStyle(
                    color: kInk,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  children: <Widget>[
                    _Stat('Total', '${stats.totalTrips}'),
                    _Stat('À venir', '${stats.upcoming}'),
                    _Stat('En cours', '${stats.active}'),
                    _Stat('Terminés', '${stats.completed}'),
                    _Stat('Jours planifiés', '${stats.totalPlannedDays}'),
                    _Stat('Budget total', formatBudget(stats.totalBudget)),
                    _Stat('Budget moyen', formatBudget(stats.averageBudget)),
                    if (stats.topDestination != null)
                      _Stat('Top destination', stats.topDestination!),
                  ],
                ),
                if (stats.nextTrip != null) ...<Widget>[
                  const SizedBox(height: 14),
                  Text(
                    'Prochain : ${stats.nextTrip!.titre}',
                    style: const TextStyle(
                      color: kInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: stats.nextTripProgress,
                      minHeight: 8,
                      backgroundColor: kPaper.withValues(alpha: 0.54),
                      color: kInk,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        TripFieldShell(
          label: 'Rechercher',
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Titre ou destination',
            ),
          ),
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: TripFieldShell(
                label: 'Statut',
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _status,
                    isExpanded: true,
                    items: <String>[
                      'Tous',
                      ...kTripStatuses,
                    ]
                        .map(
                          (String value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value == 'Tous'
                                  ? 'Tous'
                                  : tripStatusLabel(value),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (String? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => _status = value);
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TripFieldShell(
                label: 'Type',
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _type,
                    isExpanded: true,
                    items: <String>['Tous', ...kTripTypes]
                        .map(
                          (String value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (String? value) {
                      if (value == null) {
                        return;
                      }
                      setState(() => _type = value);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        TripFieldShell(
          label: 'Trier par',
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _sortBy,
              isExpanded: true,
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem(value: 'date', child: Text('Date de départ')),
                DropdownMenuItem(value: 'budget', child: Text('Budget')),
                DropdownMenuItem(value: 'creation', child: Text('Création')),
              ],
              onChanged: (String? value) {
                if (value == null) {
                  return;
                }
                setState(() => _sortBy = value);
              },
            ),
          ),
        ),
        if (_trips.isEmpty)
          const TripPanel(
            color: kMint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Aucun voyage pour le moment.',
                  style: TextStyle(
                    color: kInk,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Crée un voyage avec sa destination, ses dates et son budget.',
                  style: TextStyle(color: kInk, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          )
        else if (visible.isEmpty)
          const TripPanel(
            color: kMint,
            child: Text(
              'Aucun voyage ne correspond à ces filtres.',
              style: TextStyle(
                color: kInk,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          )
        else
          for (final Trip trip in visible)
            TripCard(trip: trip, onTap: () => _openDetails(trip)),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(color: kMute, fontSize: 12)),
          Text(
            value,
            style: const TextStyle(
              color: kInk,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
