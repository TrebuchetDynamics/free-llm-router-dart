/// One failed provider attempt.
class AttemptException implements Exception {
  const AttemptException({
    required this.provider,
    required this.attempt,
    required this.error,
  });

  final String provider;
  final int attempt;
  final Object error;

  @override
  String toString() => '$provider attempt $attempt failed: $error';
}

/// Every provider failure from a fallback attempt loop.
class CombinedException implements Exception {
  const CombinedException(this.attempts);

  final List<AttemptException> attempts;

  @override
  String toString() {
    if (attempts.isEmpty) return 'free_llm_router: no provider attempts';
    return 'free_llm_router: all provider attempts failed: ${attempts.join('; ')}';
  }
}
