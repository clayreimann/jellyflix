import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:jellyflix/components/download_controls.dart';
import 'package:tentacle/tentacle.dart';

/// Download control on the detail page. Uses the same shared state and
/// actions as episode and download rows.
class RoundedDownloadButton extends ConsumerWidget {
  const RoundedDownloadButton({
    super.key,
    required this.itemId,
    required this.data,
  });

  final String itemId;
  final BaseItemDto data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(child: DownloadStateButton(itemId: itemId));
  }
}
