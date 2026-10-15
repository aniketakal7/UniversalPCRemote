class AppConstants {
  static const int protocolVersion = 1;
  static const int defaultServerPort = 51234;
  static const int discoveryPort = 51235;
  static const String discoveryServiceId = 'UniversalPCRemote';
  static const Duration requestTimeout = Duration(seconds: 6);
  static const Duration pingInterval = Duration(seconds: 8);
}
