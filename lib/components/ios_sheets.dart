import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:dio/dio.dart';
import 'package:jellyflix/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// iOS menus, pickers and alerts that stand in for Material popups.
/// Call these only after checking `isCupertino(context)`.

/// One button in [showIosActionSheet].
class IosSheetAction<T> {
  final T value;
  final String label;

  /// Bold, for the current choice.
  final bool isDefault;

  /// Red, for deleting or other destructive actions.
  final bool isDestructive;

  const IosSheetAction({
    required this.value,
    required this.label,
    this.isDefault = false,
    this.isDestructive = false,
  });
}

/// An action sheet sliding up from the bottom, with a separate Cancel
/// button. Returns the picked action's value, or null on Cancel.
Future<T?> showIosActionSheet<T>({
  required BuildContext context,
  String? title,
  String? message,
  required List<IosSheetAction<T>> actions,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showCupertinoModalPopup<T>(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) => CupertinoActionSheet(
      title: title == null ? null : Text(title),
      message: message == null ? null : Text(message),
      actions: [
        for (final action in actions)
          CupertinoActionSheetAction(
            isDefaultAction: action.isDefault,
            isDestructiveAction: action.isDestructive,
            onPressed: () => Navigator.pop(sheetContext, action.value),
            child: Text(action.label,
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(sheetContext),
        child: Text(l10n.cancel),
      ),
    ),
  );
}

/// Shows Material [PopupMenuItem]s as an iOS action sheet, so a widget
/// that builds a popup menu can reuse its entries on iOS.
Future<T?> showIosActionSheetForMenu<T>({
  required BuildContext context,
  String? title,
  required List<PopupMenuEntry<T>> entries,
}) {
  final actions = <IosSheetAction<T>>[];
  for (final entry in entries) {
    if (entry is! PopupMenuItem<T> || entry.value == null) continue;
    final label = _menuItemLabel(entry.child);
    if (label == null) continue;
    actions.add(IosSheetAction(value: entry.value as T, label: label));
  }
  return showIosActionSheet<T>(
      context: context, title: title, actions: actions);
}

String? _menuItemLabel(Widget? child) {
  if (child is Text) return child.data;
  if (child is ListTile) return _menuItemLabel(child.title);
  if (child is Row) {
    for (final c in child.children) {
      final label = _menuItemLabel(c);
      if (label != null) return label;
    }
  }
  if (child is Padding) return _menuItemLabel(child.child);
  if (child is Flexible) return _menuItemLabel(child.child);
  return null;
}

/// An iOS alert with one OK button.
Future<void> showIosAlert({
  required BuildContext context,
  required String title,
  String? message,
}) {
  return showCupertinoDialog<void>(
    context: context,
    useRootNavigator: true,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(AppLocalizations.of(dialogContext)!.ok),
        ),
      ],
    ),
  );
}

/// What a failed request says, for showing to the user: the server's own
/// message when it sent one, else the HTTP status, else the error itself.
String describeError(Object error) {
  if (error is TimeoutException) {
    return 'The server didn\'t answer in time.';
  }
  if (error is DioException) {
    final response = error.response;
    final data = response?.data;
    String? body;
    if (data is String && data.trim().isNotEmpty) {
      body = data.trim();
    } else if (data is Map) {
      body = (data['message'] ??
              data['Message'] ??
              data['title'] ??
              data['detail'])
          ?.toString();
    }
    if (response != null) {
      final status = '${response.statusCode}'
          '${response.statusMessage == null ? '' : ' ${response.statusMessage}'}';
      return body == null ? status : '$status: $body';
    }
    return error.message ?? error.type.name;
  }
  return error.toString();
}

/// Tells the user a setting didn't save, with what the server said.
/// An iOS alert on iOS, a Material dialog elsewhere.
Future<void> showSaveFailedAlert(BuildContext context, Object error) {
  final l10n = AppLocalizations.of(context)!;
  final message =
      '${l10n.settingNotSavedText}\n\n${l10n.serverSaid(describeError(error))}';
  if (Theme.of(context).platform == TargetPlatform.iOS) {
    return showIosAlert(
        context: context, title: l10n.settingNotSaved, message: message);
  }
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.settingNotSaved),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.ok),
        ),
      ],
    ),
  );
}

