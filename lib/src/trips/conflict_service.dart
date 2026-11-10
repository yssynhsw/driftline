import '../trip.dart';
import 'itinerary_day.dart';
import 'itinerary_step.dart';

enum ScheduleConflictKind {
  endBeforeStart,
  overlappingSteps,
  stepsTooClose,
  dayOverloaded,
  outsideTripDates,
}

class ScheduleConflict {
  const ScheduleConflict({
    required this.kind,
    required this.message,
    this.dayId,
    this.stepId,
  });

  final ScheduleConflictKind kind;
  final String message;
  final int? dayId;
  final int? stepId;
}

class ConflictService {
  const ConflictService._();

  static const int maxStepsPerDay = 8;
  static const int minGapMinutes = 15;

  static List<ScheduleConflict> analyze({
    required Trip trip,
    required List<ItineraryDay> days,
    List<ItineraryStep> steps = const <ItineraryStep>[],
  }) {
    final List<ScheduleConflict> conflicts = <ScheduleConflict>[];
    final DateTime? depart = calendarDate(trip.dateDepart);
    final DateTime? retour = calendarDate(trip.dateRetour);

    for (final ItineraryDay day in days) {
      final DateTime? date = calendarDate(day.date);
      if (depart != null &&
          retour != null &&
          date != null &&
          (date.isBefore(depart) || date.isAfter(retour))) {
        conflicts.add(
          ScheduleConflict(
            kind: ScheduleConflictKind.outsideTripDates,
            message:
                'Jour ${day.dayNumber} (« ${day.title} ») hors des dates du voyage.',
            dayId: day.id,
          ),
        );
      }

      final int? dayMinutes = _parseMinutes(day.startTime);
      final int? dayEnd = _parseMinutes(day.endTime);
      if (dayMinutes != null && dayEnd != null && dayEnd < dayMinutes) {
        conflicts.add(
          ScheduleConflict(
            kind: ScheduleConflictKind.endBeforeStart,
            message:
                'Jour ${day.dayNumber} : l’heure de fin précède l’heure de début.',
            dayId: day.id,
          ),
        );
      }

      final List<ItineraryStep> daySteps = steps
          .where((ItineraryStep step) => step.dayId == day.id)
          .toList()
        ..sort((ItineraryStep a, ItineraryStep b) {
          final int sa = _parseMinutes(a.startTime) ?? a.sortOrder;
          final int sb = _parseMinutes(b.startTime) ?? b.sortOrder;
          return sa.compareTo(sb);
        });

      if (daySteps.length > maxStepsPerDay) {
        conflicts.add(
          ScheduleConflict(
            kind: ScheduleConflictKind.dayOverloaded,
            message:
                'Jour ${day.dayNumber} trop chargé (${daySteps.length} étapes).',
            dayId: day.id,
          ),
        );
      }

      for (int i = 0; i < daySteps.length; i++) {
        final ItineraryStep step = daySteps[i];
        final int? start = _parseMinutes(step.startTime);
        final int? end = _parseMinutes(step.endTime);
        if (start != null && end != null && end < start) {
          conflicts.add(
            ScheduleConflict(
              kind: ScheduleConflictKind.endBeforeStart,
              message:
                  'Étape « ${step.title} » : fin avant le début (jour ${day.dayNumber}).',
              dayId: day.id,
              stepId: step.id,
            ),
          );
        }
        if (i == 0 || start == null) {
          continue;
        }
        final ItineraryStep previous = daySteps[i - 1];
        final int? previousEnd = _parseMinutes(previous.endTime) ??
            _parseMinutes(previous.startTime);
        if (previousEnd == null) {
          continue;
        }
        if (start < previousEnd) {
          conflicts.add(
            ScheduleConflict(
              kind: ScheduleConflictKind.overlappingSteps,
              message:
                  'Chevauchement entre « ${previous.title} » et « ${step.title} » (jour ${day.dayNumber}).',
              dayId: day.id,
              stepId: step.id,
            ),
          );
        } else if (start - previousEnd < minGapMinutes) {
          conflicts.add(
            ScheduleConflict(
              kind: ScheduleConflictKind.stepsTooClose,
              message:
                  'Étapes trop rapprochées : « ${previous.title} » → « ${step.title} ».',
              dayId: day.id,
              stepId: step.id,
            ),
          );
        }
      }
    }

    return conflicts;
  }

  static int? _parseMinutes(String raw) {
    final String value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    final RegExpMatch? match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value);
    if (match == null) {
      return null;
    }
    final int hour = int.parse(match.group(1)!);
    final int minute = int.parse(match.group(2)!);
    if (hour > 23 || minute > 59) {
      return null;
    }
    return hour * 60 + minute;
  }
}
