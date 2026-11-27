import 'dart:ui' show ImageFilter;

import 'package:cupertino_ui/cupertino_ui.dart';

/// One tab in an [IosTabBar].
class IosTabItem {
  final IconData icon;
  final String label;

  const IosTabItem({required this.icon, required this.label});
}

/// A tab bar laid out like UIKit's UITabBar.
///
/// [CupertinoTabBar] always stacks the icon over the label at a fixed
/// 50pt. UITabBar does that only in compact width (an iPhone held upright).
/// When the screen is wide (an iPhone in landscape, or an iPad), the icon
/// and label sit side by side, and in landscape the bar is a short 32pt.
/// The selected tab differs only by tint: same glyph, no fill or circle.
class IosTabBar extends StatelessWidget {
  final List<IosTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Color? activeColor;

  const IosTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.activeColor,
  });

  /// Bar height above the home indicator, as UITabBar uses it.
  static const double portraitHeight = 49;
  static const double landscapeHeight = 32;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final landscape = media.size.width > media.size.height;
    final inline = landscape || media.size.width >= 600;
    // A phone in landscape has compact height: the short bar.
    final short = landscape && media.size.height < 500;
    final height = short ? landscapeHeight : portraitHeight;

    final active = activeColor ?? CupertinoTheme.of(context).primaryColor;
    final inactive = CupertinoColors.systemGrey.resolveFrom(context);
    final background = CupertinoTheme.of(context).barBackgroundColor;
    final separator = CupertinoColors.separator.resolveFrom(context);

    // Text in the bar follows Dynamic Type only a little, like UIKit,
    // so labels never push the bar taller or wrap.
    final scaler = media.textScaler.clamp(maxScaleFactor: 1.2);

    final bar = DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border(top: BorderSide(color: separator, width: 0.0)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: media.padding.bottom,
          left: media.padding.left,
          right: media.padding.right,
        ),
        child: SizedBox(
          height: height,
          child: MediaQuery(
            data: media.copyWith(textScaler: scaler),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _IosTabButton(
                      item: items[i],
                      color: i == currentIndex ? active : inactive,
                      inline: inline,
                      selected: i == currentIndex,
                      onTap: () => onTap(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    // Translucent bar: blur what scrolls under it, like the system bar.
    if (background.a < 1.0) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: bar,
        ),
      );
    }
    return bar;
  }
}

class _IosTabButton extends StatelessWidget {
  final IosTabItem item;
  final Color color;
  final bool inline;
  final bool selected;
  final VoidCallback onTap;

  const _IosTabButton({
    required this.item,
    required this.color,
    required this.inline,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = Text(
      item.label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: inline ? 13 : 10,
        fontWeight: FontWeight.w500,
        letterSpacing: inline ? -0.08 : 0.1,
      ),
    );
    final icon = Icon(item.icon, color: color, size: inline ? 21 : 25);

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: inline
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: 6),
                  Flexible(child: label),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(height: 2),
                  label,
                ],
              ),
      ),
    );
  }
}
