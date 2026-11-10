import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../trip.dart';
import '../conflict_service.dart';
import '../itinerary_day.dart';
import '../itinerary_step.dart';
import '../trip_repository.dart';
import '../widgets/itinerary_day_form.dart';
import '../widgets/step_form.dart';
import '../widgets/trip_chrome.dart';
import 'edit_itinerary_screen.dart';

class ItineraryDayScreen extends StatelessWidget {
  const ItineraryDayScreen({
    super.key,
    required this.userId,
    required this.trip,
    this.day,
    this.suggestedNumber,
    this.suggestedDate,
    this.repository,
  });

  final int userId;
  final Trip trip;
  final ItineraryDay? day;
  final int? suggestedNumber;
  final String? suggestedDate;
  final TripRepository? repository;

  @override
  Widget build(BuildContext context) {
    final ItineraryDay? current = day;
    if (current == null) {
      return DayEditorPage(
        title: 'Ajouter un programme',
        userId: userId,
        trip: trip,
        suggestedNumber: suggestedNumber,
        suggestedDate: suggestedDate,
        repository: repository,
      );
    }
    return _DayDetails(
      userId: userId,
      trip: trip,
      day: current,
      repository: repository,
    );
  }
}

class _DayDetails extends StatefulWidget {
  const _DayDetails({
    required this.userId,
    required this.trip,
    required this.day,
    this.repository,
  });

  final int userId;
  final Trip trip;
  final ItineraryDay day;
  final TripRepository? repository;

  @override
  State<_DayDetails> createState() => _DayDetailsState();
}

