import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../trip.dart';
import '../trip_repository.dart';
import '../widgets/trip_chrome.dart';
import 'edit_trip_screen.dart';
import 'itinerary_screen.dart';

class TripDetailsScreen extends StatefulWidget {
  const TripDetailsScreen({
    super.key,
    required this.userId,
    required this.tripId,
    this.repository,
  });

  final int userId;
  final int tripId;
  final TripRepository? repository;

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  TripRepository? _repository;
  Trip? _trip;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<TripRepository> _repo() async {
    return _repository ?? widget.repository ?? await TripRepository.attached();
  }

  Future<void> _load() async {
    try {
      final TripRepository repository = await _repo();
      final Trip? trip = await repository.getTripById(
        id: widget.tripId,
        userId: widget.userId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _repository = repository;
        _trip = trip;
        _loading = false;
        _error = trip == null ? 'Voyage introuvable.' : null;
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

  Future<void> _edit() async {
    final Trip? trip = _trip;
    if (trip == null) {
      return;
    }
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => EditTripScreen(
          userId: widget.userId,
          trip: trip,
          repository: _repository ?? widget.repository,
        ),
      ),
    );
    if (saved == true) {
      await _load();
    }
  }

  Future<void> _delete() async {
    final Trip? trip = _trip;
    if (trip == null) {
      return;
    }
    final bool confirmed = await confirmTripAction(
      context,
      title: 'Supprimer ce voyage ?',
      message: '« ${trip.titre} » et toutes ses journées seront supprimés.',
      confirmLabel: 'Supprimer',
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      final TripRepository repository = await _repo();
      await repository.deleteTrip(id: trip.id, userId: widget.userId);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = '$error');
    }
  }

  Future<void> _openItinerary() async {
    final Trip? trip = _trip;
    if (trip == null) {
      return;
    }
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => ItineraryScreen(
          userId: widget.userId,
          tripId: trip.id,
          repository: _repository ?? widget.repository,
        ),
      ),
    );
    if (changed == true && mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TripScaffold(
      title: 'Détails du voyage',
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: kInk));
    }
    final Trip? trip = _trip;
    if (trip == null) {
      return Padding(
        padding: const EdgeInsets.all(22),
        child: Text(
          _error ?? 'Voyage introuvable.',
          style: const TextStyle(color: Color(0xFFB3261E), fontWeight: FontWeight.w600),
        ),
      );
    }
    final int days = trip.durationDays;
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
      children: <Widget>[
        TripPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      trip.titre,
                      style: const TextStyle(
                        color: kInk,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  TripStatusChip(status: trip.statut),
                ],
              ),
              const SizedBox(height: 14),
              _Detail(label: 'Destination', value: trip.destination),
              _Detail(label: 'Pays', value: trip.pays),
              _Detail(
                label: 'Dates',
                value:
                    '${displayCalendarDate(trip.dateDepart)} – ${displayCalendarDate(trip.dateRetour)}',
              ),
              _Detail(
                label: 'Durée',
                value: days <= 1 ? '$days jour' : '$days jours',
              ),
              _Detail(label: 'Budget', value: formatBudget(trip.budget)),
              _Detail(label: 'Voyageurs', value: '${trip.nombreVoyageurs}'),
              _Detail(label: 'Type', value: trip.typeVoyage),
            ],
          ),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: Color(0xFFB3261E), fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 16),
        TripPrimaryButton(label: 'Voir l’itinéraire', onPressed: _openItinerary),
        const SizedBox(height: 10),
        TripPrimaryButton(label: 'Modifier', onPressed: _edit),
        const SizedBox(height: 10),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFB3261E),
            minimumSize: const Size.fromHeight(52),
            side: const BorderSide(color: Color(0xFFB3261E)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            textStyle: const TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          onPressed: _delete,
          child: const Text('Supprimer'),
        ),
      ],
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: kMute, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: kInk, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
