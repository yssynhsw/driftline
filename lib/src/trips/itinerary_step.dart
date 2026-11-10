class ItineraryStep {
  const ItineraryStep({
    required this.id,
    required this.dayId,
    required this.sortOrder,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.estimatedCost,
    required this.location,
  });

  final int id;
  final int dayId;
  final int sortOrder;
  final String title;
  final String description;
  final String startTime;
  final String endTime;
  final double estimatedCost;
  final String location;

  ItineraryStep copyWith({
    int? id,
    int? dayId,
    int? sortOrder,
    String? title,
    String? description,
    String? startTime,
    String? endTime,
    double? estimatedCost,
    String? location,
  }) {
    return ItineraryStep(
      id: id ?? this.id,
      dayId: dayId ?? this.dayId,
      sortOrder: sortOrder ?? this.sortOrder,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      location: location ?? this.location,
    );
  }

  Map<String, Object?> toMap({bool includeId = true}) {
    return <String, Object?>{
      if (includeId) 'id': id,
      'day_id': dayId,
      'sort_order': sortOrder,
      'title': title,
      'description': description,
      'start_time': startTime,
      'end_time': endTime,
      'estimated_cost': estimatedCost,
      'location': location,
    };
  }

  factory ItineraryStep.fromMap(Map<String, Object?> row) {
    return ItineraryStep(
      id: row['id'] as int,
      dayId: row['day_id'] as int,
      sortOrder: row['sort_order'] as int,
      title: row['title'] as String,
      description: (row['description'] as String?) ?? '',
      startTime: (row['start_time'] as String?) ?? '',
      endTime: (row['end_time'] as String?) ?? '',
      estimatedCost: ((row['estimated_cost'] as num?) ?? 0).toDouble(),
      location: (row['location'] as String?) ?? '',
    );
  }

  /// Duration in minutes when both start and end times are valid HH:MM.
  int? get durationMinutes {
    final int? start = _parseMinutes(startTime);
    final int? end = _parseMinutes(endTime);
    if (start == null || end == null || end < start) {
      return null;
    }
    return end - start;
  }

  String get durationLabel {
    final int? minutes = durationMinutes;
    if (minutes == null) {
      return '—';
    }
    final int hours = minutes ~/ 60;
    final int rest = minutes % 60;
    if (hours == 0) {
      return '$rest min';
    }
    if (rest == 0) {
      return '$hours h';
    }
    return '$hours h ${rest.toString().padLeft(2, '0')}';
  }

  String get timeRangeLabel {
    final String start = startTime.trim();
    final String end = endTime.trim();
    if (start.isEmpty && end.isEmpty) {
      return 'Horaires libres';
    }
    if (start.isEmpty) {
      return 'Jusqu’à $end';
    }
    if (end.isEmpty) {
      return 'À partir de $start';
    }
    return '$start – $end';
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

class StepDraft {
  const StepDraft({
    required this.title,
    this.description = '',
    this.startTime = '',
    this.endTime = '',
    this.estimatedCost = 0,
    this.location = '',
    this.sortOrder = 0,
  });

  final String title;
  final String description;
  final String startTime;
  final String endTime;
  final double estimatedCost;
  final String location;
  final int sortOrder;
}
