import "package:driftline/src/countries.dart";
import "package:driftline/src/trips/country_landmarks.dart";

void main() {
  final missingCapital = <String>[];
  final weak = <String>[];
  for (final c in kCountries) {
    final landmarks = landmarksForCountry(c);
    if (!kCountryCapitals.containsKey(c)) missingCapital.add(c);
    // curated + capital + country article ideally >= 3
    if (landmarks.length < 3) weak.add("$c (${landmarks.length})");
  }
  print("countries in picker: ${kCountries.length}");
  print("with capital entry: ${kCountryCapitals.length}");
  print("missing capital: ${missingCapital.length} $missingCapital");
  print("curated landmark countries: ${kCountryLandmarks.length}");
  print("weak (<3 landmark candidates): ${weak.length} $weak");
  print("sample Portugal: ${landmarksForCountry("Portugal").map((l) => l.label).toList()}");
  print("sample Tunisia: ${landmarksForCountry("Tunisia").map((l) => l.label).toList()}");
  print("sample Nauru: ${landmarksForCountry("Nauru").map((l) => l.label).toList()}");
}
