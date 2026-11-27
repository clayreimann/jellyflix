import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:jellyflix/components/adaptive.dart';
import 'package:material_ui/material_ui.dart';

/// A group of settings rows.
///
/// On iOS this is an inset grouped list like the Settings app. Elsewhere it
/// is the app's tinted rounded box.
class SettingsSection extends StatelessWidget {
  final List<Widget> children;

  /// Optional header shown above the group on iOS.
  final Widget? header;

  const SettingsSection({super.key, required this.children, this.header});

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return CupertinoListSection.insetGrouped(
        header: header,
        // Let the page colour show between the groups.
        backgroundColor: const Color(0x00000000),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: children,
      );
    }
    // A Material (rather than a coloured Container) so the tiles' ink
    // lands on the tinted box instead of being hidden under it.
    return Material(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(15),
      child: Column(children: children),
    );
  }
}

/// One settings row: a [CupertinoListTile] on iOS, a [ListTile] elsewhere.
class SettingsTile extends StatelessWidget {
  final IconData icon;

  /// The iOS glyph (a [CupertinoIcons] icon) and badge colour. Falls back
  /// to [icon] on a grey badge.
  final IconData? iosIcon;
  final Color? iosColor;
  final Widget title;

  /// The current value, shown at the trailing edge (e.g. "8 Mb/s").
  final Widget? value;

  /// A control such as a switch, shown at the trailing edge.
  final Widget? control;
  final VoidCallback? onTap;

  /// Red text and icon, for logging out or deleting.
  final bool destructive;

  /// Shows a chevron on iOS, for rows that open another screen or a picker.
  final bool opensMore;

  const SettingsTile({
    super.key,
    required this.icon,
    this.iosIcon,
    this.iosColor,
    required this.title,
    this.value,
    this.control,
    this.onTap,
    this.destructive = false,
    this.opensMore = false,
  });

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    if (isCupertino(context)) {
      final red = CupertinoColors.systemRed.resolveFrom(context);
      return CupertinoListTile(
        leading: SettingsIconBadge(
          icon: iosIcon ?? icon,
          color: destructive ? red : iosColor,
        ),
        title: iosWrappingTitle(destructive
            ? DefaultTextStyle.merge(style: TextStyle(color: red), child: title)
            : title),
        additionalInfo: value,
        trailing:
            control ?? (opensMore ? const CupertinoListTileChevron() : null),
        onTap: onTap,
      );
    }
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      leading: Icon(icon, color: destructive ? error : null),
      title: title,
      trailing: control ?? value,
      onTap: onTap,
    );
  }
}

/// Lets an iOS list-row title wrap onto more lines, as Settings does with
/// long labels and large Dynamic Type sizes, instead of the one truncated
/// line [CupertinoListTile] uses by default.
Widget iosWrappingTitle(Widget title) {
  return Builder(
    builder: (context) => DefaultTextStyle(
      style: DefaultTextStyle.of(context).style,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
        child: title,
      ),
    ),
  );
}

/// The iOS Settings-app icon: a white glyph on a small coloured rounded
/// square.
class SettingsIconBadge extends StatelessWidget {
  final IconData icon;
  final Color? color;

  const SettingsIconBadge({super.key, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 29,
      height: 29,
      decoration: BoxDecoration(
        color: CupertinoDynamicColor.resolve(
            color ?? CupertinoColors.systemGrey, context),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(icon, color: const Color(0xFFFFFFFF), size: 18),
    );
  }
}

/// On iOS, pushes a Settings-style choice list (labels on the left, a
/// checkmark on the right of the current value) and returns the picked
/// value, or null if the user goes back without picking.
Future<T?> showIosChoicePicker<T>({
  required BuildContext context,
  required String title,
  String? footer,
  required Map<T, String> options,
  T? selected,
}) {
  return Navigator.of(context).push<T>(
    CupertinoPageRoute(
      builder: (context) => _IosChoiceList<T>(
        title: title,
        footer: footer,
        options: options,
        selected: selected,
      ),
    ),
  );
}

class _IosChoiceList<T> extends StatelessWidget {
  final String title;
  final String? footer;
  final Map<T, String> options;
  final T? selected;

  const _IosChoiceList({
    super.key,
    required this.title,
    required this.footer,
    required this.options,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CupertinoNavigationBar(
        middle: Text(title),
        transitionBetweenRoutes: false,
      ),
      body: ListView(
        children: [
          CupertinoListSection.insetGrouped(
            backgroundColor: const Color(0x00000000),
            hasLeading: false,
            footer: footer == null
                ? null
                : Text(footer!,
                    style: TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel
                            .resolveFrom(context))),
            children: [
              for (final entry in options.entries)
                CupertinoListTile(
                  title: Text(entry.value),
                  trailing: entry.key == selected
                      ? Icon(CupertinoIcons.check_mark,
                          color: CupertinoTheme.of(context).primaryColor)
                      : null,
                  onTap: () => Navigator.of(context).pop(entry.key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// On iOS, asks to confirm a destructive action in an action sheet with a
/// red button. Returns true when confirmed.
Future<bool> showIosDestructiveConfirm({
  required BuildContext context,
  Widget? title,
  required String confirmLabel,
  required String cancelLabel,
}) async {
  final confirmed = await showCupertinoModalPopup<bool>(
    context: context,
    builder: (context) => CupertinoActionSheet(
      title: title,
      actions: [
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context, false),
        child: Text(cancelLabel),
      ),
    ),
  );
  return confirmed ?? false;
}
