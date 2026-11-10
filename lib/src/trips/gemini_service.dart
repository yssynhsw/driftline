import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'itinerary_step.dart';
import 'trip_services.dart';
import 'trip_validation.dart';

class GeminiException implements Exception {
  const GeminiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class GeneratedItinerary {
  const GeneratedItinerary({
    required this.days,
    required this.summary,
    this.explanation = '',
  });

  final List<DayDraft> days;
  final String summary;
  final String explanation;
}

class GeminiGenerationRequest {
  const GeminiGenerationRequest({
    required this.destination,
    required this.country,
    required this.dateDepart,
    required this.dateRetour,
    required this.budget,
    required this.travelerCount,
    required this.tripType,
    required this.preferences,
    required this.pace,
    this.instruction,
    this.existingDay,
    this.reduceBudget = false,
    this.weatherHints = const <String>[],
  });

  final String destination;
  final String country;
  final String dateDepart;
  final String dateRetour;
  final double budget;
  final int travelerCount;
  final String tripType;
  final String preferences;
  final String pace;
  final String? instruction;
  final DayDraft? existingDay;
  final bool reduceBudget;
  final List<String> weatherHints;
}

/// Real Google Gemini HTTP client for structured itinerary JSON.
class GeminiItineraryGenerator implements ItineraryGenerator {
  GeminiItineraryGenerator({
    http.Client? client,
    this.model = 'gemini-3-flash-preview',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String model;

  @override
  bool get isAvailable => true;

  @override
  Future<List<DayDraft>> generate({
    required String destination,
    required String dateDepart,
    required String dateRetour,
    required double budget,
    required String preferences,
  }) async {
    final GeneratedItinerary result = await generateDetailed(
      GeminiGenerationRequest(
        destination: destination,
        country: '',
        dateDepart: dateDepart,
        dateRetour: dateRetour,
        budget: budget,
        travelerCount: 2,
        tripType: 'Culturel',
        preferences: preferences,
        pace: 'équilibré',
      ),
    );
    return result.days;
  }

  static const List<String> _fallbackModels = <String>[
    'gemini-3-flash-preview',
    'gemini-3.1-flash-lite',
    'gemini-flash-lite-latest',
    'gemini-flash-latest',
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-3.5-flash',
  ];

  Future<GeneratedItinerary> generateDetailed(
    GeminiGenerationRequest request,
  ) async {
    if (!TripApiConfig.isGeminiConfigured) {
      throw const GeminiException(
        'L’assistant IA n’est pas activé sur cet appareil. '
        'Relance avec scripts/run_dev.ps1.',
      );
    }

    final String prompt = _buildPrompt(request);
    final Map<String, Object?> geminiBody = <String, Object?>{
      'contents': <Map<String, Object?>>[
        <String, Object?>{
          'role': 'user',
          'parts': <Map<String, String>>[
            <String, String>{'text': prompt},
          ],
        },
      ],
      'generationConfig': <String, Object?>{
        'temperature': 0.7,
        'responseMimeType': 'application/json',
      },
    };

    final LinkedHashSet<String> models = LinkedHashSet<String>.from(
      <String>[model, ..._fallbackModels],
    );
    GeminiException? lastError;

    final String? proxy = TripApiConfig.geminiProxyUrl;
    if (proxy != null) {
      for (final String candidate in models) {
        try {
          return _parseResponse(
            await _postWithRetries(
              uri: Uri.parse(proxy),
              headers: TripApiConfig.proxyHeaders(),
              body: <String, Object?>{
                'prompt': prompt,
                'model': candidate,
                'request': geminiBody,
              },
            ),
          );
        } on GeminiException catch (error) {
          lastError = error;
          if (!_isRetryableGeminiError(error)) {
            rethrow;
          }
        }
      }
      throw lastError ??
          const GeminiException(
            'L’assistant IA est temporairement saturé. Réessaie dans une minute.',
          );
    }

    final String? apiKey = await TripApiConfig.geminiApiKey();
    if (apiKey == null) {
      throw const GeminiException(
        'L’assistant IA n’est pas activé sur cet appareil.',
      );
    }

    for (final String candidate in models) {
      try {
        final http.Response response = await _postWithRetries(
          uri: Uri.https(
            'generativelanguage.googleapis.com',
            '/v1beta/models/$candidate:generateContent',
            <String, String>{'key': apiKey},
          ),
          headers: const <String, String>{
            'Content-Type': 'application/json',
          },
          body: geminiBody,
        );
        return _parseResponse(response);
      } on GeminiException catch (error) {
        lastError = error;
        if (!_isRetryableGeminiError(error)) {
          rethrow;
        }
      }
    }
    throw lastError ??
        const GeminiException(
          'L’assistant IA est temporairement saturé. Réessaie dans une minute.',
        );
  }

  bool _isRetryableGeminiError(GeminiException error) {
    final String message = error.message.toLowerCase();
    return message.contains('saturé') ||
        message.contains('indisponible') ||
        message.contains('connexion') ||
        message.contains('503') ||
        message.contains('429') ||
        message.contains('504');
  }

  Future<http.Response> _postWithRetries({
    required Uri uri,
    required Map<String, String> headers,
    required Object body,
    int attempts = 3,
  }) async {
    GeminiException? lastError;
    for (int i = 0; i < attempts; i++) {
      late final http.Response response;
      try {
        response = await _client
            .post(
              uri,
              headers: headers,
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 60));
      } catch (_) {
        lastError = const GeminiException(
          'Impossible de joindre l’assistant IA. Vérifie ta connexion.',
        );
        await Future<void>.delayed(Duration(milliseconds: 700 * (i + 1)));
        continue;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const GeminiException(
          'Accès à l’assistant IA refusé. Vérifie la configuration.',
        );
      }
      if (response.statusCode == 429 ||
          response.statusCode == 503 ||
          response.statusCode == 504) {
        lastError = const GeminiException(
          'L’assistant IA est temporairement saturé. Réessaie dans une minute.',
        );
        await Future<void>.delayed(Duration(milliseconds: 900 * (i + 1)));
        continue;
      }
      throw GeminiException(
        'Assistant IA indisponible (${response.statusCode}).',
      );
    }
    throw lastError ??
        const GeminiException(
          'L’assistant IA est temporairement saturé. Réessaie dans une minute.',
        );
  }

  GeneratedItinerary _parseResponse(http.Response response) {
    final Object decoded = jsonDecode(response.body);
    final String? text;
    if (decoded is Map<String, dynamic>) {
      if (decoded['itinerary'] is Map<String, dynamic> ||
          decoded['days'] is List<dynamic>) {
        return parseGeneratedItinerary(
          jsonEncode(decoded['itinerary'] ?? decoded),
        );
      }
      text = _extractText(decoded) ??
          (decoded['text'] is String ? decoded['text'] as String : null);
    } else if (decoded is String) {
      text = decoded;
    } else {
      text = null;
    }
    if (text == null || text.trim().isEmpty) {
      throw const GeminiException('Réponse de l’assistant IA vide.');
    }
    return parseGeneratedItinerary(text);
  }

  Future<GeneratedItinerary> regenerateDay({
    required GeminiGenerationRequest base,
    required DayDraft day,
    String? instruction,
  }) {
    return generateDetailed(
      GeminiGenerationRequest(
        destination: base.destination,
        country: base.country,
        dateDepart: base.dateDepart,
        dateRetour: base.dateRetour,
        budget: base.budget,
        travelerCount: base.travelerCount,
        tripType: base.tripType,
        preferences: base.preferences,
        pace: base.pace,
        existingDay: day,
        instruction: instruction ??
            'Régénère uniquement cette journée en gardant la cohérence globale.',
        weatherHints: base.weatherHints,
        reduceBudget: base.reduceBudget,
      ),
    );
  }

  static GeneratedItinerary parseGeneratedItinerary(String raw) {
    final Object? decoded = _decodeJson(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const GeminiException('JSON Gemini invalide.');
    }
    final List<dynamic>? daysJson = decoded['days'] as List<dynamic>?;
    if (daysJson == null || daysJson.isEmpty) {
      throw const GeminiException('Aucune journée dans la réponse Gemini.');
    }

    final List<DayDraft> days = <DayDraft>[];
    for (int i = 0; i < daysJson.length; i++) {
      final Map<String, dynamic> day =
          daysJson[i] as Map<String, dynamic>;
      final List<StepDraft> steps = <StepDraft>[];
      final List<dynamic>? stepsJson = day['steps'] as List<dynamic>?;
      if (stepsJson != null) {
        for (int s = 0; s < stepsJson.length; s++) {
          final Map<String, dynamic> step =
              stepsJson[s] as Map<String, dynamic>;
          steps.add(
            StepDraft(
              sortOrder: s + 1,
              title: '${step['title'] ?? 'Étape ${s + 1}'}'.trim(),
              description: '${step['description'] ?? ''}'.trim(),
              startTime: '${step['start_time'] ?? step['startTime'] ?? ''}'.trim(),
              endTime: '${step['end_time'] ?? step['endTime'] ?? ''}'.trim(),
              estimatedCost: _toDouble(
                step['estimated_cost'] ?? step['estimatedCost'] ?? 0,
              ),
              location: '${step['location'] ?? ''}'.trim(),
            ),
          );
        }
      }

      final String program = steps.isEmpty
          ? '${day['program'] ?? day['description'] ?? ''}'.trim()
          : steps
              .map(
                (StepDraft step) =>
                    '${step.startTime.isEmpty ? '' : '${step.startTime} '}${step.title}',
              )
              .join('\n');

      days.add(
        DayDraft(
          dayNumber: _toInt(day['day_number'] ?? day['dayNumber'] ?? (i + 1)),
          date: '${day['date'] ?? ''}'.trim(),
          title: '${day['title'] ?? 'Jour ${i + 1}'}'.trim(),
          description: '${day['description'] ?? ''}'.trim(),
          estimatedBudget: _toDouble(
            day['daily_budget'] ??
                day['estimated_budget'] ??
                day['estimatedBudget'] ??
                0,
          ),
          notes: '${day['recommendations'] ?? day['notes'] ?? ''}'.trim(),
          startTime: '${day['start_time'] ?? day['startTime'] ?? ''}'.trim(),
          endTime: '${day['end_time'] ?? day['endTime'] ?? ''}'.trim(),
          program: program,
          steps: steps,
        ),
      );
    }

    return GeneratedItinerary(
      days: days,
      summary: '${decoded['summary'] ?? ''}'.trim(),
      explanation: '${decoded['explanation'] ?? decoded['rationale'] ?? ''}'
          .trim(),
    );
  }

  String _buildPrompt(GeminiGenerationRequest request) {
    final StringBuffer buffer = StringBuffer()
      ..writeln(
        'Tu es un planificateur de voyage expert. Réponds UNIQUEMENT en JSON valide.',
      )
      ..writeln('Schéma attendu:')
      ..writeln('''
{
  "summary": "string",
  "explanation": "string",
  "days": [
    {
      "day_number": 1,
      "date": "YYYY-MM-DD",
      "title": "string",
      "description": "string",
      "start_time": "HH:MM",
      "end_time": "HH:MM",
      "daily_budget": 0,
      "recommendations": "string",
      "steps": [
        {
          "title": "string",
          "description": "string",
          "start_time": "HH:MM",
          "end_time": "HH:MM",
          "estimated_cost": 0,
          "location": "string"
        }
      ]
    }
  ]
}
''')
      ..writeln('Destination: ${request.destination}')
      ..writeln('Pays: ${request.country}')
      ..writeln('Départ: ${request.dateDepart}')
      ..writeln('Retour: ${request.dateRetour}')
      ..writeln('Budget total: ${request.budget}')
      ..writeln('Voyageurs: ${request.travelerCount}')
      ..writeln('Type: ${request.tripType}')
      ..writeln('Préférences: ${request.preferences}')
      ..writeln('Rythme: ${request.pace}');

    if (request.reduceBudget) {
      buffer.writeln(
        'Contrainte: propose un programme clairement moins coûteux.',
      );
    }
    if (request.weatherHints.isNotEmpty) {
      buffer
        ..writeln('Contraintes météo:')
        ..writeln(request.weatherHints.join('\n'));
    }
    if (request.existingDay != null) {
      buffer
        ..writeln('Régénère uniquement cette journée:')
        ..writeln(jsonEncode(<String, Object?>{
          'day_number': request.existingDay!.dayNumber,
          'date': request.existingDay!.date,
          'title': request.existingDay!.title,
          'description': request.existingDay!.description,
        }));
    }
    if (request.instruction != null && request.instruction!.trim().isNotEmpty) {
      buffer.writeln('Instruction utilisateur: ${request.instruction}');
    }
    buffer.writeln(
      'Couvre chaque jour entre départ et retour inclus. '
      'Chaque journée doit contenir des steps avec horaires HH:MM, '
      'description et estimated_cost. Budgets réalistes. Langue: français. '
      'N’ajoute aucun texte hors JSON.',
    );
    return buffer.toString();
  }

  static Object? _decodeJson(String raw) {
    String text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```(?:json)?'), '').trim();
      if (text.endsWith('```')) {
        text = text.substring(0, text.length - 3).trim();
      }
    }
    try {
      return jsonDecode(text);
    } on FormatException {
      final int start = text.indexOf('{');
      final int end = text.lastIndexOf('}');
      if (start >= 0 && end > start) {
        return jsonDecode(text.substring(start, end + 1));
      }
      throw const GeminiException(
        'Réponse IA illisible (JSON invalide). Réessaie.',
      );
    }
  }

  static String? _extractText(Map<String, dynamic> envelope) {
    final List<dynamic>? candidates =
        envelope['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      final Object? block = envelope['promptFeedback'] ?? envelope['error'];
      if (block != null) {
        return null;
      }
      return null;
    }
    final Map<String, dynamic> first = candidates.first as Map<String, dynamic>;
    final String finish = '${first['finishReason'] ?? ''}';
    if (finish == 'SAFETY' || finish == 'RECITATION') {
      throw const GeminiException(
        'La génération a été bloquée. Reformule tes préférences.',
      );
    }
    final Map<String, dynamic>? content =
        first['content'] as Map<String, dynamic>?;
    final List<dynamic>? parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      return null;
    }
    final StringBuffer buffer = StringBuffer();
    for (final Object? part in parts) {
      if (part is Map<String, dynamic> && part['text'] is String) {
        buffer.write(part['text']);
      }
    }
    return buffer.toString();
  }

  static double _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value') ?? 0;
  }

  static int _toInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? 0;
  }
}
