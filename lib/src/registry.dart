import 'provider.dart';

/// Immutable collection of providers and model aliases.
class Registry {
  factory Registry([Iterable<ProviderInfo> infos = const []]) {
    final providers = <ProviderInfo>[];
    final byName = <String, ProviderInfo>{};
    final byModel = <String, List<ProviderInfo>>{};
    final aliasOrder = <String>[];
    final seenAlias = <String>{};

    for (final info in infos) {
      final name = info.name.trim();
      if (name.isEmpty) {
        throw ArgumentError('gollmfree: provider name is required');
      }
      final key = normalizeRegistryKey(name);
      if (byName.containsKey(key)) {
        throw ArgumentError('gollmfree: duplicate provider name "$name"');
      }

      final stored = info.copyWith(
        name: name,
        supportedModels: normalizeModelAliases(info.supportedModels),
      );
      providers.add(stored);
      byName[key] = stored;

      final aliases = [key, 'auto', 'best', ...stored.supportedModels];
      final seenProviderAlias = <String>{};
      for (final rawAlias in aliases) {
        final alias = normalizeRegistryKey(rawAlias);
        if (alias.isEmpty || !seenProviderAlias.add(alias)) continue;
        if (seenAlias.add(alias)) aliasOrder.add(alias);
        byModel.putIfAbsent(alias, () => <ProviderInfo>[]).add(stored);
      }
    }

    return Registry._(
      List.unmodifiable(providers),
      Map.unmodifiable(byName),
      Map.unmodifiable(<String, List<ProviderInfo>>{
        for (final entry in byModel.entries)
          entry.key: List<ProviderInfo>.unmodifiable(entry.value),
      }),
      List.unmodifiable(aliasOrder),
    );
  }

  const Registry._(
    this._providers,
    this._byName,
    this._byModel,
    this._aliasOrder,
  );

  final List<ProviderInfo> _providers;
  final Map<String, ProviderInfo> _byName;
  final Map<String, List<ProviderInfo>> _byModel;
  final List<String> _aliasOrder;

  /// Registered providers in registration order.
  List<ProviderInfo> get providers => List.unmodifiable(_providers);

  /// Provider metadata by normalized [name].
  ProviderInfo? provider(String name) => _byName[normalizeRegistryKey(name)];

  /// Providers that can handle [model].
  List<ProviderInfo> candidates(String model) {
    return List.unmodifiable(_byModel[normalizeRegistryKey(model)] ?? const []);
  }

  /// Known aliases and provider coverage in deterministic alias order.
  List<ModelInfo> models() {
    return List.unmodifiable(
      _aliasOrder.map((alias) {
        final providers = _byModel[alias] ?? const <ProviderInfo>[];
        return ModelInfo(
          alias: alias,
          providers: List.unmodifiable(providers.map((info) => info.name)),
        );
      }),
    );
  }
}

String normalizeRegistryKey(String value) => value.trim().toLowerCase();

List<String> normalizeModelAliases(Iterable<String> aliases) {
  final normalized =
      aliases
          .map(normalizeRegistryKey)
          .where((alias) => alias.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  return List.unmodifiable(normalized);
}
