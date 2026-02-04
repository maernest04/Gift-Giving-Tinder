import 'dart:math';
import '../models/swipe_item.dart';

class RecommendationEngine {
  // Dimension map for reference
  // 0: Tech / Sci-Fi
  // 1: Nature / Outdoors
  // 2: Fashion / Style
  // 3: Luxury / High-End
  // 4: Budget / DIY
  // 5: Cozy / Home
  // 6: Active / Sport
  // 7: Geek / Pop Culture
  // 8: Art / Creative
  // 9: Food / Cooking
  static const int vectorDimension = 10;

  /// Calculates the Cosine Similarity between two vectors.
  /// Returns a value between -1.0 (opposite) and 1.0 (identical).
  static double cosineSimilarity(List<double> vecA, List<double> vecB) {
    if (vecA.length != vecB.length) {
      throw Exception('Vector lengths do not match');
    }

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < vecA.length; i++) {
      dotProduct += vecA[i] * vecB[i];
      normA += vecA[i] * vecA[i];
      normB += vecB[i] * vecB[i];
    }

    if (normA == 0 || normB == 0) return 0.0;

    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  /// Updates the user's preference vector based on a new liked item.
  /// [currentProfile]: The user's current preference vector.
  /// [itemVector]: The vector of the item they just liked.
  /// [learningRate]: How much the new item influences the profile (0.0 to 1.0).
  ///                 Higher = learns faster but might be erratic.
  ///                 Lower = more stable, requires more data.
  static List<double> updateUserProfile(
    List<double> currentProfile,
    List<double> itemVector, {
    double learningRate = 0.1,
  }) {
    List<double> newProfile = List.filled(vectorDimension, 0.0);

    for (int i = 0; i < vectorDimension; i++) {
      // Move the current point slightly towards the item's point
      // New = Old + (Target - Old) * Rate
      newProfile[i] =
          currentProfile[i] +
          (itemVector[i] - currentProfile[i]) * learningRate;
    }

    return newProfile;
  }

  /// Sorts a list of items by relevance to the user's profile vector.
  static List<SwipeItem> getRecommendations(
    List<double> userProfile,
    List<SwipeItem> allItems, {
    int limit = 10,
    List<String> excludeIds = const [],
  }) {
    // Filter out already seen items
    final candidates = allItems
        .where((item) => !excludeIds.contains(item.id))
        .toList();

    // Calculate scores
    final scoredItems = candidates.map((item) {
      final score = cosineSimilarity(userProfile, item.vector);
      return MapEntry(item, score);
    }).toList();

    // Sort descending (highest score first)
    scoredItems.sort((a, b) => b.value.compareTo(a.value));

    // Return top N
    return scoredItems.take(limit).map((e) => e.key).toList();
  }

  /// Checks if the user's profile is "complete" or confident enough to stop learning.
  static bool isProfileComplete(List<double> userVector, int swipeCount) {
    // 1. Safety Cap: If they've swiped too much, just stop.
    if (swipeCount >= 50) return true;

    // 2. Minimum Data: Don't stop too early.
    if (swipeCount < 5) return false;

    // 3. Strong Signal Check: Do they REALLY like something?
    // If any dimension is > 0.85, that's a strong enough signal.
    for (final score in userVector) {
      if (score > 0.85) return true;
    }

    // 4. (Optional) Stability Check could go here
    // comparing previous vector to current to see if it's changing much.

    return false;
  }
}
