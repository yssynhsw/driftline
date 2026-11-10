import 'package:flutter/material.dart';

import '../../trip.dart';
import '../itinerary_day.dart';
import '../trip_repository.dart';
import '../widgets/itinerary_day_form.dart';

class EditItineraryScreen extends StatelessWidget {
  const EditItineraryScreen({
    super.key,
    required this.userId,
    required this.trip,
    required this.day,
    this.repository,
  });

  final int userId;
  final Trip trip;
  final ItineraryDay day;
  final TripRepository? repository;

  @override
  Widget build(BuildContext context) {
    return DayEditorPage(
      title: 'Modifier la journée',
      userId: userId,
      trip: trip,
      initial: day,
      repository: repository,
    );
  }
}
