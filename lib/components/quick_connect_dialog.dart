import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:jellyflix/components/adaptive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:jellyflix/providers/api_provider.dart';
import 'package:jellyflix/l10n/generated/app_localizations.dart';

class QuickConnectDialog extends HookConsumerWidget {
  const QuickConnectDialog({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codeController = useTextEditingController();
    final errorText = useState<String?>(null);
    final busy = useState(false);
    final l10n = AppLocalizations.of(context)!;

    Future<void> connect() async {
      busy.value = true;
      final status = await ref
          .read(apiProvider)
          .authorizeQuickConnect(codeController.text);
      busy.value = false;
      if (!context.mounted) return;
      switch (status) {
        case 200:
          context.pop();
        case 401:
          errorText.value = l10n.quickConnectError401;
        case 404:
          errorText.value = l10n.quickConnectError404;
        default:
          errorText.value = l10n.quickConnectErrorUnknown;
      }
    }

    if (isCupertino(context)) {
      // An iOS alert with a text field, like the system's own prompts.
      return CupertinoAlertDialog(
        title: Text(l10n.quickConnect),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            Text(l10n.quickConnectDescription),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: codeController,
              placeholder: l10n.code,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              autofocus: true,
              onSubmitted: (_) => connect(),
            ),
            if (errorText.value != null) ...[
              const SizedBox(height: 8),
              Text(errorText.value!,
                  style: TextStyle(
                      color: CupertinoColors.systemRed.resolveFrom(context))),
            ],
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: busy.value ? null : connect,
            child: busy.value
                ? const CupertinoActivityIndicator()
                : Text(l10n.connect),
          ),
        ],
      );
    }

    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context)!.quickConnect,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            Text(AppLocalizations.of(context)!.quickConnectDescription),
            const SizedBox(height: 20),
            SizedBox(
              width: 250,
              child: TextField(
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.code,
                  hintText: "123456",
                  border: const OutlineInputBorder(),
                  errorText: errorText.value,
                ),
                controller: codeController,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: busy.value ? null : connect,
              child: Text(AppLocalizations.of(context)!.connect),
            ),
          ],
        ),
      ),
    );
  }
}
