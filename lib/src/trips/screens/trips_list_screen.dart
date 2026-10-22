import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../trip.dart';
import '../trip_repository.dart';
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
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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
      if (!mounted) {
        return;
      }
      setState(() {
        _repository = repository;
        _trips = trips;
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
    if (_trips.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
        children: const <Widget>[
          TripPanel(
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
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Tes voyages enregistrés',
            style: TextStyle(color: kMute, fontWeight: FontWeight.w600),
          ),
        ),
        for (final Trip trip in _trips)
          TripCard(trip: trip, onTap: () => _openDetails(trip)),
      ],
    );
  }
}
