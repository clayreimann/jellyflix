import 'package:flutter/foundation.dart';

/// Facts about the running build, injected at build time:
///
///   flutter build ios --dart-define=GIT_SHA=$(git rev-parse --short HEAD)
///
/// Leave GIT_SHA out of store builds and the line under About is hidden
/// there (it always shows in debug and profile builds).
class BuildInfo {
  static const String gitSha = String.fromEnvironment('GIT_SHA');

  /// Whether to show the build line: a dev build, or any build that was
  /// given a GIT_SHA.
  static bool get show => gitSha.isNotEmpty || !kReleaseMode;
}
