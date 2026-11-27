import 'package:flutter/material.dart';

import 'eat_screen.dart';

/// The Nutrition tab: Food ([EatScreen]) alone. Beta 6.7 (H1, owner
/// 2026-11-27): Progress and Recovery moved to Home, so there is no switch
/// at the top (beta 5.9 to 6.6 had Food · Progress · Recovery here).
class NutritionTabScreen extends StatelessWidget {
  const NutritionTabScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: const EatScreen(),
          ),
        ),
      );
}
