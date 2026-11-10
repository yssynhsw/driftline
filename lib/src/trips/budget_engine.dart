import '../trip.dart';
import 'itinerary_day.dart';
import 'itinerary_step.dart';

class BudgetBreakdown {
  const BudgetBreakdown({
    required this.tripBudget,
    required this.plannedDays,
    required this.plannedSteps,
    required this.remaining,
    required this.consumedRatio,
    required this.overBudget,
    required this.perDayAverage,
    required this.byDay,
  });

  final double tripBudget;
  final double plannedDays;
  final double plannedSteps;
  final double remaining;
  final double consumedRatio;
  final bool overBudget;
  final double perDayAverage;
  final Map<int, double> byDay;

  double get plannedTotal => plannedDays + plannedSteps;
}

class BudgetEngine {
  const BudgetEngine._();

  static BudgetBreakdown analyze({
    required Trip trip,
    required List<ItineraryDay> days,
    List<ItineraryStep> steps = const <ItineraryStep>[],
  }) {
    final Map<int, double> stepCostByDay = <int, double>{};
    double stepTotal = 0;
    for (final ItineraryStep step in steps) {
      stepTotal += step.estimatedCost;
      stepCostByDay[step.dayId] =
          (stepCostByDay[step.dayId] ?? 0) + step.estimatedCost;
    }

    // Prefer activity costs for a day when steps exist; otherwise use the
    // day-level estimated budget so empty days still count.
    final Map<int, double> byDay = <int, double>{};
    double dayBudgetFallback = 0;
    for (final ItineraryDay day in days) {
      final double stepCost = stepCostByDay[day.id] ?? 0;
      if (stepCost > 0) {
        byDay[day.id] = stepCost;
      } else {
        byDay[day.id] = day.estimatedBudget;
        dayBudgetFallback += day.estimatedBudget;
      }
    }

    final double planned = dayBudgetFallback + stepTotal;
    final double remaining = trip.budget - planned;
    final double ratio = trip.budget <= 0 ? 0 : (planned / trip.budget).clamp(0, 9);
    final int dayCount = days.isEmpty ? trip.durationDays : days.length;
    final double average = dayCount <= 0 ? 0 : planned / dayCount;

    return BudgetBreakdown(
      tripBudget: trip.budget,
      plannedDays: dayBudgetFallback,
      plannedSteps: stepTotal,
      remaining: remaining,
      consumedRatio: ratio,
      overBudget: planned > trip.budget,
      perDayAverage: average,
      byDay: byDay,
    );
  }

  static List<String> reductionTips(BudgetBreakdown breakdown) {
    if (!breakdown.overBudget) {
      return const <String>[
        'Le budget prévisionnel reste dans l’enveloppe du voyage.',
      ];
    }
    final double overflow = -breakdown.remaining;
    return <String>[
      'Dépassement estimé de ${formatBudget(overflow)}.',
      'Réduis les budgets journaliers les plus élevés.',
      'Remplace une activité payante par une option gratuite ou locale.',
      'Demande à l’IA des alternatives moins coûteuses.',
    ];
  }
}
