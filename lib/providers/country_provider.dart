import 'package:flutter_riverpod/flutter_riverpod.dart';

class CountryNotifier extends StateNotifier<String> {
  CountryNotifier() : super('Nigeria');

  void setCountry(String country) {
    if (state != country) {
      state = country;
    }
  }
}

final countryProvider = StateNotifierProvider<CountryNotifier, String>((ref) => CountryNotifier());

final availableCountriesProvider = Provider<List<String>>((ref) => [
      'United States',
      'United Kingdom',
      'Canada',
      'Australia',
      'Germany',
      'France',
      'Japan',
      'India',
      'Nigeria',
      'South Africa',
    ]);
