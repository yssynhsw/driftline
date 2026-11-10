import 'package:driftline/src/trip.dart';
import 'package:driftline/src/trips/budget_engine.dart';
import 'package:driftline/src/trips/conflict_service.dart';
import 'package:driftline/src/trips/itinerary_day.dart';
import 'package:driftline/src/trips/itinerary_step.dart';
import 'package:driftline/src/trips/trip_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Trip trip = Trip(
    id: 1,
    titre: 'Essaouira',
    destination: 'Essaouira',
    pays: 'Morocco',
    dateDepart: '2026-06-01',
    dateRetour: '2026-06-03',
    budget: 1000,
    nombreVoyageurs: 2,
    typeVoyage: 'Détente',
    statut: 'Planned',
    userId: 7,
    dateCreation: DateTime.utc(2026, 5, 1),
  );

  test('budget engine detects overflow and remaining', () {
    final BudgetBreakdown breakdown = BudgetEngine.analyze(
      trip: trip,
      days: const <ItineraryDay>[
        ItineraryDay(
          id: 1,
          tripId: 1,
          dayNumber: 1,
          date: '2026-06-01',
          title: 'A',
          description: '',
          estimatedBudget: 700,
          notes: '',
        ),
        ItineraryDay(
          id: 2,
          tripId: 1,
          dayNumber: 2,
          date: '2026-06-02',
          title: 'B',
          description: '',
          estimatedBudget: 400,
          notes: '',
        ),
      ],
      steps: const <ItineraryStep>[
        ItineraryStep(
          id: 1,
          dayId: 1,
          sortOrder: 1,
          title: 'Lunch',
          description: '',
          startTime: '12:00',
          endTime: '13:00',
          estimatedCost: 50,
          location: '',
        ),
      ],
    );

    // Day 1 uses step costs (50) instead of day budget (700); day 2 keeps 400.
    expect(breakdown.plannedSteps, 50);
    expect(breakdown.plannedDays, 400);
    expect(breakdown.plannedTotal, 450);
    expect(breakdown.overBudget, isFalse);
    expect(breakdown.remaining, 550);
    expect(BudgetEngine.reductionTips(breakdown), isNotEmpty);
  });

  test('conflict service detects same-start simultaneous activities', () {
    final List<ScheduleConflict> conflicts = ConflictService.analyze(
      trip: trip,
      days: const <ItineraryDay>[
        ItineraryDay(
          id: 1,
          tripId: 1,
          dayNumber: 1,
          date: '2026-06-01',
          title: 'A',
          description: '',
          estimatedBudget: 100,
          notes: '',
        ),
      ],
      steps: const <ItineraryStep>[
        ItineraryStep(
          id: 1,
          dayId: 1,
          sortOrder: 1,
          title: 'A1',
          description: '',
          startTime: '10:00',
          endTime: '11:00',
          estimatedCost: 0,
          location: '',
        ),
        ItineraryStep(
          id: 2,
          dayId: 1,
          sortOrder: 2,
          title: 'A2',
          description: '',
          startTime: '10:00',
          endTime: '10:30',
          estimatedCost: 0,
          location: '',
        ),
      ],
    );
    expect(
      conflicts.any(
        (ScheduleConflict c) => c.kind == ScheduleConflictKind.overlappingSteps,
      ),
      isTrue,
    );
  });

  test('conflict service flags day outside trip dates', () {
    final List<ScheduleConflict> conflicts = ConflictService.analyze(
      trip: trip,
      days: const <ItineraryDay>[
        ItineraryDay(
          id: 1,
          tripId: 1,
          dayNumber: 1,
          date: '2026-05-20',
          title: 'Hors dates',
          description: '',
          estimatedBudget: 0,
          notes: '',
        ),
      ],
      steps: const <ItineraryStep>[],
    );
    expect(
      conflicts.any(
        (ScheduleConflict c) => c.kind == ScheduleConflictKind.outsideTripDates,
      ),
      isTrue,
    );
  });

  test('budget over when step costs exceed trip budget; travelers counted', () {
    final Trip tight = trip.copyWith(budget: 100, nombreVoyageurs: 2);
    final BudgetBreakdown breakdown = BudgetEngine.analyze(
      trip: tight,
      days: const <ItineraryDay>[
        ItineraryDay(
          id: 1,
          tripId: 1,
          dayNumber: 1,
          date: '2026-06-01',
          title: 'A',
          description: '',
          estimatedBudget: 0,
          notes: '',
        ),
      ],
      steps: const <ItineraryStep>[
        ItineraryStep(
          id: 1,
          dayId: 1,
          sortOrder: 1,
          title: 'Cher',
          description: '',
          startTime: '09:00',
          endTime: '10:00',
          estimatedCost: 180,
          location: '',
        ),
      ],
    );
    expect(breakdown.overBudget, isTrue);
    expect(breakdown.plannedTotal, 180);
    expect(breakdown.remaining, lessThan(0));
    expect(tight.nombreVoyageurs, 2);
    expect(tight.budget / tight.nombreVoyageurs, 50);
  });

  test('conflict service detects overlap and invalid hours', () {
    final List<ScheduleConflict> conflicts = ConflictService.analyze(
      trip: trip,
      days: const <ItineraryDay>[
        ItineraryDay(
          id: 1,
          tripId: 1,
          dayNumber: 1,
          date: '2026-06-01',
          title: 'A',
          description: '',
          estimatedBudget: 100,
          notes: '',
          startTime: '18:00',
          endTime: '10:00',
        ),
      ],
      steps: const <ItineraryStep>[
        ItineraryStep(
          id: 1,
          dayId: 1,
          sortOrder: 1,
          title: 'Musée',
          description: '',
          startTime: '09:00',
          endTime: '11:00',
          estimatedCost: 20,
          location: '',
        ),
        ItineraryStep(
          id: 2,
          dayId: 1,
          sortOrder: 2,
          title: 'Souk',
          description: '',
          startTime: '10:30',
          endTime: '12:00',
          estimatedCost: 10,
          location: '',
        ),
      ],
    );

    expect(
      conflicts.any(
        (ScheduleConflict c) => c.kind == ScheduleConflictKind.endBeforeStart,
      ),
      isTrue,
    );
    expect(
      conflicts.any(
        (ScheduleConflict c) => c.kind == ScheduleConflictKind.overlappingSteps,
      ),
      isTrue,
    );
  });

  test('dashboard stats come from SQLite-like trip lists', () {
    final TripDashboardStats stats = TripStats.compute(
      trips: <Trip>[
        trip,
        trip.copyWith(
          id: 2,
          titre: 'Marrakech',
          destination: 'Marrakech',
          statut: 'Done',
          dateDepart: '2026-01-01',
          dateRetour: '2026-01-03',
          budget: 500,
        ),
      ],
      daysByTrip: <int, List<ItineraryDay>>{
        1: const <ItineraryDay>[
          ItineraryDay(
            id: 1,
            tripId: 1,
            dayNumber: 1,
            date: '2026-06-01',
            title: 'A',
            description: '',
            estimatedBudget: 10,
            notes: '',
          ),
        ],
        2: const <ItineraryDay>[],
      },
      now: DateTime(2026, 5, 1),
    );

    expect(stats.totalTrips, 2);
    expect(stats.completed, 1);
    expect(stats.upcoming, 1);
    expect(stats.totalBudget, 1500);
    expect(stats.nextTrip?.id, 1);
  });
}
