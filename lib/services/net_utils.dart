/// Helpers to recognise "no internet" style errors so the app can quietly fall
/// back to cached data instead of showing crash screens / error popups.
class NetErr {
  static const _patterns = [
    'SocketException',
    'Failed host lookup',
    'ClientException',
    'Network is unreachable',
    'No address associated',
    'Connection refused',
    'Connection reset',
    'Connection closed',
    'Connection timed out',
    'HandshakeException',
    'TimeoutException',
    'WebSocketChannelException',
    'WebSocketException',
    'errno = 7',
  ];

  static bool isNetwork(Object e) {
    final s = e.toString();
    return _patterns.any(s.contains);
  }

  /// Short, human friendly text for snackbars.
  static String friendly(Object e) {
    if (isNetwork(e)) return "You're offline. Check your internet connection.";
    return e.toString();
  }
}
