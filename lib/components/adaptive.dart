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

/// The system bar material on iOS: UIKit's default tab and toolbar
/// background, slightly see-through so content blurs under it.
const CupertinoDynamicColor iosChromeColor =
    CupertinoDynamicColor.withBrightness(
  color: Color(0xF0F9F9F9),
  darkColor: Color(0xF01D1D1D),
);

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

/// An iOS page with a large title that shrinks into the nav bar as the
/// content scrolls, an optional pull-to-refresh spinner and [children]
/// laid out as a list.
///
/// Only meant for iOS; callers keep their Material layout elsewhere.
class IosLargeTitlePage extends StatelessWidget {
  final String title;
  final Widget? trailing;

  /// Shown under the large title, e.g. a count or a size.
  final Widget? subtitle;
  final Future<void> Function()? onRefresh;
  final List<Widget> slivers;

  const IosLargeTitlePage({
    super.key,
    required this.title,
    this.trailing,
    this.subtitle,
    this.onRefresh,
    required this.slivers,
  });

  @override
  Widget build(BuildContext context) {
    return IosPageScaffold(
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(title),
            trailing: trailing,
            transitionBetweenRoutes: false,
          ),
          if (onRefresh != null)
            CupertinoSliverRefreshControl(onRefresh: onRefresh),
          if (subtitle != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    fontSize: 15,
                  ),
                  child: subtitle!,
                ),
              ),
            ),
          ...slivers,
          const IosBottomInset(),
        ],
      ),
    );
  }
}

/// Space at the end of an iOS scroll view for the floating tab bar (its
/// height arrives as the bottom padding), so the last items can scroll
/// clear of it.
class IosBottomInset extends StatelessWidget {
  const IosBottomInset({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(height: MediaQuery.paddingOf(context).bottom),
    );
  }
}

/// A borderless icon button for iOS nav bars.
class IosNavBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? semanticLabel;

  const IosNavBarButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      onPressed: onPressed,
      child: Icon(icon, semanticLabel: semanticLabel),
    );
  }
}

/// A text field: a filled rounded [CupertinoTextField] with the label as
/// its placeholder on iOS, an outlined Material [TextField] elsewhere.
class AdaptiveTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hintText;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  const AdaptiveTextField({
    super.key,
    this.controller,
    required this.label,
    this.hintText,
    this.obscureText = false,
    this.autofillHints,
    this.textInputAction,
    this.keyboardType,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return CupertinoTextField(
        controller: controller,
        placeholder: label,
        obscureText: obscureText,
        autofillHints: autofillHints,
        textInputAction: textInputAction,
        keyboardType: keyboardType,
        onSubmitted: onSubmitted,
        autocorrect: false,
        clearButtonMode: obscureText
            ? OverlayVisibilityMode.never
            : OverlayVisibilityMode.editing,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
          borderRadius: BorderRadius.circular(10),
        ),
      );
    }
    return TextField(
      controller: controller,
      obscureText: obscureText,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: label,
        hintText: hintText,
      ),
    );
  }
}

/// An iOS page: a [CupertinoPageScaffold], so a large-title nav bar stays
/// see-through (page-coloured) until content scrolls under it, as UIKit's
/// does. A Material [Scaffold] keeps the bar's grey always on, which made
/// a band that content seemed to butt up against.
class IosPageScaffold extends StatelessWidget {
  final Widget body;

  /// Grouped settings pages use the grouped grey; others the plain page.
  final bool grouped;

  const IosPageScaffold({super.key, required this.body, this.grouped = false});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: grouped
          ? CupertinoColors.systemGroupedBackground.resolveFrom(context)
          : Theme.of(context).scaffoldBackgroundColor,
      // Material widgets inside (ink, tooltips, text fields) need one.
      child: Material(type: MaterialType.transparency, child: body),
    );
  }
}
