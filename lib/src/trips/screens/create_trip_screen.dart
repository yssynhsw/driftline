import 'package:flutter/material.dart';

import '../trip_repository.dart';
import '../widgets/trip_form.dart';

class CreateTripScreen extends StatelessWidget {
  const CreateTripScreen({super.key, required this.userId, this.repository});

  final int userId;
  final TripRepository? repository;

  @override
  Widget build(BuildContext context) {
    return TripEditorPage(
      title: 'Nouveau voyage',
      userId: userId,
      repository: repository,
    );
  }
}
