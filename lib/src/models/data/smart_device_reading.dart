import 'package:flutter_smart_devices/flutter_smart_devices.dart';

class SmartDeviceReading {
  const SmartDeviceReading({this.energyReadings, this.energyReport, this.environment});

  final EnergyReadings? energyReadings;
  final EnergyReport? energyReport;
  final EnvironmentReading? environment;
}
