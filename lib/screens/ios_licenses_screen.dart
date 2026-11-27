import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:jellyflix/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// iOS: the open-source licenses as a Settings-style list, like
/// Settings > General > Legal & Regulatory: one row per package, each
/// opening its license text. Stands in for Material's LicensePage.
class IosLicensesScreen extends StatefulWidget {
  final String applicationName;
  final String? applicationVersion;

  const IosLicensesScreen({
    super.key,
    required this.applicationName,
    this.applicationVersion,
  });

  @override
  State<IosLicensesScreen> createState() => _IosLicensesScreenState();
}

class _IosLicensesScreenState extends State<IosLicensesScreen> {
  /// Package name to its license entries, sorted by name.
  late final Future<Map<String, List<LicenseEntry>>> _licenses = _load();

  static Future<Map<String, List<LicenseEntry>>> _load() async {
    final byPackage = <String, List<LicenseEntry>>{};
    await for (final entry in LicenseRegistry.licenses) {
      for (final package in entry.packages) {
        byPackage.putIfAbsent(package, () => []).add(entry);
      }
    }
    final names = byPackage.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return {for (final n in names) n: byPackage[n]!};
  }

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return CupertinoPageScaffold(
      backgroundColor:
          CupertinoColors.systemGroupedBackground.resolveFrom(context),
      child: FutureBuilder(
        future: _licenses,
        builder: (context, snapshot) {
          final licenses = snapshot.data;
          return CustomScrollView(
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: Text(AppLocalizations.of(context)!.licenses),
                transitionBetweenRoutes: false,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Text(
                    [
                      widget.applicationName,
                      if (widget.applicationVersion != null)
                        widget.applicationVersion!,
                    ].join(' '),
                    style: TextStyle(fontSize: 13, color: secondary),
                  ),
                ),
              ),
              if (licenses == null)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CupertinoActivityIndicator()),
                )
              else
                SliverSafeArea(
                  top: false,
                  sliver: SliverToBoxAdapter(
                    child: CupertinoListSection.insetGrouped(
                      backgroundColor: const Color(0x00000000),
                      hasLeading: false,
                      children: [
                        for (final entry in licenses.entries)
                          CupertinoListTile(
                            title: Text(entry.key),
                            additionalInfo: entry.value.length > 1
                                ? Text('${entry.value.length}')
                                : null,
                            trailing: const CupertinoListTileChevron(),
                            onTap: () => Navigator.of(context).push(
                              CupertinoPageRoute(
                                title: entry.key,
                                builder: (_) => _IosLicenseText(
                                    package: entry.key, entries: entry.value),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _IosLicenseText extends StatelessWidget {
  final String package;
  final List<LicenseEntry> entries;

  const _IosLicenseText({required this.package, required this.entries});

  @override
  Widget build(BuildContext context) {
    final label = CupertinoColors.label.resolveFrom(context);
    final paragraphs = <Widget>[];
    for (final entry in entries) {
      if (paragraphs.isNotEmpty) {
        paragraphs.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Container(
              height: 0.5,
              color: CupertinoColors.separator.resolveFrom(context)),
        ));
      }
      for (final p in entry.paragraphs) {
        paragraphs.add(Padding(
          padding: EdgeInsets.only(
              left: p.indent == LicenseParagraph.centeredIndent
                  ? 0
                  : 12.0 * p.indent,
              bottom: 8),
          child: Text(
            p.text,
            textAlign: p.indent == LicenseParagraph.centeredIndent
                ? TextAlign.center
                : TextAlign.start,
            style: TextStyle(fontSize: 13, height: 1.35, color: label),
          ),
        ));
      }
    }
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(package),
        transitionBetweenRoutes: false,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: paragraphs,
        ),
      ),
    );
  }
}
