/// Serializes writes from both features, including their preflight reads.
class LocalWriteCoordinator {
  Future<void> _pending = Future<void>.value();

  Future<T> run<T>(Future<T> Function() operation) {
    final result = _pending.then((_) => operation());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> get settled => _pending;
}
