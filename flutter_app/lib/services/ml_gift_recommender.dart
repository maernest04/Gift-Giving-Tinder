import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/swipe_item.dart';
import 'seed_data_service.dart';
import 'adaptive_recommender.dart';

/// Full ML-based gift recommendation system that learns patterns from user behavior
/// and automatically narrows down to meaningful category combinations.
class MLGiftRecommender {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdaptiveRecommender _vectorRecommender;

  // Tag co-occurrence matrix: learns which tags appear together in liked items
  final Map<String, Map<String, double>> _tagCooccurrence = {};
  
  // Category embedding: learns relationships between categories
  final Map<String, List<double>> _categoryEmbeddings = {};
  
  // User preference profile (learned from swipes)
  List<double>? _userPreferenceVector;

  MLGiftRecommender({
    required AdaptiveRecommender vectorRecommender,
  }) : _vectorRecommender = vectorRecommender;

  /// Loads historical swipes from Firestore to learn patterns.
  /// Call this on initialization to learn from past user behavior.
  Future<void> loadHistoricalData(String userId) async {
    try {
      final swipes = await _firestore
          .collection('userSwipes')
          .where('userId', isEqualTo: userId)
          .where('liked', isEqualTo: true)
          .get();

      final allItems = SeedDataService.getAllItems();
      final itemMap = {for (var item in allItems) item.id: item};

      for (final doc in swipes.docs) {
        final data = doc.data();
        final itemId = data['itemId'] as String?;
        if (itemId == null) continue;

        final item = itemMap[itemId];
        if (item == null) continue;

        // Learn from this historical like
        learnFromSwipe(item, true);
      }
    } catch (_) {
      // Silently fail - historical data is nice-to-have
    }
  }

  /// Updates the ML model with a new swipe event.
  /// Learns tag patterns, category relationships, and user preferences.
  void learnFromSwipe(SwipeItem item, bool liked) {
    if (!liked) return; // Focus learning on positive signals

    // Update tag co-occurrence: if user likes item with tags [A, B, C],
    // increment co-occurrence counts for all pairs (A-B, A-C, B-C)
    final tags = item.tags;
    for (int i = 0; i < tags.length; i++) {
      for (int j = i + 1; j < tags.length; j++) {
        final tag1 = tags[i];
        final tag2 = tags[j];
        
        _tagCooccurrence.putIfAbsent(tag1, () => {});
        _tagCooccurrence.putIfAbsent(tag2, () => {});
        
        _tagCooccurrence[tag1]![tag2] = (_tagCooccurrence[tag1]![tag2] ?? 0.0) + 1.0;
        _tagCooccurrence[tag2]![tag1] = (_tagCooccurrence[tag2]![tag1] ?? 0.0) + 1.0;
      }
    }

    // Update category embedding: use item's vector as a learned embedding
    // Average with existing embedding if category was seen before
    final categoryName = item.name;
    if (_categoryEmbeddings.containsKey(categoryName)) {
      final existing = _categoryEmbeddings[categoryName]!;
      final newEmbedding = List<double>.generate(
        existing.length,
        (i) => (existing[i] * 0.7 + item.vector[i] * 0.3),
      );
      _categoryEmbeddings[categoryName] = newEmbedding;
    } else {
      _categoryEmbeddings[categoryName] = List<double>.from(item.vector);
    }
  }

  /// Gets the learned user preference vector from the adaptive recommender.
  List<double> _getUserPreferenceVector() {
    // Extract learned weights directly from the adaptive recommender
    return _vectorRecommender.getLearnedPreferenceVector();
  }

