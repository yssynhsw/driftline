import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../trip.dart';
import '../itinerary_day.dart';
import '../trip_repository.dart';
import '../trip_services.dart';
import '../widgets/itinerary_day_card.dart';
import '../widgets/trip_chrome.dart';
import 'itinerary_day_screen.dart';

class ItineraryScreen extends StatefulWidget {
  const ItineraryScreen({
    super.key,
    required this.userId,
    required this.tripId,
    this.repository,
  });

  final int userId;
  final int tripId;
  final TripRepository? repository;

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  static const ItineraryGenerator _generator = UnavailableItineraryGenerator();
  static const DestinationForecast _forecast = UnavailableDestinationForecast();

  TripRepository? _repository;
  Trip? _trip;
  List<ItineraryDay> _days = const <ItineraryDay>[];
  bool _loading = true;
  String? _error;
  bool _changed = false;

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
      final List<ItineraryDay> days = trip == null
          ? const <ItineraryDay>[]
          : await repository.getDaysByTripId(
              tripId: trip.id,
              userId: widget.userId,
            );
      if (!mounted) {
        return;
      }
      setState(() {
        _repository = repository;
        _trip = trip;
        _days = days;
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

  Future<void> _addDay() async {
    final Trip? trip = _trip;
    if (trip == null) {
      return;
    }
    final int nextNumber = _days.isEmpty
        ? 1
        : _days
                  .map((ItineraryDay day) => day.dayNumber)
                  .reduce((int a, int b) => a > b ? a : b) +
              1;
    final DateTime? depart = calendarDate(trip.dateDepart);
    final DateTime? retour = calendarDate(trip.dateRetour);
    DateTime? suggested = depart?.add(Duration(days: nextNumber - 1));
    if (suggested != null && retour != null && suggested.isAfter(retour)) {
      suggested = retour;
    }
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => ItineraryDayScreen(
          userId: widget.userId,
          trip: trip,
          suggestedNumber: nextNumber,
          suggestedDate: suggested == null ? null : storeCalendarDate(suggested),
          repository: _repository ?? widget.repository,
        ),
      ),
    );
    if (saved == true) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _openDay(ItineraryDay day) async {
    final Trip? trip = _trip;
    if (trip == null) {
      return;
    }
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => ItineraryDayScreen(
          userId: widget.userId,
          trip: trip,
          day: day,
          repository: _repository ?? widget.repository,
        ),
      ),
    );
    if (changed == true) {
      _changed = true;
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (didPop) {
          return;
        }
        Navigator.of(context).pop(_changed);
      },
      child: TripScaffold(
        title: 'Itinéraire',
        body: _buildBody(),
      ),
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
        child: Text(_error ?? 'Voyage introuvable.'),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
      children: <Widget>[
        Text(
          trip.titre,
          style: const TextStyle(
            color: kInk,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${displayCalendarDate(trip.dateDepart)} – ${displayCalendarDate(trip.dateRetour)}',
          style: const TextStyle(color: kMute, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        if (_days.isEmpty)
          const TripPanel(
            color: kMint,
            child: Text(
              'Aucune journée pour le moment.',
              style: TextStyle(
                color: kInk,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          )
        else
          for (final ItineraryDay day in _days)
            ItineraryDayCard(day: day, onTap: () => _openDay(day)),
        const SizedBox(height: 8),
        TripPrimaryButton(label: 'Ajouter un programme', onPressed: _addDay),
        const SizedBox(height: 10),
        TripPrimaryButton(
          label: 'Générer avec IA · Bientôt disponible',
          onPressed: _generator.isAvailable ? _addDay : null,
        ),
        if (!_forecast.isAvailable) ...<Widget>[
          const SizedBox(height: 12),
          const Text(
            'Prévisions météo · Bientôt disponible',
            textAlign: TextAlign.center,
            style: TextStyle(color: kMute, fontWeight: FontWeight.w600),
          ),
        ],
        if (_error != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: Color(0xFFB3261E), fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}
