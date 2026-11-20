import 'package:flutter/material.dart';

class GradientBackground extends StatelessWidget {
  final Widget child;
  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2E2468),
            Color(0xFF7B5EC0),
            Color(0xFFD9A5B8),
            Color(0xFF8A4F7D),
          ],
          stops: [0.0, 0.4, 0.75, 1.0],
        ),
      ),
      child: child,
    );
  }
}