/// A full-screen iOS list to pick one or several items, slid up as a
/// modal page with Cancel and Done in the bar.
///
/// With [multiple] false, tapping a row picks it and closes the page.
/// Returns the picked list, or null on Cancel.
Future<List<T>?> showIosListPicker<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  required String Function(T) label,
  required List<T> selected,
  bool multiple = true,

  /// A first row that clears the selection, e.g. "All".
  String? clearLabel,

  /// Called with the pick instead of closing the page, for callers whose
  /// handler closes it themselves.
  ValueChanged<List<T>>? onDone,
}) {
  return Navigator.of(context, rootNavigator: true).push<List<T>>(
    CupertinoPageRoute(
      fullscreenDialog: true,
      builder: (_) => _IosListPicker<T>(
        title: title,
        items: items,
        label: label,
        selected: selected,
        multiple: multiple,
        clearLabel: clearLabel,
        onDone: onDone,
      ),
    ),
  );
}

class _IosListPicker<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final String Function(T) label;
  final List<T> selected;
  final bool multiple;
  final String? clearLabel;
  final ValueChanged<List<T>>? onDone;

  const _IosListPicker({
    super.key,
    required this.title,
    required this.items,
    required this.label,
    required this.selected,
    required this.multiple,
    required this.clearLabel,
    required this.onDone,
  });

  @override
  State<_IosListPicker<T>> createState() => _IosListPickerState<T>();
}

class _IosListPickerState<T> extends State<_IosListPicker<T>> {
  late final List<T> _picked = [...widget.selected];
  String _query = '';

  void _finish(List<T> picked) {
    if (widget.onDone != null) {
      widget.onDone!(picked);
    } else {
      Navigator.pop(context, picked);
    }
  }

  void _tap(T item) {
    if (!widget.multiple) {
      _finish([item]);
      return;
    }
    setState(() {
      if (_picked.contains(item)) {
        _picked.remove(item);
      } else {
        _picked.add(item);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tint = CupertinoTheme.of(context).primaryColor;
    final shown = _query.isEmpty
        ? widget.items
        : widget.items
            .where((i) =>
                widget.label(i).toLowerCase().contains(_query.toLowerCase()))
            .toList();
    Widget check(bool on) => on
        ? Icon(CupertinoIcons.check_mark, color: tint, size: 20)
        : const SizedBox();

    return CupertinoPageScaffold(
      backgroundColor:
          CupertinoColors.systemGroupedBackground.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.title),
        transitionBetweenRoutes: false,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        trailing: widget.multiple
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _finish(_picked),
                child: Text(l10n.done,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              )
            : null,
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          children: [
            if (widget.items.length > 12)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: CupertinoSearchTextField(
                  placeholder: l10n.search,
                  onChanged: (q) => setState(() => _query = q),
                ),
              ),
            CupertinoListSection.insetGrouped(
              backgroundColor: const Color(0x00000000),
              hasLeading: false,
              children: [
                if (widget.clearLabel != null && _query.isEmpty)
                  CupertinoListTile(
                    title: Text(widget.clearLabel!),
                    trailing: check(_picked.isEmpty),
                    onTap: () {
                      if (widget.multiple) {
                        setState(_picked.clear);
                      } else {
                        _finish(<T>[]);
                      }
                    },
                  ),
                for (final item in shown)
                  CupertinoListTile(
                    title: Text(widget.label(item)),
                    trailing: check(_picked.contains(item)),
                    onTap: () => _tap(item),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A [PopupMenuButton] that opens an iOS action sheet on iOS instead of a
/// Material popup menu. The same [itemBuilder] feeds both.
class AdaptivePopupMenuButton<T> extends StatelessWidget {
  final PopupMenuItemBuilder<T> itemBuilder;
  final PopupMenuItemSelected<T>? onSelected;
  final Widget? child;
  final Widget? icon;

  /// The button's icon on iOS, when [icon] is a Material glyph.
  final Widget? iosIcon;
  final ShapeBorder? shape;
  final String? tooltip;

  /// Shown at the top of the iOS action sheet.
  final String? iosTitle;

  const AdaptivePopupMenuButton({
    super.key,
    required this.itemBuilder,
    this.onSelected,
    this.child,
    this.icon,
    this.iosIcon,
    this.shape,
    this.tooltip,
    this.iosTitle,
  });

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      Future<void> open() async {
        final picked = await showIosActionSheetForMenu<T>(
          context: context,
          title: iosTitle,
          entries: itemBuilder(context),
        );
        if (picked != null) onSelected?.call(picked);
      }

      if (child != null) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: open,
          child: child,
        );
      }
      return CupertinoButton(
        padding: const EdgeInsets.all(8),
        minimumSize: Size.zero,
        onPressed: open,
        child: iosIcon ?? icon ?? const Icon(CupertinoIcons.ellipsis),
      );
    }
    return PopupMenuButton<T>(
      itemBuilder: itemBuilder,
      onSelected: onSelected,
      icon: icon,
      shape: shape,
      tooltip: tooltip,
      child: child,
    );
  }
}
