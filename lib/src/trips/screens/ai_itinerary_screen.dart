import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../trip.dart';
import '../api_config.dart';
import '../itinerary_step.dart';
import '../trip_repository.dart';
import '../trip_services.dart';
import '../trip_validation.dart';
import '../widgets/trip_chrome.dart';

// Gemini credentials come only from --dart-define / backend proxy.
// Never collect an API key from end users in this screen.

class AiItineraryScreen extends StatefulWidget {
  const AiItineraryScreen({
    super.key,
    required this.userId,
    required this.trip,
    this.repository,
    this.generator,
    this.forecast,
  });

  final int userId;
  final Trip trip;
  final TripRepository? repository;
  final ItineraryGenerator? generator;
  final DestinationForecast? forecast;

  @override
  State<AiItineraryScreen> createState() => _AiItineraryScreenState();
}

class _AiItineraryScreenState extends State<AiItineraryScreen> {
  late final TextEditingController _preferences;
  late final TextEditingController _instruction;
  String _pace = 'équilibré';
  bool _reduceBudget = false;
  bool _useWeather = true;
  bool _loading = false;
  String? _error;
  GeneratedItinerary? _preview;
  String? _explanation;

  @override
  void initState() {
    super.initState();
    _preferences = TextEditingController();
    _instruction = TextEditingController();
    if (!TripApiConfig.isGeminiConfigured) {
      _error = 'L’assistant IA n’est pas disponible pour le moment.';
    }
  }

