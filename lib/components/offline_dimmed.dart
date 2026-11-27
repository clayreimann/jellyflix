import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:jellyflix/providers/offline_provider.dart';
import 'package:tentacle/tentacle.dart';

const _grayscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0,
]);

/// Grays out its child while offline if [item] hasn't been downloaded.
class OfflineDimmed extends ConsumerWidget {
  final BaseItemDto item;
  final Widget child;

  const OfflineDimmed({super.key, required this.item, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isOfflineProvider)) return child;
    final availability = ref.watch(offlineAvailabilityProvider).value;
    if (availability == null || availability.isAvailable(item)) return child;
    return Opacity(
      opacity: 0.35,
      child: ColorFiltered(colorFilter: _grayscale, child: child),
    );
  }
}
