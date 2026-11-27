import 'package:jellyflix/components/ios_sheets.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

/// The one row layout for episodes and downloads everywhere in the app:
/// 16:9 artwork, title, a details line, optional status and description,
/// then trailing controls and the ⋮ menu, all vertically centered on the row.
class MediaRow extends StatelessWidget {
  final Widget image;
  final Widget? imageOverlay;
  final String title;
  final String? details;
  final Widget? status;
  final String? overview;
  final Widget? trailing;
  final List<PopupMenuEntry<String>>? menuEntries;
  final ValueChanged<String>? onMenuSelected;
  final VoidCallback? onTap;

  const MediaRow({
    super.key,
    required this.image,
    required this.title,
    this.imageOverlay,
    this.details,
    this.status,
    this.overview,
    this.trailing,
    this.menuEntries,
    this.onMenuSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 640;
    return InkWell(
      borderRadius: BorderRadius.circular(10.0),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: isWide ? 220 : 140,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: image,
                    ),
                    if (imageOverlay != null) imageOverlay!,
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  if (details != null && details!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      details!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                  if (status != null) ...[
                    const SizedBox(height: 6),
                    status!,
                  ],
                  if (overview != null && overview!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      overview!,
                      maxLines: isWide ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (menuEntries != null && menuEntries!.isNotEmpty)
              AdaptivePopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                iosIcon: const Icon(CupertinoIcons.ellipsis),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.0)),
                itemBuilder: (context) => menuEntries!,
                onSelected: onMenuSelected,
              ),
          ],
        ),
      ),
    );
  }
}
