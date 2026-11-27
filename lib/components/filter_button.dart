import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:jellyflix/components/adaptive.dart';
import 'package:material_ui/material_ui.dart';

class FilterButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final int length;

  /// Shows a small down chevron on iOS, for buttons that open a list.
  final bool opensList;

  const FilterButton(
      {super.key,
      this.onPressed,
      required this.text,
      required this.length,
      this.opensList = true});

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return _iosButton(context);
    }
    return TextButton(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
            (states) => Theme.of(context).focusColor),
      ),
      onPressed: onPressed,
      child: Row(
        children: [
          Text(
            text,
            overflow: TextOverflow.ellipsis,
          ),
          if (length > 1)
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).buttonTheme.colorScheme!.primary,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  "$length",
                  style: TextStyle(
                    color: Theme.of(context).buttonTheme.colorScheme!.onPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// A small tinted capsule, like the filter buttons in iOS apps.
  Widget _iosButton(BuildContext context) {
    final tint = CupertinoTheme.of(context).primaryColor;
    return CupertinoButton.tinted(
      sizeStyle: CupertinoButtonSize.small,
      borderRadius: BorderRadius.circular(100),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      minimumSize: const Size(0, 30),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15)),
          if (length > 1) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text("$length",
                  style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.systemBackground
                          .resolveFrom(context))),
            ),
          ],
          if (opensList) ...[
            const SizedBox(width: 3),
            const Icon(CupertinoIcons.chevron_down, size: 12),
          ],
        ],
      ),
    );
  }
}
