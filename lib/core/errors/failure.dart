class Failure {
  const Failure({required this.message, this.code});

  final String message;
  final String? code;

  @override
  String toString() {
    if (code == null || code!.isEmpty) {
      return message;
    }
    return 'Failure(code: $code, message: $message)';
  }
}
