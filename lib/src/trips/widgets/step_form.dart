import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme.dart';
import '../../trip.dart';
import '../itinerary_step.dart';
import '../trip_repository.dart';
import '../trip_validation.dart';
import 'trip_chrome.dart';

class StepEditorPage extends StatefulWidget {
  const StepEditorPage({
    super.key,
    required this.userId,
    required this.dayId,
    this.initial,
    this.suggestedSortOrder,
    this.repository,
    this.presetTitle,
    this.presetLocation,
  });

  final int userId;
  final int dayId;
  final ItineraryStep? initial;
  final int? suggestedSortOrder;
  final TripRepository? repository;
  final String? presetTitle;
  final String? presetLocation;

  @override
  State<StepEditorPage> createState() => _StepEditorPageState();
}

class _StepEditorPageState extends State<StepEditorPage> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _start;
  late final TextEditingController _end;
  late final TextEditingController _cost;
  late final TextEditingController _location;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final ItineraryStep? step = widget.initial;
    _title = TextEditingController(
      text: step?.title ?? widget.presetTitle ?? '',
    );
    _description = TextEditingController(text: step?.description ?? '');
    _start = TextEditingController(text: step?.startTime ?? '');
    _end = TextEditingController(text: step?.endTime ?? '');
    _cost = TextEditingController(
      text: step == null || step.estimatedCost == 0
          ? ''
          : formatBudget(step.estimatedCost),
    );
    _location = TextEditingController(
      text: step?.location ?? widget.presetLocation ?? '',
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _start.dispose();
    _end.dispose();
    _cost.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final double? cost = _cost.text.trim().isEmpty
        ? 0
        : double.tryParse(_cost.text.trim().replaceAll(',', '.'));
    final StepDraft draft = StepDraft(
      title: _title.text,
      description: _description.text,
      startTime: _start.text.trim(),
      endTime: _end.text.trim(),
      estimatedCost: cost ?? -1,
      location: _location.text,
      sortOrder: widget.initial?.sortOrder ?? widget.suggestedSortOrder ?? 0,
    );
    final String? localError = TripValidation.validateStep(draft);
    if (localError != null) {
      setState(() => _error = localError);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final TripRepository repository =
          widget.repository ?? await TripRepository.attached();
      final ItineraryStep? initial = widget.initial;
      if (initial == null) {
        await repository.createStep(
          userId: widget.userId,
          dayId: widget.dayId,
          draft: draft,
        );
      } else {
        await repository.updateStep(
          userId: widget.userId,
          stepId: initial.id,
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
    final bool editing = widget.initial != null;
    return TripScaffold(
      title: editing ? 'Modifier l’activité' : 'Nouvelle activité',
      bottom: TripPrimaryButton(
        label: _saving ? 'Enregistrement…' : 'Enregistrer',
        onPressed: _saving ? null : _save,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        children: <Widget>[
          TripFieldShell(
            label: 'Nom de l’activité',
            child: TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              style: _valueStyle,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: 'Visite de la médina',
              ),
            ),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: TripFieldShell(
                  label: 'Début (HH:MM)',
                  child: TextField(
                    controller: _start,
                    style: _valueStyle,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: '09:00',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TripFieldShell(
                  label: 'Fin (HH:MM)',
                  child: TextField(
                    controller: _end,
                    style: _valueStyle,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      hintText: '11:30',
                    ),
                  ),
                ),
              ),
            ],
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
                hintText: 'Détails, réservation, conseils…',
              ),
            ),
          ),
          TripFieldShell(
            label: 'Lieu',
            child: TextField(
              controller: _location,
              style: _valueStyle,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: 'Adresse ou quartier',
              ),
            ),
          ),
          TripFieldShell(
            label: 'Coût estimé',
            child: TextField(
              controller: _cost,
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
