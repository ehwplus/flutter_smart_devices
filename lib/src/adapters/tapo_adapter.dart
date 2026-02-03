import 'package:flutter_smart_devices/flutter_smart_devices.dart';
import 'package:flutter_tapo/flutter_tapo.dart';

class TapoDeviceAdapter {
  TapoDeviceAdapter(this.config)
    : _client = HttpTapoApiClient(host: config.host, port: config.port, useHttps: config.useHttps);

  final TapoDeviceConfig config;
  final HttpTapoApiClient _client;

  TapoDeviceInfo? _deviceInfo;
  bool _isAuthenticating = false;

  SmartDevice toSmartDevice() {
    final name = config.name ?? _deviceInfo?.nickname ?? config.host;
    return SmartDevice(
      id: 'tapo:${config.host}',
      name: name,
      vendor: SmartDeviceVendor.tapo,
      type: config.model,
      capabilities: const {DeviceCapability.energy},
      metadata: {'host': config.host, 'port': config.port, 'useHttps': config.useHttps},
    );
  }

  Future<SmartDevice> describe() async {
    await _loadDeviceInfo();
    return toSmartDevice();
  }

  Future<TapoDeviceInfo> _loadDeviceInfo() async {
    await _ensureAuthenticated();
    _deviceInfo ??= await _client.getDeviceInfo();
    return _deviceInfo!;
  }

  Future<EnergyReport> fetchEnergyReport() async {
    await _loadDeviceInfo();
    final usage = await _client.getEnergyUsage();
    return EnergyReport(todayWh: usage.todayEnergy.toDouble(), monthWh: usage.monthEnergy.toDouble(), raw: usage);
  }

  Future<EnergyReadings> fetchEnergyReadings({
    required EnergyReadingIntervalType intervalType,
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    await _loadDeviceInfo();
    final interval = _buildEnergyInterval(intervalType: intervalType, startDate: startDate, endDate: endDate);
    final data = await _client.getEnergyData(interval);
    return _mapEnergyReadings(data, intervalType: intervalType);
  }

  Future<void> _ensureAuthenticated() async {
    if (_client.isAuthenticated || _isAuthenticating) {
      return;
    }
    _isAuthenticating = true;
    try {
      await _client.authenticate(email: config.email, password: config.password);
    } finally {
      _isAuthenticating = false;
    }
  }

  void dispose() {
    _client.close();
  }

  static TapoEnergyDataInterval _buildEnergyInterval({
    required EnergyReadingIntervalType intervalType,
    required DateTime startDate,
    DateTime? endDate,
  }) {
    switch (intervalType) {
      case EnergyReadingIntervalType.hourly:
        if (endDate == null) {
          throw ArgumentError('endDate is required for hourly energy readings.');
        }
        return TapoEnergyDataInterval.hourly(startDate: startDate, endDate: endDate);
      case EnergyReadingIntervalType.activity:
        if (endDate == null) {
          throw ArgumentError('endDate is required for activity energy readings.');
        }
        return TapoEnergyDataInterval.activity(startDate: startDate, endDate: endDate);
      case EnergyReadingIntervalType.daily:
        final quarterStart = _quarterStart(startDate);
        return TapoEnergyDataInterval.daily(quarterStart: quarterStart);
      case EnergyReadingIntervalType.monthly:
        final yearStart = DateTime(startDate.year, 1, 1);
        return TapoEnergyDataInterval.monthly(yearStart: yearStart);
      case EnergyReadingIntervalType.fifteenMinutes:
      case EnergyReadingIntervalType.weekly:
      case EnergyReadingIntervalType.yearly:
        throw UnsupportedError('Interval $intervalType is not supported by Tapo energy data.');
    }
  }

  static EnergyReadings _mapEnergyReadings(
    TapoEnergyData data, {
    required EnergyReadingIntervalType intervalType,
  }) {
    switch (intervalType) {
      case EnergyReadingIntervalType.activity:
        return EnergyReadings(
          intervalType: intervalType,
          entries: _mapActivityReadings(data),
        );
      case EnergyReadingIntervalType.hourly:
      case EnergyReadingIntervalType.daily:
      case EnergyReadingIntervalType.monthly:
        return EnergyReadings(
          intervalType: intervalType,
          entries: _mapPointReadings(data, intervalType: intervalType),
        );
      case EnergyReadingIntervalType.fifteenMinutes:
      case EnergyReadingIntervalType.weekly:
      case EnergyReadingIntervalType.yearly:
        throw UnsupportedError('Interval $intervalType is not supported by Tapo energy data.');
    }
  }

  static List<EnergyReading> _mapPointReadings(
    TapoEnergyData data, {
    required EnergyReadingIntervalType intervalType,
  }) {
    final points = data.points;
    if (points.isEmpty) {
      return const [];
    }

    final intervalMinutes = data.interval ?? 60;
    final entries = <EnergyReading>[];
    for (var index = 0; index < points.length; index += 1) {
      final point = points[index];
      final start = point.start;
      final end = index + 1 < points.length
          ? points[index + 1].start
          : _defaultEndForInterval(intervalType, start, intervalMinutes);
      entries.add(
        EnergyReading(
          value: point.energyWh.toDouble(),
          dateTimeFrom: start.toIso8601String(),
          dateTimeTo: end.toIso8601String(),
          raw: point,
        ),
      );
    }
    return entries;
  }

  static List<EnergyReading> _mapActivityReadings(TapoEnergyData data) {
    final activities = data.activities;
    if (activities.isEmpty) {
      return const [];
    }

    final points = data.points;
    final entries = <EnergyReading>[];
    for (final activity in activities) {
      final totalWh = points
          .where((point) => !point.start.isBefore(activity.start) && point.start.isBefore(activity.end))
          .fold<int>(0, (sum, point) => sum + point.energyWh);
      entries.add(
        EnergyReading(
          value: totalWh.toDouble(),
          dateTimeFrom: activity.start.toIso8601String(),
          dateTimeTo: activity.end.toIso8601String(),
          raw: activity,
        ),
      );
    }
    return entries;
  }

  static DateTime _defaultEndForInterval(
    EnergyReadingIntervalType intervalType,
    DateTime start,
    int intervalMinutes,
  ) {
    switch (intervalType) {
      case EnergyReadingIntervalType.hourly:
        return start.add(Duration(minutes: intervalMinutes));
      case EnergyReadingIntervalType.daily:
        return DateTime(start.year, start.month, start.day + 1);
      case EnergyReadingIntervalType.monthly:
        return DateTime(start.year, start.month + 1, 1);
      case EnergyReadingIntervalType.activity:
      case EnergyReadingIntervalType.fifteenMinutes:
      case EnergyReadingIntervalType.weekly:
      case EnergyReadingIntervalType.yearly:
        return start.add(Duration(minutes: intervalMinutes));
    }
  }

  static DateTime _quarterStart(DateTime date) {
    final quarter = ((date.month - 1) ~/ 3) * 3 + 1;
    return DateTime(date.year, quarter, 1);
  }
}
