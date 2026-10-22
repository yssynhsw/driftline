class ItineraryDay {
  const ItineraryDay({
    required this.id,
    required this.tripId,
    required this.dayNumber,
    required this.date,
    required this.title,
    required this.description,
    required this.estimatedBudget,
    required this.notes,
  });

  final int id;
  final int tripId;
  final int dayNumber;
  final String date;
  final String title;
  final String description;
  final double estimatedBudget;
  final String notes;

  ItineraryDay copyWith({
    int? id,
    int? tripId,
    int? dayNumber,
    String? date,
    String? title,
    String? description,
    double? estimatedBudget,
    String? notes,
  }) {
    return ItineraryDay(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      dayNumber: dayNumber ?? this.dayNumber,
      date: date ?? this.date,
      title: title ?? this.title,
      description: description ?? this.description,
      estimatedBudget: estimatedBudget ?? this.estimatedBudget,
      notes: notes ?? this.notes,
    );
  }

  Map<String, Object?> toMap({bool includeId = true}) {
    return <String, Object?>{
      if (includeId) 'id': id,
      'trip_id': tripId,
      'day_number': dayNumber,
      'date': date,
      'title': title,
      'description': description,
      'estimated_budget': estimatedBudget,
      'notes': notes,
    };
  }

  factory ItineraryDay.fromMap(Map<String, Object?> row) {
    return ItineraryDay(
      id: row['id'] as int,
      tripId: row['trip_id'] as int,
      dayNumber: row['day_number'] as int,
      date: row['date'] as String,
      title: row['title'] as String,
      description: row['description'] as String,
      estimatedBudget: (row['estimated_budget'] as num).toDouble(),
      notes: row['notes'] as String,
    );
  }
}
