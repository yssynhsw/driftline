import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../trip.dart';
import '../budget_engine.dart';
import '../conflict_service.dart';
import '../itinerary_day.dart';
import '../trip_repository.dart';
import '../widgets/destination_gallery.dart';
import '../widgets/destination_photo.dart';
import '../widgets/nearby_places_panel.dart';
import '../widgets/trip_chrome.dart';
import '../widgets/weather_panel.dart';
import 'ai_itinerary_screen.dart';
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
  BudgetBreakdown? _budget;
  List<ItineraryDay> _days = const <ItineraryDay>[];
  List<ScheduleConflict> _conflicts = const <ScheduleConflict>[];
  bool _loading = true;
  bool _galleryLoading = false;
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
      BudgetBreakdown? budget;
      List<ItineraryDay> days = const <ItineraryDay>[];
      List<ScheduleConflict> conflicts = const <ScheduleConflict>[];
      if (trip != null) {
        days = await repository.getDaysByTripId(
          tripId: trip.id,
          userId: widget.userId,
        );
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
      if (trip != null &&
          !const bool.fromEnvironment('FLUTTER_TEST') &&
          (trip.galleryPhotos.length < 5 ||
              trip.galleryPhotos.any(
                (photo) =>
                    photo.representativeOnly ||
                    photo.credit.toLowerCase().contains('unsplash'),
              ))) {
        await _ensureGallery(repository, trip);
      }
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

  Future<void> _ensureGallery(TripRepository repository, Trip trip) async {
    if (!mounted) {
      return;
    }
    setState(() => _galleryLoading = true);
    try {
      final Trip updated = await repository.ensureGalleryPhotos(
        id: trip.id,
        userId: widget.userId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _trip = updated;
        _galleryLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _galleryLoading = false);
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
      _changed = true;
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
    if (saved == true && mounted) {
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
        title: 'Détails du voyage',
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
        child: Text(
          _error ?? 'Voyage introuvable.',
          style: const TextStyle(color: Color(0xFFB3261E), fontWeight: FontWeight.w600),
        ),
      );
    }
    final int days = trip.durationDays;
    final BudgetBreakdown? budget = _budget;
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
      children: <Widget>[
        DestinationPhoto(
          destination: trip.destination,
          country: trip.pays,
          imageUrl: trip.coverPhotoUrl,
          credit: trip.coverPhotoCredit,
          matchLevel: trip.coverMatchLevel,
          height: 220,
          overlayLabel: trip.destination,
          heroTag: 'trip-photo-${trip.id}',
          autoload: trip.coverPhotoUrl.trim().isEmpty,
          onResolved: (cover) async {
            if (trip.coverPhotoUrl.trim().isNotEmpty) {
              return;
            }
            try {
              final TripRepository repository =
                  widget.repository ?? await TripRepository.attached();
              final Trip updated = await repository.ensureCoverPhoto(
                id: trip.id,
                userId: widget.userId,
              );
              if (!mounted) {
                return;
              }
              setState(() => _trip = updated);
            } catch (_) {
              // Preview can still show the resolved URL even if persist fails.
            }
          },
        ),
        const SizedBox(height: 12),
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
        if (budget != null) ...<Widget>[
          const SizedBox(height: 12),
          TripPanel(
            color: budget.overBudget ? const Color(0xFFFFE8E6) : kMint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Budget',
                  style: TextStyle(
                    color: kInk,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                _Detail(
                  label: 'Planifié',
                  value: formatBudget(budget.plannedTotal),
                ),
                _Detail(
                  label: 'Restant',
                  value: formatBudget(budget.remaining),
                ),
                _Detail(
                  label: 'Consommé',
                  value: '${(budget.consumedRatio * 100).toStringAsFixed(0)} %',
                ),
                _Detail(
                  label: 'Par voyageur',
                  value: formatBudget(
                    trip.nombreVoyageurs <= 0
                        ? trip.budget
                        : trip.budget / trip.nombreVoyageurs,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: budget.consumedRatio.clamp(0, 1),
                    minHeight: 10,
                    backgroundColor: Colors.white70,
                    color: budget.overBudget
                        ? const Color(0xFFB3261E)
                        : kGreen,
                  ),
                ),
                if (budget.byDay.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  const Text(
                    'Répartition par journée',
                    style: TextStyle(
                      color: kInk,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final ItineraryDay day in _days)
                    if (budget.byDay.containsKey(day.id))
                      _Detail(
                        label: 'J${day.dayNumber} · ${day.title}',
                        value: formatBudget(budget.byDay[day.id]!),
                      ),
                ],
                const SizedBox(height: 10),
                for (final String tip in BudgetEngine.reductionTips(budget))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $tip'),
                  ),
              ],
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
                  'Conflits horaires',
                  style: TextStyle(
                    color: kInk,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                for (final ScheduleConflict conflict in _conflicts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• ${conflict.message}'),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        DestinationGallerySection(
          destination: trip.destination,
          country: trip.pays,
          photos: trip.galleryPhotos,
          loading: _galleryLoading && trip.galleryPhotos.length < 5,
        ),
        const SizedBox(height: 12),
        WeatherPanel(
          trip: trip,
          // Avoid hanging widget tests on real network calls.
          autoload: !const bool.fromEnvironment('FLUTTER_TEST'),
        ),
        if (!const bool.fromEnvironment('FLUTTER_TEST')) ...<Widget>[
          const SizedBox(height: 12),
          NearbyPlacesPanel(
            userId: widget.userId,
            trip: trip,
            repository: _repository ?? widget.repository,
          ),
        ],
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
        TripPrimaryButton(
          label: 'Générer un itinéraire IA',
          onPressed: _openAi,
        ),
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
