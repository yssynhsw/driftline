import 'package:driftline/src/trips/destination_photos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps curated destinations to distinct Unsplash photos', () {
    final String paris = DestinationPhotos.urlFor(destination: 'Paris');
    final String rome = DestinationPhotos.urlFor(destination: 'Rome');
    final String dubai = DestinationPhotos.urlFor(destination: 'Dubaï');
    final String tokyo = DestinationPhotos.urlFor(destination: 'Tokyo');
    final String maldives = DestinationPhotos.urlFor(destination: 'Maldives');
    final String nyc = DestinationPhotos.urlFor(destination: 'New York');

    expect(paris, contains('images.unsplash.com'));
    expect(rome, isNot(equals(paris)));
    expect(dubai, contains('unsplash.com'));
    expect(tokyo, contains('unsplash.com'));
    expect(maldives, contains('unsplash.com'));
    expect(nyc, contains('unsplash.com'));
  });

  test('matches demo morocco cities and falls back safely', () {
    expect(
      DestinationPhotos.urlFor(destination: 'Essaouira', country: 'Morocco'),
      contains('unsplash.com'),
    );
    expect(
      DestinationPhotos.urlFor(destination: 'Marrakech'),
      isNot(equals(DestinationPhotos.fallbackUrl)),
    );
    final String unknown = DestinationPhotos.urlFor(
      destination: 'SomewhereUnknownXYZ',
    );
    expect(unknown, DestinationPhotos.fallbackUrl);
  });

  test('Tunis resolves to Tunisian curated photo, not Egypt', () {
    final String tunis = DestinationPhotos.urlFor(destination: 'Tunis');
    expect(tunis, contains('Sidi_Bou_Said'));
    expect(tunis, isNot(contains('photo-1553913861')));
    expect(
      DestinationPhotos.lookupUrl(destination: 'Tunis'),
      isNotNull,
    );
  });
}
