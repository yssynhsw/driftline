import 'package:driftline/src/trips/itinerary_step.dart';
import 'package:driftline/src/trips/trip_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('validateStep accepts coherent activity', () {
    expect(
      TripValidation.validateStep(
        const StepDraft(
          title: 'Musée',
          startTime: '10:00',
          endTime: '12:00',
          estimatedCost: 15,
        ),
      ),
      isNull,
    );
  });

  test('validateStep rejects inverted hours and empty title', () {
    expect(
      TripValidation.validateStep(
        const StepDraft(title: '', estimatedCost: 0),
      ),
      isNotNull,
    );
    expect(
      TripValidation.validateStep(
        const StepDraft(
          title: 'A',
          startTime: '14:00',
          endTime: '13:00',
        ),
      ),
      contains('fin'),
    );
  });

  test('ItineraryStep duration helpers', () {
    const ItineraryStep step = ItineraryStep(
      id: 1,
      dayId: 1,
      sortOrder: 1,
      title: 'A',
      description: '',
      startTime: '09:00',
      endTime: '10:30',
      estimatedCost: 0,
      location: '',
    );
    expect(step.durationMinutes, 90);
    expect(step.durationLabel, contains('h'));
    expect(step.timeRangeLabel, '09:00 – 10:30');
  });
}
