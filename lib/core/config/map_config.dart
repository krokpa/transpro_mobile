import 'package:flutter/painting.dart';
import 'app_constants.dart';

// ── Map provider configuration ────────────────────────────────────────────────
//
// Change [kMapProvider] to switch between Mapbox and OpenStreetMap globally.

enum MapProvider { mapbox, openStreetMap }

// ── Active provider ───────────────────────────────────────────────────────────
// Changer ici pour basculer sur openStreetMap (gratuit, aucune clé requise)
const kMapProvider = MapProvider.mapbox;

// ── Route polyline ────────────────────────────────────────────────────────────
const kRoutePolylineColor = Color(0xFF1A73E8); // bleu Google Maps-style
const kRoutePolylineWidth = 4.5;

// ── Tile URL helpers ──────────────────────────────────────────────────────────

String get tileUrlTemplate {
  if (kMapProvider == MapProvider.mapbox) {
    return 'https://api.mapbox.com/styles/v1/mapbox/$kMapboxStyle/tiles/256/{z}/{x}/{y}@2x?access_token=$kMapboxToken';
  }
  return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
}

String get tileAttribution {
  if (kMapProvider == MapProvider.mapbox) {
    return '© <a href="https://www.mapbox.com/about/maps/">Mapbox</a> © <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>';
  }
  return '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap contributors</a>';
}
