// SPDX-License-Identifier: MIT

/// Named route constants for `go_router` (see `route_config.dart`).
///
/// Centralising the name strings avoids typo-prone literals scattered
/// across `context.goNamed(...)` call sites — a rename here propagates at
/// compile time instead of failing silently on a mistyped string.
class RouteNames {
  static const String join = 'join';
  static const String result = 'result';
  static const String create = 'create';
  static const String addplayer = 'addPlayer';
  static const String home = 'home';
  static const String simple = 'simple';
  static const String game = 'game';
  static const String settings = 'settings';
}