class _DayDetailsState extends State<_DayDetails> {
  late ItineraryDay _day;
  List<ItineraryStep> _steps = const <ItineraryStep>[];
  List<ScheduleConflict> _conflicts = const <ScheduleConflict>[];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _day = widget.day;
    _load();
  }

  Future<TripRepository> _repo() async {
    return widget.repository ?? await TripRepository.attached();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final TripRepository repository = await _repo();
      final List<ItineraryDay> days = await repository.getDaysByTripId(
        tripId: widget.trip.id,
        userId: widget.userId,
      );
      ItineraryDay? refreshed;
      for (final ItineraryDay day in days) {
        if (day.id == _day.id) {
          refreshed = day;
        }
      }
      final List<ItineraryStep> steps = await repository.getStepsForDay(
        userId: widget.userId,
        dayId: _day.id,
      );
      final List<ScheduleConflict> conflicts =
          await repository.conflictsForTrip(
        userId: widget.userId,
        tripId: widget.trip.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        if (refreshed != null) {
          _day = refreshed;
        }
        _steps = steps;
        _conflicts = conflicts
            .where(
              (ScheduleConflict c) =>
                  c.dayId == _day.id ||
                  steps.any((ItineraryStep s) => s.id == c.stepId),
            )
            .toList();
        _loading = false;
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

  double get _dayTotal =>
      _steps.fold<double>(0, (double sum, ItineraryStep s) => sum + s.estimatedCost);

  Future<void> _editDay() async {
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => EditItineraryScreen(
          userId: widget.userId,
          trip: widget.trip,
          day: _day,
          repository: widget.repository,
        ),
      ),
    );
    if (saved == true && mounted) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _addStep({String? title, String? location}) async {
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => StepEditorPage(
          userId: widget.userId,
          dayId: _day.id,
          suggestedSortOrder: _steps.length + 1,
          repository: widget.repository,
          presetTitle: title,
          presetLocation: location,
        ),
      ),
    );
    if (saved == true && mounted) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _editStep(ItineraryStep step) async {
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => StepEditorPage(
          userId: widget.userId,
          dayId: _day.id,
          initial: step,
          repository: widget.repository,
        ),
      ),
    );
    if (saved == true && mounted) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _deleteStep(ItineraryStep step) async {
    final bool confirmed = await confirmTripAction(
      context,
      title: 'Supprimer cette activité ?',
      message: step.title,
      confirmLabel: 'Supprimer',
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      final TripRepository repository = await _repo();
      await repository.deleteStep(userId: widget.userId, stepId: step.id);
      _changed = true;
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = '$error';
      });
      return;
    }
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  Future<void> _moveStep(int index, int delta) async {
    final int target = index + delta;
    if (target < 0 || target >= _steps.length) {
      return;
    }
    final List<ItineraryStep> next = List<ItineraryStep>.from(_steps);
    final ItineraryStep item = next.removeAt(index);
    next.insert(target, item);
    setState(() {
      _steps = next;
      _busy = true;
    });
    try {
      final TripRepository repository = await _repo();
      await repository.reorderSteps(
        userId: widget.userId,
        dayId: _day.id,
        orderedStepIds: next.map((ItineraryStep s) => s.id).toList(),
      );
      _changed = true;
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = '$error');
      await _load();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteDay() async {
    final bool confirmed = await confirmTripAction(
      context,
      title: 'Supprimer cette journée ?',
      message: 'Jour ${_day.dayNumber} · ${_day.title}\n'
          'Les activités associées seront aussi supprimées.',
      confirmLabel: 'Supprimer',
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      final TripRepository repository = await _repo();
      await repository.deleteItineraryDay(
        userId: widget.userId,
        dayId: _day.id,
      );
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
        title: 'Jour ${_day.dayNumber}',
        bottom: TripPrimaryButton(
          label: 'Ajouter une activité',
          onPressed: _loading || _busy ? null : () => _addStep(),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
                  children: <Widget>[
                    TripPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _day.title,
                            style: const TextStyle(
                              color: kInk,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            displayCalendarDate(_day.date),
                            style: const TextStyle(
                              color: kMute,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (_day.description.trim().isNotEmpty) ...<Widget>[
                            const SizedBox(height: 12),
                            Text(
                              _day.description,
                              style: const TextStyle(
                                color: kInk,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          _MetaLine(
                            label: 'Activités',
                            value: '${_steps.length}',
                          ),
                          _MetaLine(
                            label: 'Coût total du jour',
                            value: formatBudget(_dayTotal),
                          ),
                          if (_day.notes.trim().isNotEmpty)
                            _MetaLine(label: 'Notes', value: _day.notes),
                        ],
                      ),
                    ),
                    if (_conflicts.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      TripPanel(
                        color: const Color(0xFFFFE8E6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'Conflits détectés',
                              style: TextStyle(
                                color: Color(0xFFB42318),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            for (final ScheduleConflict conflict in _conflicts)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  conflict.message,
                                  style: const TextStyle(
                                    color: Color(0xFFB42318),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFB3261E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    const Text(
                      'Activités',
                      style: TextStyle(
                        color: kInk,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_steps.isEmpty)
                      TripPanel(
                        color: kMint,
                        child: const Text(
                          'Aucune activité pour cette journée.\n'
                          'Ajoute une visite, un repas ou un trajet.',
                          style: TextStyle(
                            color: kInk,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      )
                    else
                      for (int i = 0; i < _steps.length; i++) ...<Widget>[
                        _StepCard(
                          step: _steps[i],
                          index: i,
                          total: _steps.length,
                          enabled: !_busy,
                          onEdit: () => _editStep(_steps[i]),
                          onDelete: () => _deleteStep(_steps[i]),
                          onMoveUp: () => _moveStep(i, -1),
                          onMoveDown: () => _moveStep(i, 1),
                        ),
                        const SizedBox(height: 10),
                      ],
                    const SizedBox(height: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kInk,
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: kInk),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: _busy ? null : _editDay,
                      child: const Text('Modifier la journée'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB3261E),
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: Color(0xFFB3261E)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: _busy ? null : _deleteDay,
                      child: const Text('Supprimer la journée'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 140,
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

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.index,
    required this.total,
    required this.enabled,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final ItineraryStep step;
  final int index;
  final int total;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    return TripPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  step.title,
                  style: const TextStyle(
                    color: kInk,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Monter',
                onPressed: enabled && index > 0 ? onMoveUp : null,
                icon: const Icon(Icons.arrow_upward_rounded, size: 20),
              ),
              IconButton(
                tooltip: 'Descendre',
                onPressed: enabled && index < total - 1 ? onMoveDown : null,
                icon: const Icon(Icons.arrow_downward_rounded, size: 20),
              ),
            ],
          ),
          Text(
            step.timeRangeLabel,
            style: const TextStyle(color: kMute, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Durée : ${step.durationLabel} · Coût : ${formatBudget(step.estimatedCost)}',
            style: const TextStyle(color: kInk, fontWeight: FontWeight.w600),
          ),
          if (step.location.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              step.location,
              style: const TextStyle(color: kMute, fontWeight: FontWeight.w600),
            ),
          ],
          if (step.description.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              step.description,
              style: const TextStyle(color: kInk, height: 1.35),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              TextButton(
                onPressed: enabled ? onEdit : null,
                child: const Text('Modifier'),
              ),
              TextButton(
                onPressed: enabled ? onDelete : null,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFB3261E),
                ),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