  @override
  void dispose() {
    _preferences.dispose();
    _instruction.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (!TripApiConfig.isGeminiConfigured) {
      setState(() {
        _error = 'L’assistant IA n’est pas disponible pour le moment.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ItineraryGenerator generator =
          widget.generator ?? TripServiceLocator.itineraryGenerator();
      if (generator is! GeminiItineraryGenerator) {
        throw const GeminiException('Assistant IA indisponible.');
      }

      final List<String> weatherHints = <String>[];
      if (_useWeather) {
        try {
          final DestinationForecast forecast =
              widget.forecast ?? TripServiceLocator.destinationForecast();
          final String destinationQuery = widget.trip.pays.trim().isEmpty
              ? widget.trip.destination.trim()
              : '${widget.trip.destination.trim()}, ${widget.trip.pays.trim()}';
          final WeatherForecastResult weather = await forecast.load(
            destination: destinationQuery,
            dateDepart: widget.trip.dateDepart,
            dateRetour: widget.trip.dateRetour,
          );
          for (final WeatherDayForecast day in weather.days.take(5)) {
            weatherHints.add(
              '${day.date}: ${day.conditionLabel}, '
              '${day.tempMin.toStringAsFixed(0)}-${day.tempMax.toStringAsFixed(0)}°C'
              '${day.precipitationProbability == null ? '' : ', pluie ${day.precipitationProbability}%'}',
            );
          }
        } catch (_) {
          // Weather is optional for generation; Gemini still runs.
        }
      }

      final GeneratedItinerary result = await generator.generateDetailed(
        GeminiGenerationRequest(
          destination: widget.trip.destination,
          country: widget.trip.pays,
          dateDepart: widget.trip.dateDepart,
          dateRetour: widget.trip.dateRetour,
          budget: widget.trip.budget,
          travelerCount: widget.trip.nombreVoyageurs,
          tripType: widget.trip.typeVoyage,
          preferences: _preferences.text.trim().isEmpty
              ? 'visite culturelle et gastronomie locale'
              : _preferences.text.trim(),
          pace: _pace,
          instruction: _instruction.text.trim().isEmpty
              ? null
              : _instruction.text.trim(),
          reduceBudget: _reduceBudget,
          weatherHints: weatherHints,
        ),
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _preview = result;
        _explanation = result.explanation.isEmpty
            ? result.summary
            : result.explanation;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = '$error';
        _preview = null;
      });
    }
  }

  Future<void> _save() async {
    final GeneratedItinerary? preview = _preview;
    if (preview == null) {
      return;
    }
    final bool confirmed = await confirmTripAction(
      context,
      title: 'Enregistrer cet itinéraire ?',
      message:
          'Les journées actuelles du voyage seront remplacées par la proposition IA.',
      confirmLabel: 'Enregistrer',
    );
    if (!confirmed || !mounted) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final TripRepository repository =
          widget.repository ?? await TripRepository.attached();
      await repository.replaceItineraryFromAi(
        userId: widget.userId,
        tripId: widget.trip.id,
        days: preview.days,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
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

  @override
  Widget build(BuildContext context) {
    final bool ready = TripApiConfig.isGeminiConfigured;
    return TripScaffold(
      title: 'Itinéraire IA',
      bottom: _preview == null
          ? TripPrimaryButton(
              label: _loading ? 'Génération…' : 'Générer mon itinéraire',
              onPressed: _loading || !ready ? null : _generate,
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TripPrimaryButton(
                  label: _loading ? 'Enregistrement…' : 'Enregistrer',
                  onPressed: _loading ? null : _save,
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _loading ? null : _generate,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: kInk,
                    side: const BorderSide(color: kInk),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text('Régénérer'),
                ),
              ],
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
        children: <Widget>[
          TripPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.trip.titre,
                  style: const TextStyle(
                    color: kInk,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.trip.destination} · ${displayCalendarDate(widget.trip.dateDepart)} – ${displayCalendarDate(widget.trip.dateRetour)}',
                  style: const TextStyle(
                    color: kMute,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Budget du voyage : ${formatBudget(widget.trip.budget)}',
                  style: const TextStyle(
                    color: kInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tes préférences',
            style: TextStyle(
              color: kInk,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          TripFieldShell(
            label: 'Ce que tu aimes',
            child: TextField(
              controller: _preferences,
              maxLines: 3,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Ex. plages, gastronomie, musées, nature…',
              ),
            ),
          ),
          TripFieldShell(
            label: 'Rythme du séjour',
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _pace,
                isExpanded: true,
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(
                    value: 'calme',
                    child: Text('Calme — peu d’activités par jour'),
                  ),
                  DropdownMenuItem(
                    value: 'équilibré',
                    child: Text('Équilibré — rythme confortable'),
                  ),
                  DropdownMenuItem(
                    value: 'intensif',
                    child: Text('Intensif — journées bien remplies'),
                  ),
                ],
                onChanged: (String? value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _pace = value);
                },
              ),
            ),
          ),
          TripFieldShell(
            label: 'Précision (optionnel)',
            child: TextField(
              controller: _instruction,
              maxLines: 2,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Ex. éviter les musées, prioriser la mer…',
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Options',
            style: TextStyle(
              color: kInk,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _OptionCard(
            icon: Icons.savings_outlined,
            title: 'Économiser sur le budget',
            subtitle:
                'Propose des activités moins chères que le budget prévu '
                '(${formatBudget(widget.trip.budget)}).',
            value: _reduceBudget,
            onChanged: (bool value) => setState(() => _reduceBudget = value),
          ),
          const SizedBox(height: 10),
          _OptionCard(
            icon: Icons.wb_cloudy_outlined,
            title: 'Tenir compte de la météo',
            subtitle:
                'Adapte le programme selon la météo prévue sur les dates du voyage.',
            value: _useWeather,
            onChanged: (bool value) => setState(() => _useWeather = value),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Column(
                children: <Widget>[
                  CircularProgressIndicator(color: kInk),
                  SizedBox(height: 12),
                  Text(
                    'Création de ton itinéraire…',
                    style: TextStyle(color: kMute, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Cela peut prendre jusqu’à une minute.',
                    style: TextStyle(color: kMute),
                  ),
                ],
              ),
            ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            TripPanel(
              color: const Color(0xFFFFE8E6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Impossible de générer pour le moment',
                    style: TextStyle(
                      color: Color(0xFFB42318),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFB42318),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Réessaie dans quelques secondes.',
                    style: TextStyle(color: kInk),
                  ),
                ],
              ),
            ),
          ],
          if (_preview != null) ...<Widget>[
            const SizedBox(height: 14),
            TripPanel(
              color: kLilac,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Prévisualisation',
                    style: TextStyle(
                      color: kInk,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (_explanation != null &&
                      _explanation!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(_explanation!, style: const TextStyle(color: kInk)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            for (final DayDraft day in _preview!.days)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TripPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Jour ${day.dayNumber} · ${day.title}',
                        style: const TextStyle(
                          color: kInk,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${displayCalendarDate(day.date)} · budget ${formatBudget(day.estimatedBudget)}',
                        style: const TextStyle(color: kMute),
                      ),
                      const SizedBox(height: 8),
                      Text(day.description),
                      if (day.steps.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        for (final StepDraft step in day.steps)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• ${step.startTime.isEmpty ? '' : '${step.startTime} '}${step.title}'
                              '${step.estimatedCost > 0 ? ' (${formatBudget(step.estimatedCost)})' : ''}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                      if (day.notes.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          day.notes,
                          style: const TextStyle(
                            color: kMute,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return TripPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: kInk),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: kInk,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: kMute, height: 1.35),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
