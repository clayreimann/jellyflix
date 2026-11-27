import 'package:jellyflix/components/adaptive.dart';
import 'package:flutter/material.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: AdaptiveProgressIndicator(),
      ),
    );
  }
}
