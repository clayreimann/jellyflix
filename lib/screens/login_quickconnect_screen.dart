import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jellyflix/l10n/generated/app_localizations.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:jellyflix/models/screen_paths.dart';
import 'package:jellyflix/providers/auth_provider.dart';
import 'package:jellyflix/components/login_messages.dart';

class LoginQuickConnectScreen extends HookConsumerWidget {
  final String serverAddress;
  const LoginQuickConnectScreen({super.key, required this.serverAddress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = useState<String?>(null);

    useEffect(() {
      final token = CancelToken();

      runQuickConnect() async {
        try {
          await ref
              .read(authProvider)
              .loginByQuickConnect(serverAddress, (c) => code.value = c, token);
        } on DioException catch (e) {
          if (!token.isCancelled && context.mounted) {
            await LoginMessages.showHttpErrorDialog(context, e);
          }
        } on Exception catch (e) {
          if (!token.isCancelled && context.mounted) {
            await LoginMessages.showErrorDialog(context, e);
          }
        }

        if (context.mounted) {
          context.go(ScreenPaths.login);
        }
      }

      runQuickConnect();

      return () => token.cancel();
    }, [serverAddress]);

    return Scaffold(
      appBar: AppBar(),
      body: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.enter): () async {}
        },
        child: FocusScope(
          // needed for enter shortcut to work
          autofocus: true,
          child: Center(
            child: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: AutofillGroup(
                    child: Column(
                      children: [
                        Text(AppLocalizations.of(context)!.appName,
                            style: Theme.of(context).textTheme.displaySmall),
                        Text(
                          AppLocalizations.of(context)!.appSubtitle,
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          child: Text(
                            serverAddress,
                            textAlign: TextAlign.left,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        code.value == null
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20.0),
                                child:
                                    Center(child: CircularProgressIndicator()))
                            : Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10.0),
                                    child: Text(
                                      AppLocalizations.of(context)!
                                          .useQuickConnect,
                                      textAlign: TextAlign.left,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        // selectable, and tap or the
                                        // button copies it, to paste into
                                        // another signed-in app
                                        SelectableText(
                                          code.value ?? "",
                                          onTap: () =>
                                              _copyCode(context, code.value),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge,
                                        ),
                                        IconButton(
                                          tooltip:
                                              AppLocalizations.of(context)!
                                                  .copyCode,
                                          icon: const Icon(Icons.copy_rounded),
                                          onPressed: () =>
                                              _copyCode(context, code.value),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                        kIsWeb
                            ? Text(AppLocalizations.of(context)!.webDemoNote)
                            : const SizedBox(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _copyCode(BuildContext context, String? code) async {
    if (code == null || code.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final copied = AppLocalizations.of(context)!.codeCopied;
    await Clipboard.setData(ClipboardData(text: code));
    messenger.showSnackBar(SnackBar(
        content: Text(copied), duration: const Duration(seconds: 2)));
  }
}
