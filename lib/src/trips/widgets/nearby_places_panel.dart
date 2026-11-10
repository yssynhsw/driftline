import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../trip.dart';
import '../api_config.dart';
import '../itinerary_day.dart';
import '../open_route_service.dart';
import '../open_trip_map_service.dart';
import '../trip_repository.dart';
import 'step_form.dart';
import 'trip_chrome.dart';

class NearbyPlacesPanel extends StatefulWidget {
  const NearbyPlacesPanel({
    super.key,
    required this.userId,
    required this.trip,
    this.repository,
  });

  final int userId;
  final Trip trip;
  final TripRepository? repository;

  @override
  State<NearbyPlacesPanel> createState() => _NearbyPlacesPanelState();
}

class _NearbyPlacesPanelState extends State<NearbyPlacesPanel> {
  final OpenTripMapService _otm = OpenTripMapService();
  final OpenRouteService _ors = OpenRouteService();
  bool _loading = false;
  String? _error;
  List<TouristPlace> _places = const <TouristPlace>[];
  RouteLegInfo? _leg;
  String? _legError;

  @override
  void initState() {
    super.initState();
    if (TripApiConfig.isOpenTripMapConfigured) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!TripApiConfig.isOpenTripMapConfigured) {
      setState(() {
        _error =
            'OpenTripMap non configuré. Ajoute OPENTRIPMAP_API_KEY puis relance l’app.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _leg = null;
      _legError = null;
    });
    try {
      final List<TouristPlace> places = await _otm.searchNearDestination(
        destination: widget.trip.destination,
        country: widget.trip.pays,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _places = places;
        _loading = false;
      });
      if (places.length >= 2 && TripApiConfig.isOpenRouteServiceConfigured) {
        await _loadRoute(places[0], places[1]);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = '$error';
        _places = const <TouristPlace>[];
      });
    }
  }

  Future<void> _loadRoute(TouristPlace from, TouristPlace to) async {
    try {
      final RouteLegInfo leg = await _ors.routeBetween(
        fromLon: from.longitude,
        fromLat: from.latitude,
        toLon: to.longitude,
        toLat: to.latitude,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _leg = leg;
        _legError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _leg = null;
        _legError = '$error';
      });
    }
  }

  Future<void> _addToDay(TouristPlace place) async {
    final TripRepository repository =
        widget.repository ?? await TripRepository.attached();
    final List<ItineraryDay> days = await repository.getDaysByTripId(
      tripId: widget.trip.id,
      userId: widget.userId,
    );
    if (!mounted) {
      return;
    }
    if (days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Crée d’abord une journée dans l’itinéraire.'),
        ),
      );
      return;
    }

    ItineraryDay selected = days.first;
    if (days.length > 1) {
      final ItineraryDay? picked = await showModalBottomSheet<ItineraryDay>(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    'Ajouter à quelle journée ?',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                for (final ItineraryDay day in days)
                  ListTile(
                    title: Text('Jour ${day.dayNumber} · ${day.title}'),
                    onTap: () => Navigator.pop(context, day),
                  ),
              ],
            ),
          );
        },
      );
      if (picked == null || !mounted) {
        return;
      }
      selected = picked;
    }

    TouristPlace detailed = place;
    try {
      detailed = await _otm.loadDetails(place);
    } catch (_) {
      // Keep list data if detail call fails.
    }

    if (!mounted) {
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => StepEditorPage(
          userId: widget.userId,
          dayId: selected.id,
          repository: repository,
          presetTitle: detailed.name,
          presetLocation:
              '${detailed.name} (${detailed.latitude.toStringAsFixed(4)}, ${detailed.longitude.toStringAsFixed(4)})',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TripPanel(
      color: kLilac,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'Lieux à proximité',
                  style: TextStyle(
                    color: kInk,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Actualiser',
              ),
            ],
          ),
          const Text(
            'OpenTripMap · points d’intérêt réels autour de la destination',
            style: TextStyle(color: kMute, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          if (!TripApiConfig.isOpenTripMapConfigured)
            const Text(
              'Non configuré : ajoute OPENTRIPMAP_API_KEY dans .env.local '
              'puis relance avec les dart-defines.',
              style: TextStyle(color: kInk, fontWeight: FontWeight.w600),
            )
          else if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFB42318),
                fontWeight: FontWeight.w600,
              ),
            )
          else if (_places.isEmpty)
            const Text(
              'Aucun lieu trouvé pour cette destination.',
              style: TextStyle(color: kInk, fontWeight: FontWeight.w600),
            )
          else ...<Widget>[
            if (_leg != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Trajet ${_leg!.profile.label} entre les 2 premiers lieux : '
                  '${_leg!.distanceLabel} · ${_leg!.durationLabel}',
                  style: const TextStyle(
                    color: kInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (_legError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  TripApiConfig.isOpenRouteServiceConfigured
                      ? _legError!
                      : 'OpenRouteService non configuré '
                          '(OPENROUTESERVICE_API_KEY).',
                  style: const TextStyle(
                    color: kMute,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            for (final TouristPlace place in _places.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              place.name,
                              style: const TextStyle(
                                color: kInk,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              place.categoryLabel +
                                  (place.distanceMeters == null
                                      ? ''
                                      : ' · ${place.distanceMeters!.round()} m'),
                              style: const TextStyle(
                                color: kMute,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _addToDay(place),
                        child: const Text('Ajouter'),
                      ),
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
