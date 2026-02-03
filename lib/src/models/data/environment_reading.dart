/// Snapshot of the current environment
class EnvironmentReading {
  const EnvironmentReading({this.temperatureCelsius, this.humidityPercent, this.raw});

  /// The current temperature
  final double? temperatureCelsius;

  /// The current humidity in percent
  final double? humidityPercent;

  final Object? raw;
}
