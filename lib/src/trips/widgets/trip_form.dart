import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../countries.dart';
import '../../theme.dart';
import '../../trip.dart';
import '../destination_cover.dart';
import '../trip_repository.dart';
import '../trip_validation.dart';
import 'destination_photo.dart';
import 'trip_chrome.dart';

class TripEditorPage extends StatefulWidget {
  const TripEditorPage({
    super.key,
    required this.title,
    required this.userId,
    this.initial,
    this.showStatus = false,
    this.repository,
  });

  final String title;
  final int userId;
  final Trip? initial;
  final bool showStatus;
  final TripRepository? repository;

  @override
  State<TripEditorPage> createState() => _TripEditorPageState();
}

class _TripEditorPageState extends State<TripEditorPage> {
  late final TextEditingController _titre;
  late final TextEditingController _destination;
  late final TextEditingController _budget;
  late final TextEditingController _people;
  late String _pays;
  late String _type;
  late String _statut;
  DateTime? _depart;
  DateTime? _retour;
  bool _saving = false;
  String? _error;
  Timer? _coverDebounce;
  DestinationCoverResult? _coverPreview;
  bool _coverLoading = false;
  bool _coverAttempted = false;
  int _coverRequestId = 0;
  String _coverLoadedCountry = '';

  @override
  void initState() {
    super.initState();
    final Trip? trip = widget.initial;
    _titre = TextEditingController(text: trip?.titre ?? '');
    _destination = TextEditingController(text: trip?.destination ?? '');
    _budget = TextEditingController(
      text: trip == null ? '' : formatBudget(trip.budget),
    );
    _people = TextEditingController(
      text: trip == null ? '1' : '${trip.nombreVoyageurs}',
    );
    _pays = trip?.pays ?? '';
    _type = trip?.typeVoyage ?? kTripTypes.first;
    _statut = trip?.statut ?? 'Planned';
    _depart = trip == null ? null : calendarDate(trip.dateDepart);
    _retour = trip == null ? null : calendarDate(trip.dateRetour);
    if ((trip?.coverPhotoUrl ?? '').trim().isNotEmpty) {
      _coverPreview = DestinationCoverResult(
        imageUrl: trip!.coverPhotoUrl,
        matchLevel: trip.coverMatchLevel.isEmpty
            ? DestinationCoverResult.levelExact
            : trip.coverMatchLevel,
        resolvedPlace: trip.pays.isNotEmpty ? trip.pays : trip.destination,
        credit: trip.coverPhotoCredit,
        country: trip.pays,
      );
      _coverLoadedCountry = trip.pays.trim().toLowerCase();
    } else if (_pays.trim().isNotEmpty) {
      _scheduleCoverFromCountry(immediate: true);
    }
  }

  @override
  void dispose() {
    _coverDebounce?.cancel();
    _titre.dispose();
    _destination.dispose();
    _budget.dispose();
    _people.dispose();
    super.dispose();
  }

  void _onCountrySelected(String value) {
    final String next = value.trim();
    final String previous = _pays.trim();
    // Same country already selected — keep current cover, skip re-search.
    if (next.isNotEmpty &&
        next.toLowerCase() == previous.toLowerCase() &&
        (_coverPreview != null ||
            _coverLoading ||
            _coverLoadedCountry == next.toLowerCase())) {
      return;
    }
    _pays = value;
    _scheduleCoverFromCountry(immediate: true);
  }

  void _scheduleCoverFromCountry({
    bool immediate = false,
    bool forceRefresh = false,
  }) {
    _coverDebounce?.cancel();
    final String country = _pays.trim();
    // Always drop the previous photo before fetching the new country cover.
    setState(() {
      _coverPreview = null;
      _coverAttempted = false;
      _coverLoading = country.isNotEmpty;
      if (country.isEmpty) {
        _coverLoadedCountry = '';
      }
    });
    if (country.isEmpty) {
      return;
    }
    if (immediate) {
      _loadCoverPreview(forceRefresh: forceRefresh);
      return;
    }
    _coverDebounce = Timer(const Duration(milliseconds: 80), () {
      _loadCoverPreview(forceRefresh: forceRefresh);
    });
  }

  Future<void> _loadCoverPreview({bool forceRefresh = false}) async {
    final int requestId = ++_coverRequestId;
    final String country = _pays.trim();
    if (country.isEmpty) {
      if (mounted) {
        setState(() {
          _coverPreview = null;
          _coverLoading = false;
          _coverAttempted = false;
          _coverLoadedCountry = '';
        });
      }
      return;
    }
    // Skip network when this country cover is already shown.
    if (!forceRefresh &&
        _coverLoadedCountry == country.toLowerCase() &&
        _coverPreview != null &&
        _coverPreview!.imageUrl.trim().isNotEmpty) {
      if (mounted) {
        setState(() => _coverLoading = false);
      }
      return;
    }
    setState(() {
      _coverPreview = null;
      _coverLoading = true;
      _coverAttempted = false;
    });
    try {
      final TripRepository repository =
          widget.repository ?? await TripRepository.attached();
      // Cover is driven only by the selected Country field.
      final DestinationCoverResult cover = await repository.previewCover(
        destination: '',
        country: country,
        forceRefresh: forceRefresh,
      );
      if (!mounted || requestId != _coverRequestId) {
        return;
      }
      if (_pays.trim().toLowerCase() != country.toLowerCase()) {
        return;
      }
      setState(() {
        _coverPreview = cover.imageUrl.trim().isEmpty ? null : cover;
        _coverLoading = false;
        _coverAttempted = true;
        _coverLoadedCountry = country.toLowerCase();
      });
    } catch (_) {
      if (!mounted || requestId != _coverRequestId) {
        return;
      }
      setState(() {
        _coverPreview = null;
        _coverLoading = false;
        _coverAttempted = true;
      });
    }
  }

