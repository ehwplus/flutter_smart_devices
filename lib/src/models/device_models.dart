import 'package:meta/meta.dart';

enum SmartDeviceVendor { tapo, fritz }

enum SmartDeviceType { tapoP100, tapoP115, fritzDect200, fritzSmartControl440, fritzBox }

enum DeviceCapability { energy, temperature, humidity, networkCounters, wifiClients }

@immutable
class SmartDevice {
  const SmartDevice({
    required this.id,
    required this.name,
    required this.vendor,
    required this.type,
    required this.capabilities,
    this.metadata = const {},
  });

  final String id;
  final String name;
  final SmartDeviceVendor vendor;
  final SmartDeviceType type;
  final Set<DeviceCapability> capabilities;
  final Map<String, Object?> metadata;

  SmartDevice copyWith({String? name, Set<DeviceCapability>? capabilities, Map<String, Object?>? metadata}) {
    return SmartDevice(
      id: id,
      name: name ?? this.name,
      vendor: vendor,
      type: type,
      capabilities: capabilities ?? this.capabilities,
      metadata: metadata ?? this.metadata,
    );
  }
}

class EnergyReading {
  const EnergyReading({this.todayWh, this.monthWh, this.powerW, this.raw});

  final double? todayWh;
  final double? monthWh;
  final double? powerW;
  final Object? raw;
}

class EnvironmentReading {
  const EnvironmentReading({this.temperatureCelsius, this.humidityPercent, this.raw});

  final double? temperatureCelsius;
  final double? humidityPercent;
  final Object? raw;
}

class OnlineCounters {
  const OnlineCounters({required this.totalBytes, required this.bytesSent, required this.bytesReceived, this.raw});

  final int totalBytes;
  final int bytesSent;
  final int bytesReceived;
  final Object? raw;
}

class WifiClient {
  const WifiClient({required this.name, this.ip, this.mac, this.connectionType, this.isOnline});

  final String name;
  final String? ip;
  final String? mac;
  final String? connectionType;
  final bool? isOnline;
}

class SmartDeviceReading {
  const SmartDeviceReading({this.energy, this.environment});

  final EnergyReading? energy;
  final EnvironmentReading? environment;
}

class FritzBoxConfig {
  const FritzBoxConfig({this.baseUrl = 'http://fritz.box', this.username, required this.password});

  final String baseUrl;
  final String? username;
  final String password;
}

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
