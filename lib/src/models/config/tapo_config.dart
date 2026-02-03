import 'package:flutter_smart_devices/src/models/device/smart_device_type.dart';

class TapoDeviceConfig {
  const TapoDeviceConfig({
    required this.host,
    required this.email,
    required this.password,
    this.useHttps = false,
    this.port = 80,
    this.name,
    this.model = SmartDeviceType.tapoP115,
  }) : assert(model == SmartDeviceType.tapoP100 || model == SmartDeviceType.tapoP115);

  final String host;
  final int port;
  final bool useHttps;
  final String email;
  final String password;
  final String? name;
  final SmartDeviceType model;
}
