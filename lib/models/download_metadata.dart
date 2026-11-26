import 'package:tentacle/tentacle.dart';

class DownloadMetadata {
  final String id;
  String name;
  final BaseItemKind type;
  final int runTimeTicks;
  final String? seriesName;
  final String? seriesId;
  final int? indexNumber;
  final int? parentIndexNumber;
  final String? path;
  final int? downloadSize;
  // Added for richer offline browsing. All optional so metadata written by
  // older versions of the app can still be read.
  String? overview;
  String? seasonId;
  String? seasonName;
  int? productionYear;
  DateTime? downloadedAt;

  DownloadMetadata({
    required this.id,
    required this.name,
    required this.type,
    required this.runTimeTicks,
    required this.seriesName,
    required this.seriesId,
    required this.indexNumber,
    required this.parentIndexNumber,
    required this.path,
    this.downloadSize,
    this.overview,
    this.seasonId,
    this.seasonName,
    this.productionYear,
    this.downloadedAt,
  });

  bool get isEpisode => type == BaseItemKind.episode;

  /// The series id, or null if this isn't part of a series.
  String? get normalizedSeriesId =>
      (seriesId == null || seriesId!.isEmpty) ? null : seriesId;

  int get runTimeMinutes => (runTimeTicks / 10000000 / 60).round();

  /// Episode title without the server's placeholder names. Some servers
  /// name episodes with only a number when metadata is missing; in that case
  /// fall back to "Episode N".
  String displayEpisodeTitle(String Function(int) episodeLabel) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || RegExp(r'^\d+$').hasMatch(trimmed)) {
      return episodeLabel(indexNumber ?? int.tryParse(trimmed) ?? 0);
    }
    return trimmed;
  }

  Map<String, dynamic> toJson() {
    return {
      "Id": id,
      "Name": name,
      "Type": type.name,
      "RunTimeTicks": runTimeTicks,
      "SeriesName": seriesName,
      "SeriesId": seriesId,
      "IndexNumber": indexNumber,
      "ParentIndexNumber": parentIndexNumber,
      "Path": path,
      "DownloadSize": downloadSize,
      "Overview": overview,
      "SeasonId": seasonId,
      "SeasonName": seasonName,
      "ProductionYear": productionYear,
      "DownloadedAt": downloadedAt?.toIso8601String(),
    };
  }

  static DownloadMetadata fromJson(Map<String, dynamic> json) {
    return DownloadMetadata(
      id: json["Id"],
      name: json["Name"] ?? "",
      type: BaseItemKind.values.firstWhere((p0) => p0.name == json["Type"],
          orElse: () => BaseItemKind.movie),
      runTimeTicks: json["RunTimeTicks"] ?? 0,
      seriesName: json["SeriesName"],
      seriesId: json["SeriesId"],
      indexNumber: json["IndexNumber"],
      parentIndexNumber: json["ParentIndexNumber"],
      path: json["Path"],
      downloadSize: json["DownloadSize"],
      overview: json["Overview"],
      seasonId: json["SeasonId"],
      seasonName: json["SeasonName"],
      productionYear: json["ProductionYear"],
      downloadedAt: json["DownloadedAt"] == null
          ? null
          : DateTime.tryParse(json["DownloadedAt"]),
    );
  }
}