  Future<void> _pickDate({required bool departure}) async {
    final DateTime now = DateTime.now();
    final DateTime initial = (departure ? _depart : _retour) ?? now;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 6),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      final DateTime day = DateTime(picked.year, picked.month, picked.day);
      if (departure) {
        _depart = day;
      } else {
        _retour = day;
      }
    });
  }

  Future<void> _save() async {
    final double? budget = double.tryParse(_budget.text.trim().replaceAll(',', '.'));
    final int? people = int.tryParse(_people.text.trim());
    final TripDraft draft = TripDraft(
      titre: _titre.text,
      destination: _destination.text,
      pays: _pays,
      dateDepart: _depart == null ? '' : storeCalendarDate(_depart!),
      dateRetour: _retour == null ? '' : storeCalendarDate(_retour!),
      budget: budget ?? -1,
      nombreVoyageurs: people ?? 0,
      typeVoyage: _type,
      statut: widget.showStatus ? _statut : (widget.initial?.statut ?? 'Planned'),
    );
    final String? error = TripValidation.validateTrip(draft);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final TripRepository repository =
          widget.repository ?? await TripRepository.attached();
      final Trip? initial = widget.initial;
      if (initial == null) {
        await repository.createTrip(userId: widget.userId, draft: draft);
      } else {
        await repository.updateTrip(
          id: initial.id,
          userId: widget.userId,
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
    final List<String> types = <String>[
      ...kTripTypes,
      if (!kTripTypes.contains(_type)) _type,
    ];
    return TripScaffold(
      title: widget.title,
      bottom: TripPrimaryButton(
        label: _saving ? 'Enregistrement…' : 'Enregistrer',
        onPressed: _saving ? null : _save,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        children: <Widget>[
          if (_coverLoading ||
              _coverPreview != null ||
              (_coverAttempted && _pays.trim().isNotEmpty)) ...<Widget>[
            if (_coverLoading && _coverPreview == null)
              Container(
                height: 160,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EEF2),
                  borderRadius: kCardRadius,
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: kInk,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Recherche d\'une photo emblématique…',
                      style: TextStyle(
                        color: kInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else if (_coverPreview != null)
              DestinationPhoto(
                destination: _pays.trim().isEmpty ? 'Pays' : _pays.trim(),
                country: _pays,
                imageUrl: _coverPreview?.imageUrl,
                credit: _coverPreview?.credit,
                matchLevel: _coverPreview?.matchLevel,
                height: 160,
                overlayLabel: _pays.trim().isEmpty ? null : _pays.trim(),
                autoload: false,
              )
            else
              Container(
                height: 160,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EEF2),
                  borderRadius: kCardRadius,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      'Aucune photographie fiable pour ${_pays.trim()}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: kInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _scheduleCoverFromCountry(
                        immediate: true,
                        forceRefresh: true,
                      ),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            if (_coverPreview != null && !_coverLoading)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  _coverPreview!.badgeLabel,
                  style: const TextStyle(
                    color: kMute,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
          TripFieldShell(
            label: 'Titre du voyage',
            child: TextField(
              controller: _titre,
              textCapitalization: TextCapitalization.sentences,
              style: _valueStyle,
              autofillHints: const <String>[],
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: null,
              ),
            ),
          ),
          TripFieldShell(
            label: 'Destination',
            child: TextField(
              controller: _destination,
              textCapitalization: TextCapitalization.words,
              style: _valueStyle,
              autofillHints: const <String>[],
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: null,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: kLine),
              ),
              child: CountryField(
                value: _pays,
                onChanged: _onCountrySelected,
              ),
            ),
          ),
          TripFieldShell(
            label: 'Date de départ',
            child: _DateRow(
              value: _depart,
              onTap: () => _pickDate(departure: true),
            ),
          ),
          TripFieldShell(
            label: 'Date de retour',
            child: _DateRow(
              value: _retour,
              onTap: () => _pickDate(departure: false),
            ),
          ),
          TripFieldShell(
            label: 'Budget',
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
            label: 'Nombre de voyageurs',
            child: TextField(
              controller: _people,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: _valueStyle,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: '1',
              ),
            ),
          ),
          TripFieldShell(
            label: 'Type de voyage',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final String type in types)
                  ChoiceChip(
                    label: Text(type),
                    selected: _type == type,
                    onSelected: (_) => setState(() => _type = type),
                    selectedColor: kMint,
                    labelStyle: const TextStyle(
                      color: kInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          if (widget.showStatus)
            TripFieldShell(
              label: 'Statut',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final String status in kTripStatuses)
                    ChoiceChip(
                      label: Text(tripStatusLabel(status)),
                      selected: _statut == status,
                      onSelected: (_) => setState(() => _statut = status),
                      selectedColor: kGold,
                      labelStyle: const TextStyle(
                        color: kInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFB3261E),
                  fontWeight: FontWeight.w600,
                ),
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

class _DateRow extends StatelessWidget {
  const _DateRow({required this.value, required this.onTap});

  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String label = value == null
        ? 'Choisir une date'
        : displayCalendarDate(storeCalendarDate(value!));
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: value == null ? kMute : kInk,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(Icons.calendar_today_outlined, size: 18, color: kInk),
          ],
        ),
      ),
    );
  }
}
