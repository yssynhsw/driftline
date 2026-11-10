import 'package:driftline/src/trips/wikimedia_images.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('converts full Commons file URL to standard 1280px thumb', () {
    const String full =
        'https://upload.wikimedia.org/wikipedia/commons/0/05/Sidi_Chebaan.jpg';
    expect(
      WikimediaImages.normalizeForDisplay(full),
      'https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/Sidi_Chebaan.jpg/1280px-Sidi_Chebaan.jpg',
    );
  });

  test('converts English Wikipedia file URLs for any country asset', () {
    const String full =
        'https://upload.wikimedia.org/wikipedia/en/0/0c/Monument_de_la_Renaissance_africaine_(cropped).JPG';
    expect(
      WikimediaImages.normalizeForDisplay(full),
      'https://upload.wikimedia.org/wikipedia/en/thumb/0/0c/Monument_de_la_Renaissance_africaine_(cropped).JPG/1280px-Monument_de_la_Renaissance_africaine_(cropped).JPG',
    );
  });

  test('forces cover thumbs to the standard 1280px display size', () {
    const String odd =
        'https://upload.wikimedia.org/wikipedia/commons/thumb/8/85/Tour.jpg/1600px-Tour.jpg';
    expect(
      WikimediaImages.normalizeForDisplay(odd),
      'https://upload.wikimedia.org/wikipedia/commons/thumb/8/85/Tour.jpg/1280px-Tour.jpg',
    );
  });

  test('keeps already-valid 1280px thumbs', () {
    const String ok =
        'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d4/AlgerCasbah.jpg/1280px-AlgerCasbah.jpg';
    expect(WikimediaImages.normalizeForDisplay(ok), ok);
  });

  test('displayCandidates provide fallbacks for every country URL', () {
    const String france =
        'https://upload.wikimedia.org/wikipedia/commons/8/85/Tour_Eiffel_Wikimedia_Commons_(cropped).jpg';
    final List<String> candidates = WikimediaImages.displayCandidates(france);
    expect(candidates.first, contains('1280px-'));
    expect(candidates.length, greaterThan(1));
    expect(candidates.toSet().length, candidates.length);
  });
}
