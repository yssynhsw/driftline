import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme.dart';
import '../../trip.dart';
import '../itinerary_day.dart';
import '../trip_repository.dart';
import '../trip_validation.dart';
import 'trip_chrome.dart';

class DayEditorPage extends StatefulWidget {
  const DayEditorPage({
    super.key,
    required this.title,
    required this.userId,
    required this.trip,
    this.initial,
    this.suggestedNumber,
    this.suggestedDate,
    this.repository,
  });

  final String title;
  final int userId;
  final Trip trip;
  final ItineraryDay? initial;
  final int? suggestedNumber;
  final String? suggestedDate;
  final TripRepository? repository;

  @override
  State<DayEditorPage> createState() => _DayEditorPageState();
}

class _DayEditorPageState extends State<DayEditorPage> {
  late final TextEditingController _number;
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _budget;
  late final TextEditingController _notes;
  DateTime? _date;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final ItineraryDay? day = widget.initial;
    _number = TextEditingController(
      text: '${day?.dayNumber ?? widget.suggestedNumber ?? 1}',
    );
    _title = TextEditingController(text: day?.title ?? '');
    _description = TextEditingController(text: day?.description ?? '');
    _budget = TextEditingController(
      text: day == null ? '' : formatBudget(day.estimatedBudget),
    );
    _notes = TextEditingController(text: day?.notes ?? '');
    _date = calendarDate(day?.date ?? widget.suggestedDate ?? '');
  }

  @override
  void dispose() {
    _number.dispose();
    _title.dispose();
    _description.dispose();
    _budget.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? first = calendarDate(widget.trip.dateDepart);
    final DateTime? last = calendarDate(widget.trip.dateRetour);
    if (first == null || last == null) {
      setState(() => _error = 'Les dates du voyage sont invalides.');
      return;
    }
    final DateTime initial = _date ?? first;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) || initial.isAfter(last) ? first : initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _save() async {
    final double? budget = double.tryParse(
      _budget.text.trim().replaceAll(',', '.'),
    );
    final DayDraft draft = DayDraft(
      dayNumber: int.tryParse(_number.text.trim()) ?? 0,
      date: _date == null ? '' : storeCalendarDate(_date!),
      title: _title.text,
      description: _description.text,
      estimatedBudget: budget ?? -1,
      notes: _notes.text,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final TripRepository repository =
          widget.repository ?? await TripRepository.attached();
      final ItineraryDay? initial = widget.initial;
      if (initial == null) {
        await repository.createItineraryDay(
          userId: widget.userId,
          tripId: widget.trip.id,
          draft: draft,
        );
      } else {
        await repository.updateItineraryDay(
          userId: widget.userId,
          dayId: initial.id,
          draft: draft,
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
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
    return TripScaffold(
      title: widget.title,
      bottom: TripPrimaryButton(
        label: _saving ? 'Enregistrement…' : 'Enregistrer',
        onPressed: _saving ? null : _save,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        children: <Widget>[
          Text(
            '${widget.trip.titre} · ${displayCalendarDate(widget.trip.dateDepart)} – ${displayCalendarDate(widget.trip.dateRetour)}',
            style: const TextStyle(color: kMute, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          TripFieldShell(
            label: 'Numéro du jour',
            child: TextField(
              controller: _number,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: _valueStyle,
              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
            ),
          ),
          TripFieldShell(
            label: 'Date',
            child: InkWell(
              onTap: _pickDate,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _date == null
                            ? 'Choisir une date'
                            : displayCalendarDate(storeCalendarDate(_date!)),
                        style: TextStyle(
                          color: _date == null ? kMute : kInk,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(Icons.calendar_today_outlined, size: 18, color: kInk),
                  ],
                ),
              ),
            ),
          ),
          TripFieldShell(
            label: 'Titre du programme',
            child: TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              style: _valueStyle,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: 'Médina et remparts',
              ),
            ),
          ),
          TripFieldShell(
            label: 'Description',
            child: TextField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: _valueStyle,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: 'Matinée dans la médina, après-midi sur la plage.',
              ),
            ),
          ),
          TripFieldShell(
            label: 'Budget estimé',
            child: TextField(
              controller: _budget,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style: _valueStyle,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: '0',
              ),
            ),
          ),
          TripFieldShell(
            label: 'Notes',
            child: TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              style: _valueStyle,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: 'Réserver le soir.',
              ),
            ),
          ),
          if (_error != null)
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFB3261E),
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

const TextStyle _valueStyle = TextStyle(
  color: kInk,
  fontSize: 16,
  fontWeight: FontWeight.w700,
);
