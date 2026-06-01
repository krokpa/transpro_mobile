import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../offline/favorites_cache.dart';

class FavoritesState {
  final List<Map<String, dynamic>> companies;
  final List<Map<String, dynamic>> stations;
  const FavoritesState({required this.companies, required this.stations});

  FavoritesState copyWith({
    List<Map<String, dynamic>>? companies,
    List<Map<String, dynamic>>? stations,
  }) => FavoritesState(
    companies: companies ?? this.companies,
    stations: stations ?? this.stations,
  );

  bool isCompanyFavorite(String id) => companies.any((c) => c['id'] == id);
  bool isStationFavorite(String id) => stations.any((s) => s['id'] == id);
}

class FavoritesNotifier extends StateNotifier<FavoritesState> {
  FavoritesNotifier()
      : super(FavoritesState(
          companies: FavoritesCache.getCompanies(),
          stations: FavoritesCache.getStations(),
        ));

  Future<void> toggleCompany(Map<String, dynamic> company) async {
    await FavoritesCache.toggleCompany(company);
    state = state.copyWith(companies: FavoritesCache.getCompanies());
  }

  Future<void> toggleStation(Map<String, dynamic> station) async {
    await FavoritesCache.toggleStation(station);
    state = state.copyWith(stations: FavoritesCache.getStations());
  }
}

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, FavoritesState>(
  (ref) => FavoritesNotifier(),
);
