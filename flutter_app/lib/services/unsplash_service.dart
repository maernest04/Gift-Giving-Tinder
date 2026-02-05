import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class UnsplashService {
  static String get _accessKey => dotenv.env['UNSPLASH_ACCESS_KEY'] ?? '';

  /// True when UNSPLASH_ACCESS_KEY is set; otherwise uses picsum fallback only.
  static bool get enabled => _accessKey.isNotEmpty;

  /// Fetches a high-quality image URL for a given query.
  /// If no Unsplash key is set, returns a picsum fallback immediately.
  static Future<String> getImageUrl(
    String query, {
    int width = 600,
    int height = 400,
  }) async {
    if (_accessKey.isEmpty) {
      return 'https://picsum.photos/seed/${query.hashCode}/$width/$height';
    }

    debugPrint('Fetching image for: $query');

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.unsplash.com/search/photos?query=${Uri.encodeComponent(query)}&per_page=1&orientation=landscape',
            ),
            headers: {'Authorization': 'Client-ID $_accessKey'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final imageUrl = data['results'][0]['urls']['regular'];
          debugPrint('Unsplash success: $imageUrl');
          // Append size parameters to the Unsplash URL for optimization
          return '$imageUrl&w=$width&h=$height&fit=crop';
        } else {
          debugPrint('Unsplash returned no results for: $query');
        }
      } else {
        debugPrint(
          'Unsplash API error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Unsplash Service Exception: $e');
    }

    // Fallback if API fails or rate limit hit
    // Using picsum.photos as a more reliable fallback for many queries
    return 'https://picsum.photos/seed/${query.hashCode}/$width/$height';
  }
}
