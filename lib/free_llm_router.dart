/// Core Dart API for free_llm_router.
///
/// This library is safe to import from Flutter apps, including web builds. I/O
/// backed providers are exported separately from `package:free_llm_router/providers.dart`.
///
/// Routing strategies, degradation, and fallback policy are inspired by
/// OmniRoute's multi-strategy routing engine.
library;

export 'src/client.dart';
export 'src/degradation.dart';
export 'src/errors.dart';
export 'src/fallback_policy.dart';
export 'src/health.dart';
export 'src/provider.dart';
export 'src/registry.dart';
export 'src/routing_strategy.dart';
export 'src/types.dart';
