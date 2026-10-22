import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../trip.dart';
import '../itinerary_day.dart';
import '../trip_repository.dart';
import '../widgets/itinerary_day_form.dart';
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
  String? _error;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _day = widget.day;
  }

  Future<void> _edit() async {
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
      final TripRepository repository =
          widget.repository ?? await TripRepository.attached();
      final List<ItineraryDay> days = await repository.getDaysByTripId(
        tripId: widget.trip.id,
        userId: widget.userId,
      );
      ItineraryDay? updated;
      for (final ItineraryDay day in days) {
        if (day.id == _day.id) {
          updated = day;
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _changed = true;
        if (updated != null) {
          _day = updated;
        }
      });
    }
  }

  Future<void> _delete() async {
    final bool confirmed = await confirmTripAction(
      context,
      title: 'Supprimer cette journée ?',
      message: 'Jour ${_day.dayNumber} · ${_day.title}',
      confirmLabel: 'Supprimer',
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      final TripRepository repository =
          widget.repository ?? await TripRepository.attached();
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
        body: ListView(
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
                    style: const TextStyle(color: kMute, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  _Line(label: 'Programme', value: _day.description),
                  _Line(
                    label: 'Budget estimé',
                    value: formatBudget(_day.estimatedBudget),
                  ),
                  _Line(label: 'Notes', value: _day.notes),
                ],
              ),
            ),
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
            const SizedBox(height: 16),
            TripPrimaryButton(label: 'Modifier', onPressed: _edit),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB3261E),
                minimumSize: const Size.fromHeight(52),
                side: const BorderSide(color: Color(0xFFB3261E)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: _delete,
              child: const Text('Supprimer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final String shown = value.trim().isEmpty ? '—' : value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(color: kMute, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            shown,
            style: const TextStyle(color: kInk, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
