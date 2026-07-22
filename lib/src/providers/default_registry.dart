import '../client.dart';
import '../provider.dart';
import '../registry.dart';
import 'gptfree.dart';
import 'pollinations_ai.dart';
import 'wewordle.dart';

/// Returns the default provider registry used by the CLI.
Registry defaultRegistry() {
  final pollinations = PollinationsAI();
  final wewordle = WeWordle();
  final gptfree = GptFree();
  return Registry([
    _info(pollinations, 1),
    _info(wewordle, 2),
    _info(gptfree, 3),
  ]);
}

/// Returns a client wired to all default Dart providers.
///
/// [maxRetries] is per provider in sequential mode: `0` means no retry
/// after the first attempt. Race mode starts one attempt per raced provider.
GollmfreeClient defaultClient({
  Duration perAttemptTimeout = const Duration(seconds: 60),
  bool raceMode = false,
  int maxRetries = 0,
}) {
  return GollmfreeClient(
    registry: defaultRegistry(),
    perAttemptTimeout: perAttemptTimeout,
    maxRetries: maxRetries,
    raceMode: raceMode,
  );
}

ProviderInfo _info(Provider provider, int priority) {
  return ProviderInfo(
    name: provider.name,
    provider: provider,
    supportedModels: provider.supportedModels,
    defaultPriority: priority,
  );
}
