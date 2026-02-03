import 'package:flutter/material.dart';
import '../theme.dart';

class SwipePage extends StatelessWidget {
  const SwipePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("✨", style: TextStyle(fontSize: 64)),
          const SizedBox(height: 24),
          Text("All caught up!", style: AppTextStyles.h2),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              "You've seen all the gift ideas for now. Check back later!",
              style: AppTextStyles.body.copyWith(
                color: AppColors.getSecondaryTextColor(),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
