import 'package:jellyflix/components/adaptive.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

class SwitchSettingsTile extends StatelessWidget {
  final Widget? leading;
  final bool value;
  final Function(bool)? onChanged;
  final Widget title;
  const SwitchSettingsTile({
    super.key,
    this.leading,
    required this.value,
    required this.title,
    this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      // A Settings-app row; pairs with SettingsSection's grouped list.
      return CupertinoListTile(
        leading: leading == null
            ? null
            : IconTheme.merge(
                data: IconThemeData(
                    color: Theme.of(context).colorScheme.primary, size: 24),
                child: leading!,
              ),
        title: title,
        trailing: AdaptiveSwitch(value: value, onChanged: onChanged),
        onTap: onChanged == null ? null : () => onChanged!(!value),
      );
    }
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      leading: leading,
      title: title,
      trailing: AdaptiveSwitch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
