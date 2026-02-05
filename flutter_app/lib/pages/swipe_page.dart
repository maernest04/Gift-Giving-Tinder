import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme.dart';
import '../services/theme_service.dart';
import '../models/swipe_item.dart';
import '../services/seed_data_service.dart';
import '../services/recommendation_engine.dart';
import '../services/unsplash_service.dart';
import '../services/adaptive_recommender.dart';
import '../services/ml_gift_recommender.dart';

class SwipePage extends StatefulWidget {
  const SwipePage({super.key});

  @override
  State<SwipePage> createState() => _SwipePageState();
}

class _SwipePageState extends State<SwipePage>
    with SingleTickerProviderStateMixin {
  // Adaptive recommender ("ML") over the 10-D item vectors.
  late final AdaptiveRecommender _recommender;
  
  // Full ML gift recommendation system that learns patterns
  late final MLGiftRecommender _mlGiftRecommender;

  // The pool of unseen items + a 2-card stack (top + next).
  late List<SwipeItem> _allItems;
  List<SwipeItem> _cards = [];

  // Track seen items to avoid repetition
  final List<String> _seenIds = [];

  // Avoid flash of empty state before initial cards load
  bool _initialLoadDone = false;

  // Animation State
  late AnimationController _animController;
  Offset _dragOffset = Offset.zero;
  bool _isAnimatingOut = false;

  @override
  void initState() {
    super.initState();
    _recommender = AdaptiveRecommender(
      d: RecommendationEngine.vectorDimension,
      // Slightly explore; tweak as desired.
      epsilon: 0.18,
      priorVariance: 0.7,
    );
    _mlGiftRecommender = MLGiftRecommender(
      vectorRecommender: _recommender,
    );
    
    // Load historical swipes to learn from past behavior
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _mlGiftRecommender.loadHistoricalData(user.uid);
    }
    
    _animController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 400),
        )..addListener(() {
          setState(() {}); // Rebuild on animation frame
        });

    _loadInitialCards();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _loadInitialCards() {
    _allItems = List<SwipeItem>.from(SeedDataService.getAllItems());
    _allItems.shuffle();
    _seenIds.clear();
    _recommender.reset();

    // Start with a random top card to gather initial signal.
    final first = _allItems.removeLast();
    _seenIds.add(first.id);

    final second = _pickNextFromPool(excludeIds: _seenIds);
    setState(() {
      _cards = second == null ? [first] : [second, first];
      _initialLoadDone = true;
    });
  }

  SwipeItem? _pickNextFromPool({required List<String> excludeIds}) {
    final candidates = _allItems
        .where((i) => !excludeIds.contains(i.id))
        .toList();
    final next = _recommender.selectNext(candidates);
    if (next == null) return null;
    // Remove from pool to avoid repeats.
    _allItems.removeWhere((i) => i.id == next.id);
    return next;
  }

  void _onPanStart(DragStartDetails details) {
    if (_isAnimatingOut) return;
    _animController.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isAnimatingOut) return;
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isAnimatingOut) return;

    final width = MediaQuery.of(context).size.width;
    final threshold = width * 0.3; // Swipe 30% of screen to confirm

    if (_dragOffset.dx > threshold) {
      _animateOut(true); // Right / Like
    } else if (_dragOffset.dx < -threshold) {
      _animateOut(false); // Left / Nope
    } else {
      // Snap back to center
      final start = _dragOffset;
      _runAnimation(
        (t) {
          _dragOffset = Offset.lerp(start, Offset.zero, t)!;
        },
        duration: const Duration(milliseconds: 300), // Quick snap back
      );
    }
  }

  /// Programmatic swipe (e.g. from buttons)
  void _triggerSwipe(bool isLiked) {
    if (_cards.isEmpty || _isAnimatingOut) return;

    // Start slightly in the direction so it feels like a push
    _dragOffset = Offset(isLiked ? 20 : -20, 0);
    _animateOut(isLiked);
  }

  /// Animates the card off screen
  void _animateOut(bool isLiked) {
    _isAnimatingOut = true;
    final width = MediaQuery.of(context).size.width;
    // Target is way off screen
    final endOffset = Offset(
      isLiked ? width * 1.5 : -width * 1.5,
      _dragOffset.dy + 50,
    );
    final startOffset = _dragOffset;

    _runAnimation(
      (t) {
        // Linear lerp for position looks fine for fly-out
        _dragOffset = Offset.lerp(startOffset, endOffset, t)!;
      },
      duration: const Duration(milliseconds: 1000), // Smoother, slower exit
      onComplete: () {
        _completeSwipe(isLiked);
      },
    );
  }

  /// Runs a transient animation from 0 to 1 using the controller
  void _runAnimation(
    void Function(double) onUpdate, {
    VoidCallback? onComplete,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    _animController.reset();
    _animController.duration = duration;

    // Using a curve makes it feel more natural
    final curve = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    void listener() {
      onUpdate(curve.value);
    }

    _animController.addListener(listener);

    _animController.forward().then((_) {
      _animController.removeListener(listener);
      if (onComplete != null) onComplete();
    });
  }

  void _completeSwipe(bool isLiked) {
    // Reset state for next card
    _isAnimatingOut = false;
    _dragOffset = Offset.zero;

    // Logic from original _onSwipe
    if (_cards.isEmpty) return;

    final item = _cards.last;

    setState(() {
      _cards.removeLast();
      _seenIds.add(item.id);
    });

    // Learn from both likes and dislikes.
    _recommender.update(item.vector, liked: isLiked);
    
    // Full ML learning: learn tag patterns, category relationships, and combinations
    _mlGiftRecommender.learnFromSwipe(item, isLiked);

    // Persist the swipe to Firestore for long-term learning / gift suggestions.
    _recordSwipe(item, isLiked);

    // Refill the stack back to 2 cards if possible.
    final need = 2 - _cards.length;
    if (need > 0) {
      final next = _pickNextFromPool(excludeIds: _seenIds);
      if (next != null) {
        setState(() {
          // Background card sits below; insert at start so "last" remains top.
          _cards.insert(0, next);
        });
      }
    }

    // Stop when we run out of items.
    if (_cards.isEmpty) return;
  }

  Future<void> _recordSwipe(SwipeItem item, bool isLiked) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final firestore = FirebaseFirestore.instance;
    try {
      // Raw swipe events (optional for analytics / replay).
      await firestore.collection('userSwipes').add({
        'userId': user.uid,
        'itemId': item.id,
        'name': item.name,
        'liked': isLiked,
        'tags': item.tags,
        'vector': item.vector,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Aggregated preferences: titles and tags used for gift recommendations.
      final prefRef = firestore.collection('userPreferences').doc(user.uid);
      if (isLiked) {
        await prefRef.set({
          'likedTitles': FieldValue.arrayUnion([item.name]),
          'likedTags': FieldValue.arrayUnion(item.tags),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await prefRef.set({
          'dislikedTitles': FieldValue.arrayUnion([item.name]),
          'dislikedTags': FieldValue.arrayUnion(item.tags),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {
      // Swallow errors; swipe UX shouldn't break on write failure.
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        // Avoid flash: show loading until first batch of cards is ready
        if (!_initialLoadDone && _cards.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_cards.isEmpty) {
          return _buildEmptyState();
        }

        // Calculate rotation based on X position
        // Max rotation = 15 degrees (~0.26 rad) at screen edge
        final screenWidth = MediaQuery.of(context).size.width;
        final rotation = (_dragOffset.dx / screenWidth) * 0.4;

        // Dynamic transition for the next card (background)
        // As the top card moves away, the background card scales up and fades in.
        final dragDistance = _dragOffset.distance;
        // Reach full size when card is moved halfway across screen
        final progress = (dragDistance / (screenWidth * 0.5)).clamp(0.0, 1.0);

        final nextScale = 0.95 + (0.05 * progress);
        final nextOpacity = 0.6 + (0.4 * progress);

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Card Area
            Stack(
              alignment: Alignment.center,
              children: [
                // Background Card (Next in line)
                if (_cards.length > 1)
                  Transform.scale(
                    scale: nextScale,
                    child: Opacity(
                      opacity: nextOpacity,
                      child: _buildCard(_cards[_cards.length - 2]),
                    ),
                  ),

                // Top Card (Gesture Controlled)
                GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: Transform.translate(
                    offset: _dragOffset,
                    child: Transform.rotate(
                      angle: rotation, // Dynamic Tilt!
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.9,
                        height: MediaQuery.of(context).size.height * 0.55,
                        child: _buildCard(
                          _cards.last,
                          overlayOpacity:
                              (_dragOffset.dx.abs() / (screenWidth * 0.4))
                                  .clamp(0.0, 1.0),
                          isLike: _dragOffset.dx > 0,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // UI Controls (extra bottom padding for home indicator / safe area)
            Padding(
              padding: EdgeInsets.only(
                top: 24,
                bottom: 20 + MediaQuery.of(context).padding.bottom,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildAnimatedActionButton(
                    icon: Icons.close,
                    color: Colors.red,
                    isActive: _dragOffset.dx < -50,
                    scale: _dragOffset.dx < 0
                        ? 1.0 +
                              (_dragOffset.dx.abs() / screenWidth * 0.5).clamp(
                                0.0,
                                0.4,
                              )
                        : 1.0,
                    onTap: () => _triggerSwipe(false), // Animate Left
                  ),
                  const SizedBox(width: 32),
                  _buildAnimatedActionButton(
                    icon: Icons.favorite,
                    color: Colors.green,
                    isActive: _dragOffset.dx > 50,
                    scale: _dragOffset.dx > 0
                        ? 1.0 +
                              (_dragOffset.dx.abs() / screenWidth * 0.5).clamp(
                                0.0,
                                0.4,
                              )
                        : 1.0,
                    onTap: () => _triggerSwipe(true), // Animate Right
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCard(
    SwipeItem item, {
    double overlayOpacity = 0.0,
    bool isLike = true,
  }) {
    final cardBg = themeService.isGlass
        ? Colors.white.withOpacity(0.85)
        : AppColors.bgCard;

    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: themeService.isGlass
            ? Border.all(color: Colors.white.withOpacity(0.5))
            : Border.all(color: AppColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Image
                  Expanded(flex: 3, child: _buildSmartImage(item)),

                  // Content
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.name,
                            style: AppTextStyles.h2.copyWith(fontSize: 24),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.left,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            alignment: WrapAlignment.start,
                            crossAxisAlignment: WrapCrossAlignment.start,
                            children: item.tags
                                .map(
                                  (tag) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryGradient[0]
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.primaryGradient[0]
                                            .withOpacity(0.3),
                                      ),
                                    ),
                                    child: Text(
                                      tag.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryGradient[0],
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            item.description,
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.getSecondaryTextColor(),
                              fontSize: 14,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.left,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Swipe Feedback Overlay
              if (overlayOpacity > 0.01)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isLike
                            ? [
                                Colors.green.withOpacity(overlayOpacity * 0.3),
                                Colors.green.withOpacity(0),
                              ]
                            : [
                                Colors.red.withOpacity(overlayOpacity * 0.3),
                                Colors.red.withOpacity(0),
                              ],
                      ),
                    ),
                    child: Center(
                      child: Opacity(
                        opacity: overlayOpacity.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 0.8 + (overlayOpacity * 0.4),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.2),
                              border: Border.all(
                                color: isLike ? Colors.green : Colors.red,
                                width: 4,
                              ),
                            ),
                            child: Icon(
                              isLike ? Icons.favorite : Icons.close,
                              color: isLike ? Colors.green : Colors.red,
                              size: 80,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isActive = false,
    double scale = 1.0,
  }) {
    // Smoothly animate back to 1.0 when resetting, but react instantly when dragging
    final duration = (scale == 1.0)
        ? const Duration(milliseconds: 300)
        : Duration.zero;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: scale,
        duration: duration,
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(isActive ? 0.6 : 0.3),
                blurRadius: isActive ? 25 : 15,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(
              color: isActive ? color : Colors.transparent,
              width: isActive ? 2 : 0,
            ),
          ),
          child: Icon(icon, color: color, size: 32),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(32, 32, 32, 32 + bottom),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.green,
            ),
            const SizedBox(height: 24),
            Text("Learning Complete!", style: AppTextStyles.h2),
            const SizedBox(height: 8),
            Text(
              "Your Vector Brain has analyzed your style.",
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: AppColors.getSecondaryTextColor(),
              ),
            ),
            const SizedBox(height: 24),

            // ML-Narrowed Categories Display
            FutureBuilder<Map<String, dynamic>>(
              future: _mlGiftRecommender.getMyRecommendations(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                
                final data = snapshot.data ?? {};
                final narrowed = List<String>.from(data['narrowedCategories'] ?? []);
                final combinations = List<String>.from(data['combinations'] ?? []);
                
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "🎯 ML-Narrowed Categories:",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (narrowed.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: narrowed.take(8).map((cat) => Chip(
                            label: Text(cat, style: const TextStyle(fontSize: 11)),
                            padding: EdgeInsets.zero,
                          )).toList(),
                        ),
                      ] else
                        const Text(
                          "Keep swiping to learn your preferences!",
                          style: TextStyle(fontSize: 12),
                        ),
                      if (combinations.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          "💡 Intelligent Combinations:",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        ...combinations.take(3).map((combo) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            "• $combo",
                            style: const TextStyle(fontSize: 11),
                          ),
                        )),
                      ],
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Reset for demo
                _loadInitialCards();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGradient[0],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Reset & Learn Again",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartImage(SwipeItem item) {
    if (!item.imageUrl.startsWith('unsplash:')) {
      return Image.network(
        item.imageUrl,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (ctx, _, __) => _buildPlaceholder(),
      );
    }

    if (!UnsplashService.enabled) return _buildPlaceholder();

    final query = item.imageUrl.replaceFirst('unsplash:', '');

    return FutureBuilder<String>(
      future: UnsplashService.getImageUrl(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.grey[900],
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final url = snapshot.data ?? '';
        if (url.isEmpty) return _buildPlaceholder();

        return Image.network(
          url,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (ctx, _, __) => _buildPlaceholder(),
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: const Center(
        child: Icon(Icons.image, size: 50, color: Colors.white54),
      ),
    );
  }
}