  /// ML-based narrowing: finds top categories using learned patterns.
  /// Returns a narrowed list of category names that are most relevant.
  Future<List<String>> getNarrowedCategories(String userId) async {
    // 1. Get user's liked categories from Firestore
    final prefDoc = await _firestore
        .collection('userPreferences')
        .doc(userId)
        .get();

    if (!prefDoc.exists) return [];
    final data = prefDoc.data()!;
    final likedTitles = List<String>.from(data['likedTitles'] ?? []);
    final likedTags = List<String>.from(data['likedTags'] ?? []);

    if (likedTitles.isEmpty) return [];

    // 2. Load all items to compute similarity
    final allItems = SeedDataService.getAllItems();
    final itemMap = {for (var item in allItems) item.name: item};

    // 3. Compute category scores using ML:
    //    - Vector similarity to user's learned preferences
    //    - Tag co-occurrence strength
    //    - Category embedding similarity to liked categories
    final categoryScores = <String, double>{};

    // Get user's learned preference vector from the adaptive recommender
    final userVector = _getUserPreferenceVector();

    for (final likedTitle in likedTitles) {
      final likedItem = itemMap[likedTitle];
      if (likedItem == null) continue;

      // Score other categories by similarity to this liked category
      for (final candidate in allItems) {
        if (likedTitles.contains(candidate.name)) continue; // Skip already liked

        double score = 0.0;

        // ML: Vector similarity to user's learned preference (most important)
        final userSim = _cosineSimilarity(userVector, candidate.vector);
        score += userSim * 0.5;

        // Vector similarity to this specific liked item
        final vectorSim = _cosineSimilarity(likedItem.vector, candidate.vector);
        score += vectorSim * 0.2;

        // Tag overlap (Jaccard similarity)
        final tagOverlap = _jaccardSimilarity(likedItem.tags, candidate.tags);
        score += tagOverlap * 0.15;

        // Tag co-occurrence strength (learned pattern from user's behavior)
        double cooccurScore = 0.0;
        for (final tag1 in likedItem.tags) {
          for (final tag2 in candidate.tags) {
            final cooccur = _tagCooccurrence[tag1]?[tag2] ?? 0.0;
            cooccurScore += cooccur / (1.0 + cooccur); // Normalize
          }
        }
        score += cooccurScore * 0.1;

        // Category embedding similarity (learned from user's patterns)
        if (_categoryEmbeddings.containsKey(candidate.name)) {
          final embedSim = _cosineSimilarity(
            _categoryEmbeddings[candidate.name]!,
            likedItem.vector,
          );
          score += embedSim * 0.05;
        }

        categoryScores[candidate.name] =
            (categoryScores[candidate.name] ?? 0.0) + score;
      }
    }

    // 4. Also score by tag frequency (tags that appear in many liked items are strong signals)
    final tagFrequency = <String, int>{};
    for (final tag in likedTags) {
      tagFrequency[tag] = (tagFrequency[tag] ?? 0) + 1;
    }

    for (final candidate in allItems) {
      if (likedTitles.contains(candidate.name)) continue;
      
      double tagScore = 0.0;
      for (final tag in candidate.tags) {
        tagScore += (tagFrequency[tag] ?? 0).toDouble();
      }
      categoryScores[candidate.name] =
          (categoryScores[candidate.name] ?? 0.0) + tagScore * 0.1;
    }

    // 5. Return top N categories (narrowed down intelligently)
    final sorted = categoryScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Take top categories, but also include some diversity (not all from same cluster)
    final topCategories = <String>[];
    final seenTags = <String>{};
    
    for (final entry in sorted) {
      if (topCategories.length >= 8) break; // Narrow to ~8 categories
      
      final item = itemMap[entry.key];
      if (item == null) continue;
      
      // Add diversity: don't add if too similar to already selected
      bool tooSimilar = false;
      for (final selected in topCategories) {
        final selectedItem = itemMap[selected];
        if (selectedItem == null) continue;
        final sim = _cosineSimilarity(item.vector, selectedItem.vector);
        if (sim > 0.85) {
          tooSimilar = true;
          break;
        }
      }
      
      if (!tooSimilar) {
        topCategories.add(entry.key);
        seenTags.addAll(item.tags);
      }
    }

    return topCategories;
  }

  // Theme labels from vector dimensions (see SeedDataService):
  // 0: Tech, 1: Outdoors, 2: Style, 3: Luxury, 4: Budget, 5: Cozy, 6: Active, 7: Geek, 8: Art, 9: Food
  static const List<String> _themeNames = [
    'Tech & gadgets',
    'Outdoors & adventure',
    'Style & fashion',
    'Luxury & premium',
    'Practical picks',
    'Home & cozy',
    'Fitness & wellness',
    'Geek & creative',
    'Art & design',
    'Food & drink',
  ];

  /// Returns thematic gift ideas: groups liked categories by theme so ideas
  /// read as "Theme: Item1 & Item2" instead of random "A + B" pairs.
  Future<List<String>> getIntelligentCombinations(String userId) async {
    final narrowed = await getNarrowedCategories(userId);
    if (narrowed.isEmpty) return [];

    final allItems = SeedDataService.getAllItems();
    final itemMap = {for (var item in allItems) item.name: item};

    // Assign each category to its dominant theme (vector dimension)
    final themeToCategories = <String, List<String>>{};
    for (final name in narrowed) {
      final item = itemMap[name];
      if (item == null || item.vector.isEmpty) continue;
      final theme = _themeForVector(item.vector);
      themeToCategories.putIfAbsent(theme, () => []).add(name);
    }

    final ideas = <String>[];
    // Prefer themes that have 2+ items (actual "combos"); then single-category ideas
    final multi = themeToCategories.entries
        .where((e) => e.value.length >= 2)
        .toList();
    final single = themeToCategories.entries
        .where((e) => e.value.length == 1)
        .toList();

    for (final e in multi) {
      final theme = e.key;
      final cats = e.value;
      // One readable line per theme: "Theme: Item1 & Item2" (or 3 if we have them)
      final list = cats.take(3).join(' & ');
      ideas.add('$theme: $list');
      if (ideas.length >= 6) return ideas;
    }
    for (final e in single) {
      if (ideas.length >= 6) break;
      ideas.add('${e.key}: ${e.value.first}');
    }

    return ideas.take(6).toList();
  }

  String _themeForVector(List<double> vector) {
    int best = 0;
    for (int i = 1; i < vector.length && i < _themeNames.length; i++) {
      if (vector[i] > vector[best]) best = i;
    }
    return _themeNames[best];
  }

  // -----------------------
  // ML similarity functions
  // -----------------------

  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    double dot = 0.0, normA = 0.0, normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0.0;
    return dot / (sqrt(normA) * sqrt(normB));
  }

  double _jaccardSimilarity(List<String> a, List<String> b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    final setA = a.toSet();
    final setB = b.toSet();
    final intersection = setA.intersection(setB).length;
    final union = setA.union(setB).length;
    return union == 0 ? 0.0 : intersection / union;
  }

  /// Gets recommendations for current user.
  Future<Map<String, dynamic>> getMyRecommendations() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {'narrowedCategories': [], 'combinations': []};
    }
    return getRecommendationsForUser(user.uid);
  }

  /// Gets ML-narrowed categories and gift combinations for any user (e.g. partner).
  Future<Map<String, dynamic>> getRecommendationsForUser(String userId) async {
    final narrowed = await getNarrowedCategories(userId);
    final combinations = await getIntelligentCombinations(userId);
    return {
      'narrowedCategories': narrowed,
      'combinations': combinations,
    };
  }
}
