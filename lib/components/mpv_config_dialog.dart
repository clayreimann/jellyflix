import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:jellyflix/components/adaptive.dart';
import 'package:jellyflix/components/settings_list.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:jellyflix/l10n/generated/app_localizations.dart';

class MpvConfigDialog extends HookConsumerWidget {
  const MpvConfigDialog({
    super.key,
    required String mpvConfig,
  }) : _mpvConfig = mpvConfig;

  final String _mpvConfig;

  static String getDefaultConfig() {
    return "# MPV Configuration File\n";
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mpvConfig = useState(_mpvConfig);
    final textController = useTextEditingController(text: _mpvConfig);

    if (isCupertino(context)) {
      return _iosPage(context, textController, mpvConfig);
    }

    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.mpvConfigTitle),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.customMpvConfigDescription,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              maxLines: 10,
              minLines: 5,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'hwdec=auto\ncache=yes\ncache-secs=120',
                contentPadding: const EdgeInsets.all(12),
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              onChanged: (value) {
                mpvConfig.value = value;
              },
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Text(
                      AppLocalizations.of(context)!.mpvConfigResetConfirm,
                    ),
                    content: Text(
                      AppLocalizations.of(context)!.mpvConfigResetDescription,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                        },
                        child: Text(AppLocalizations.of(context)!.cancel),
                      ),
                      TextButton(
                        onPressed: () {
                          final defaultConfig = getDefaultConfig();
                          textController.text = defaultConfig;
                          mpvConfig.value = defaultConfig;
                          Navigator.pop(dialogContext);
                        },
                        child: Text(AppLocalizations.of(context)!.reset),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context)!.resetToDefault),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context, null);
          },
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context, mpvConfig.value);
          },
          child: Text(AppLocalizations.of(context)!.save),
        ),
      ],
    );
  }

  /// iOS: a full-screen modal editor with Cancel and Save in the bar, like
  /// composing a note, rather than a cramped alert.
  Widget _iosPage(BuildContext context, TextEditingController textController,
      ValueNotifier<String> mpvConfig) {
    final l10n = AppLocalizations.of(context)!;
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return CupertinoPageScaffold(
      backgroundColor:
          CupertinoColors.systemGroupedBackground.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.mpvConfigTitle),
        transitionBetweenRoutes: false,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context, mpvConfig.value),
          child: Text(l10n.save,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.customMpvConfigDescription,
                style: TextStyle(fontSize: 13, color: secondary)),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: textController,
              minLines: 10,
              maxLines: 20,
              placeholder: 'hwdec=auto\ncache=yes\ncache-secs=120',
              autocorrect: false,
              enableSuggestions: false,
              padding: const EdgeInsets.all(12),
              style: TextStyle(
                fontFamily: 'Menlo',
                fontSize: 14,
                color: CupertinoColors.label.resolveFrom(context),
              ),
              decoration: BoxDecoration(
                color: CupertinoColors.secondarySystemGroupedBackground
                    .resolveFrom(context),
                borderRadius: BorderRadius.circular(10),
              ),
              onChanged: (value) => mpvConfig.value = value,
            ),
            const SizedBox(height: 16),
            CupertinoButton(
              onPressed: () async {
                if (await showIosDestructiveConfirm(
                  context: context,
                  title: Text(l10n.mpvConfigResetDescription),
                  confirmLabel: l10n.resetToDefault,
                  cancelLabel: l10n.cancel,
                )) {
                  final defaultConfig = getDefaultConfig();
                  textController.text = defaultConfig;
                  mpvConfig.value = defaultConfig;
                }
              },
              child: Text(l10n.resetToDefault,
                  style: TextStyle(
                      color: CupertinoColors.systemRed.resolveFrom(context))),
            ),
          ],
        ),
      ),
    );
  }
}
