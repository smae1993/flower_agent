/// A user-correctable Flower Agent failure.
final class FlowerException implements Exception {
  const FlowerException(this.message, {this.cause});

  /// A concise, actionable description of the failure.
  final String message;

  /// The original failure, when one is available.
  final Object? cause;

  @override
  String toString() => 'FlowerException: $message';
}
