class SmartDeviceReading {
  const SmartDeviceReading({this.energy, this.environment});

  final EnergyReading? energy;
  final EnvironmentReading? environment;
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

class OnlineCount {
  const OnlineCount({required this.totalBytes, required this.bytesSent, required this.bytesReceived, this.raw});

  final int totalBytes;
  final int bytesSent;
  final int bytesReceived;
  final Object? raw;
}
