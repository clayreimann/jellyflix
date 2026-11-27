import 'package:jellyflix/components/adaptive.dart';
import 'package:material_ui/material_ui.dart';

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
