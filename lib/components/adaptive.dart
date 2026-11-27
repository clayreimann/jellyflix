import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// iOS-only look-and-feel helpers.
///
/// Flutter's own `.adaptive` constructors switch to Cupertino on both iOS
/// and macOS. Jellyflix only wants the Cupertino look on iOS, so every
/// widget here checks [isCupertino] first and keeps the Material widget on
/// Android, desktop (including macOS) and the web.

/// Whether this device should get iOS-style widgets.
///
/// Reads the platform from the theme so tests can override it with
/// `debugDefaultTargetPlatformOverride` or `ThemeData(platform: ...)`.
bool isCupertino(BuildContext context) =>
    !kIsWeb && Theme.of(context).platform == TargetPlatform.iOS;

/// Same as [isCupertino] for places without a [BuildContext], such as the
/// root theme.
bool get isCupertinoPlatform =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// A [Switch] that becomes a [CupertinoSwitch] on iOS.
class AdaptiveSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const AdaptiveSwitch({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return Switch.adaptive(value: value, onChanged: onChanged);
    }
    return Switch(value: value, onChanged: onChanged);
  }
}

/// An indeterminate [CircularProgressIndicator] that becomes a
/// [CupertinoActivityIndicator] on iOS.
class AdaptiveProgressIndicator extends StatelessWidget {
  const AdaptiveProgressIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return const CircularProgressIndicator.adaptive();
    }
    return const CircularProgressIndicator();
  }
}

/// Shows a dialog with the iOS presentation (fade in, no barrier dismiss)
/// on iOS and the Material one elsewhere.
Future<T?> showAdaptivePlatformDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool? barrierDismissible,
}) {
  if (isCupertino(context)) {
    return showAdaptiveDialog<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
    );
  }
  return showDialog<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible ?? true,
  );
}

/// A simple alert: a [CupertinoAlertDialog] on iOS, an [AlertDialog]
/// elsewhere. Build the actions with [AdaptiveDialogAction].
class AdaptiveAlertDialog extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final List<Widget> actions;

  const AdaptiveAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return AlertDialog.adaptive(
        title: title,
        content: content,
        actions: actions,
      );
    }
    return AlertDialog(title: title, content: content, actions: actions);
  }
}

/// A dialog button: a [CupertinoDialogAction] on iOS. Elsewhere it is the
/// [materialButton] when one is given, otherwise a [TextButton].
class AdaptiveDialogAction extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool isDefaultAction;
  final bool isDestructiveAction;
  final Widget? materialButton;

  const AdaptiveDialogAction({
    super.key,
    required this.onPressed,
    required this.child,
    this.isDefaultAction = false,
    this.isDestructiveAction = false,
    this.materialButton,
  });

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return CupertinoDialogAction(
        onPressed: onPressed,
        isDefaultAction: isDefaultAction,
        isDestructiveAction: isDestructiveAction,
        child: child,
      );
    }
    return materialButton ?? TextButton(onPressed: onPressed, child: child);
  }
}

/// A top bar: a [CupertinoNavigationBar] (chevron back button, blurred
/// translucent background) on iOS, an [AppBar] elsewhere.
///
/// [transparent] makes the bar see-through with no hairline, for pages that
/// draw artwork behind it.
PreferredSizeWidget adaptiveAppBar(
  BuildContext context, {
  Widget? title,
  List<Widget> actions = const [],
  bool transparent = false,
}) {
  if (isCupertino(context)) {
    return CupertinoNavigationBar(
      middle: title,
      trailing: actions.isEmpty
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: actions),
      backgroundColor: transparent ? const Color(0x00000000) : null,
      border: transparent ? null : _defaultNavBarBorder,
      // Pages come from go_router with mixed transitions; flying titles
      // between them look wrong, so each bar stays put.
      transitionBetweenRoutes: false,
    );
  }
  return AppBar(
    title: title,
    actions: actions,
    backgroundColor: transparent ? Colors.transparent : null,
  );
}

const Border _defaultNavBarBorder = Border(
  bottom: BorderSide(color: Color(0x4D000000), width: 0.0),
);

/// A search field: [CupertinoSearchTextField] on iOS, a Material
/// [SearchBar] elsewhere.
class AdaptiveSearchField extends StatelessWidget {
  final String hintText;
  final ValueChanged<String> onChanged;

  const AdaptiveSearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return CupertinoSearchTextField(
        placeholder: hintText,
        onChanged: onChanged,
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: SearchBar(
        hintText: hintText,
        leading: const Icon(Icons.search_rounded),
        onChanged: onChanged,
      ),
    );
  }
}
