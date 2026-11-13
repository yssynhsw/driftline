import 'package:flutter/material.dart';

import '../../trip.dart';
import '../trip_repository.dart';
import '../widgets/trip_form.dart';

class EditTripScreen extends StatelessWidget {
  const EditTripScreen({
    super.key,
    required this.userId,
    required this.trip,
    this.repository,
  });

  final int userId;
  final Trip trip;
  final TripRepository? repository;

  @override
  Widget build(BuildContext context) {
    return TripEditorPage(
      title: 'Modifier le voyage',
      userId: userId,
      initial: trip,
      showStatus: true,
      repository: repository,
    );
  }
}
