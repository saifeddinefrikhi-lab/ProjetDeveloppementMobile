import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Helper service to perform reverse geocoding (coordinates -> address)
/// and forward geocoding (address -> coordinates) using OpenStreetMap Nominatim.
/// Free, does not require an API key, works seamlessly on Windows and mobile.
class GeocodingService {
  GeocodingService._();
  static final GeocodingService instance = GeocodingService._();

  static const _userAgent = 'WasteClassificationApp/1.0';

  /// Converts (latitude, longitude) into a human-readable street address.
  Future<String?> reverseGeocode(
    double lat,
    double lon, {
    String languageCode = 'fr',
  }) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json'
        '&lat=$lat'
        '&lon=$lon'
        '&zoom=18'
        '&addressdetails=1'
        '&accept-language=$languageCode',
      );

      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;

        // Try to construct a clean short address if available
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          final parts = <String>[];
          final road = address['road'] ??
              address['pedestrian'] ??
              address['street'] ??
              address['suburb'] ??
              address['county'];
          if (road != null && road.toString().isNotEmpty) {
            parts.add(road.toString());
          }

          final city = address['city'] ??
              address['town'] ??
              address['village'] ??
              address['municipality'] ??
              address['state_district'];
          if (city != null && city.toString().isNotEmpty) {
            parts.add(city.toString());
          }

          final state = address['state'];
          if (state != null && state.toString().isNotEmpty && state != city) {
            parts.add(state.toString());
          }

          final country = address['country'];
          if (country != null && country.toString().isNotEmpty) {
            parts.add(country.toString());
          }

          if (parts.isNotEmpty) {
            return parts.join(', ');
          }
        }

        // Fallback to full display_name
        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          return displayName;
        }
      }
    } catch (e) {
      debugPrint('[GeocodingService] Reverse geocode error: $e');
    }
    return null;
  }

  /// Converts a text address into (latitude, longitude) coordinates.
  Future<LatLng?> forwardGeocode(String address) async {
    final clean = address.trim();
    if (clean.isEmpty) return null;

    // Check if the string itself contains coordinates (e.g. "GPS: 36.88, 10.17")
    final regex = RegExp(r'(-?\d+\.\d+)[,\s]+(-?\d+\.\d+)');
    final match = regex.firstMatch(clean);
    if (match != null) {
      final lat = double.tryParse(match.group(1)!);
      final lon = double.tryParse(match.group(2)!);
      if (lat != null && lon != null) {
        return LatLng(lat, lon);
      }
    }

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(clean)}'
        '&format=json'
        '&limit=1',
      );

      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final list = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        if (list.isNotEmpty) {
          final item = list.first as Map<String, dynamic>;
          final lat = double.tryParse(item['lat']?.toString() ?? '');
          final lon = double.tryParse(item['lon']?.toString() ?? '');
          if (lat != null && lon != null) {
            return LatLng(lat, lon);
          }
        }
      }
    } catch (e) {
      debugPrint('[GeocodingService] Forward geocode error: $e');
    }
    return null;
  }
}
