import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../trip.dart';
import '../budget_engine.dart';
import '../conflict_service.dart';
import '../itinerary_day.dart';
import '../trip_repository.dart';
import '../widgets/itinerary_day_card.dart';
import '../widgets/trip_chrome.dart';
import '../widgets/weather_panel.dart';
import 'ai_itinerary_screen.dart';
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
  TripRepository? _repository;
  Trip? _trip;
  List<ItineraryDay> _days = const <ItineraryDay>[];
  BudgetBreakdown? _budget;
  List<ScheduleConflict> _conflicts = const <ScheduleConflict>[];
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
      BudgetBreakdown? budget;
      List<ScheduleConflict> conflicts = const <ScheduleConflict>[];
      if (trip != null) {
        budget = await repository.budgetForTrip(
          userId: widget.userId,
          tripId: trip.id,
        );
        conflicts = await repository.conflictsForTrip(
          userId: widget.userId,
          tripId: trip.id,
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _repository = repository;
        _trip = trip;
        _days = days;
        _budget = budget;
        _conflicts = conflicts;
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

  Future<void> _openAi() async {
    final Trip? trip = _trip;
    if (trip == null) {
      return;
    }
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => AiItineraryScreen(
          userId: widget.userId,
          trip: trip,
          repository: _repository ?? widget.repository,
        ),
      ),
    );
    if (saved == true) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _moveDay(ItineraryDay day, int delta) async {
    final int index = _days.indexWhere((ItineraryDay item) => item.id == day.id);
    final int target = index + delta;
    if (index < 0 || target < 0 || target >= _days.length) {
      return;
    }
    final List<ItineraryDay> ordered = List<ItineraryDay>.from(_days);
    final ItineraryDay moved = ordered.removeAt(index);
    ordered.insert(target, moved);
    try {
      final TripRepository repository = await _repo();
      await repository.reorderItineraryDays(
        userId: widget.userId,
        tripId: widget.tripId,
        orderedDayIds: ordered.map((ItineraryDay item) => item.id).toList(),
      );
      _changed = true;
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = '$error');
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
    final BudgetBreakdown? budget = _budget;
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
        if (budget != null) ...<Widget>[
          const SizedBox(height: 12),
          TripPanel(
            child: Text(
              'Budget planifié ${formatBudget(budget.plannedTotal)} / ${formatBudget(budget.tripBudget)}'
              '${budget.overBudget ? ' · dépassement' : ''}',
              style: TextStyle(
                color: budget.overBudget ? const Color(0xFFB3261E) : kInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        if (_conflicts.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          TripPanel(
            color: const Color(0xFFFFF1D6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Attention planning',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                for (final ScheduleConflict conflict in _conflicts.take(4))
                  Text('• ${conflict.message}'),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        WeatherPanel(
          trip: trip,
          autoload: !const bool.fromEnvironment('FLUTTER_TEST'),
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
            Column(
              children: <Widget>[
                ItineraryDayCard(day: day, onTap: () => _openDay(day)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Monter',
                      onPressed: () => _moveDay(day, -1),
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                    IconButton(
                      tooltip: 'Descendre',
                      onPressed: () => _moveDay(day, 1),
                      icon: const Icon(Icons.arrow_downward_rounded),
                    ),
                  ],
                ),
              ],
            ),
        const SizedBox(height: 8),
        TripPrimaryButton(label: 'Ajouter un programme', onPressed: _addDay),
        const SizedBox(height: 10),
        TripPrimaryButton(
          label: 'Générer avec Gemini AI',
          onPressed: _openAi,
        ),
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
