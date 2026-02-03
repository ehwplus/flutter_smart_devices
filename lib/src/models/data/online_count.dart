class OnlineCount {
  const OnlineCount({required this.totalBytes, required this.bytesSent, required this.bytesReceived, this.raw});

  final int totalBytes;
  final int bytesSent;
  final int bytesReceived;
  final Object? raw;
}
