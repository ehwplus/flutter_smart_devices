import 'package:flutter_tapo/flutter_tapo.dart';

import '../models/device_models.dart';

class TapoDeviceAdapter {
  TapoDeviceAdapter(this.config)
      : _client = HttpTapoApiClient(
          host: config.host,
          port: config.port,
          useHttps: config.useHttps,
        );

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
      metadata: {
        'host': config.host,
        'port': config.port,
        'useHttps': config.useHttps,
      },
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

  Future<EnergyReading> fetchEnergy() async {
    await _loadDeviceInfo();
    final usage = await _client.getEnergyUsage();
    return EnergyReading(
      todayWh: usage.todayEnergy.toDouble(),
      monthWh: usage.monthEnergy.toDouble(),
      raw: usage,
    );
  }

  Future<void> _ensureAuthenticated() async {
    if (_client.isAuthenticated || _isAuthenticating) {
      return;
    }
    _isAuthenticating = true;
    try {
      await _client.authenticate(
        email: config.email,
        password: config.password,
      );
    } finally {
      _isAuthenticating = false;
    }
  }

  void dispose() {
    _client.close();
  }
}
