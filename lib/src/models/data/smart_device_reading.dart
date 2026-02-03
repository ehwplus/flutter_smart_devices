import 'package:flutter_smart_devices/flutter_smart_devices.dart';

class SmartDeviceReading {
  const SmartDeviceReading({this.energy, this.environment});

  final EnergyReport? energy;
  final EnvironmentReading? environment;
}
