import 'package:flutter_smart_devices/flutter_smart_devices.dart';

/// A client connected via wifi
class WifiClient {
  const WifiClient({required this.name, this.ip, this.mac, this.connectionType, this.isOnline});

  final String name;
  final String? ip;
  final String? mac;
  final String? connectionType;
  final bool? isOnline;
}
