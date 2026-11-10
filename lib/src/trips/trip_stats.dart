import '../trip.dart';
import 'itinerary_day.dart';

class TripDashboardStats {
  const TripDashboardStats({
    required this.totalTrips,
    required this.upcoming,
    required this.completed,
    required this.active,
    required this.cancelled,
    required this.totalPlannedDays,
    required this.totalBudget,
    required this.averageBudget,
    required this.topDestination,
    required this.nextTrip,
    required this.nextTripProgress,
  });

  final int totalTrips;
  final int upcoming;
  final int completed;
  final int active;
  final int cancelled;
  final int totalPlannedDays;
  final double totalBudget;
  final double averageBudget;
  final String? topDestination;
  final Trip? nextTrip;
  final double nextTripProgress;
}

class TripStats {
  const TripStats._();

  static TripDashboardStats compute({
    required List<Trip> trips,
    required Map<int, List<ItineraryDay>> daysByTrip,
    DateTime? now,
  }) {
    final DateTime today = _dateOnly(now ?? DateTime.now());
    int upcoming = 0;
    int completed = 0;
    int active = 0;
    int cancelled = 0;
    int plannedDays = 0;
    double budgetSum = 0;
    final Map<String, int> destinations = <String, int>{};
    Trip? nextTrip;
    DateTime? nextDepart;

    for (final Trip trip in trips) {
      budgetSum += trip.budget;
      final String key = trip.destination.trim().toLowerCase();
      if (key.isNotEmpty) {
        destinations[key] = (destinations[key] ?? 0) + 1;
      }
      plannedDays += daysByTrip[trip.id]?.length ?? trip.durationDays;

      final String status = trip.statut;
      if (status == 'Cancelled') {
        cancelled++;
      } else if (status == 'Done') {
        completed++;
      } else if (status == 'Active') {
        active++;
      } else {
        upcoming++;
      }

      final DateTime? depart = calendarDate(trip.dateDepart);
      if (depart == null || status == 'Cancelled' || status == 'Done') {
        continue;
      }
      if (!depart.isBefore(today) &&
          (nextDepart == null || depart.isBefore(nextDepart))) {
        nextDepart = depart;
        nextTrip = trip;
      }
    }

    String? topDestination;
    int topCount = 0;
    destinations.forEach((String destination, int count) {
      if (count > topCount) {
        topCount = count;
        topDestination = destination;
      }
    });
    if (topDestination != null) {
      topDestination = trips
          .firstWhere(
            (Trip trip) =>
                trip.destination.trim().toLowerCase() == topDestination,
          )
          .destination;
    }

    double progress = 0;
    if (nextTrip != null) {
      final DateTime? start = calendarDate(nextTrip.dateDepart);
      final DateTime? end = calendarDate(nextTrip.dateRetour);
      if (start != null && end != null) {
        if (today.isBefore(start)) {
          progress = 0;
        } else if (today.isAfter(end)) {
          progress = 1;
        } else {
          final int total = end.difference(start).inDays;
          final int done = today.difference(start).inDays;
          progress = total <= 0 ? 1 : (done / total).clamp(0, 1);
        }
      }
    }

    return TripDashboardStats(
      totalTrips: trips.length,
      upcoming: upcoming,
      completed: completed,
      active: active,
      cancelled: cancelled,
      totalPlannedDays: plannedDays,
      totalBudget: budgetSum,
      averageBudget: trips.isEmpty ? 0 : budgetSum / trips.length,
      topDestination: topDestination,
      nextTrip: nextTrip,
      nextTripProgress: progress,
    );
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
