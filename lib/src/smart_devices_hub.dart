import 'package:http/http.dart' as http;

import 'adapters/fritz_adapter.dart';
import 'adapters/tapo_adapter.dart';
import 'models/device_models.dart';

class SmartDevicesHub {
  SmartDevicesHub({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  final Map<String, TapoDeviceAdapter> _tapoDevices = {};
  FritzBoxAdapter? _fritzAdapter;

  Future<SmartDevice> addTapoPlug(TapoDeviceConfig config) async {
    final adapter = TapoDeviceAdapter(config);
    final device = await adapter.describe();
    _tapoDevices[device.id] = adapter;
    return device;
  }

  void removeTapoPlug(String deviceId) {
    _tapoDevices.remove(deviceId)?.dispose();
  }

  Future<void> configureFritzBox(FritzBoxConfig config) async {
    _fritzAdapter?.dispose();
    _fritzAdapter = FritzBoxAdapter(config, httpClient: _httpClient);
    await _fritzAdapter!.ensureSession();
  }

  Future<List<SmartDevice>> listDevices({bool refreshFritz = true}) async {
    final devices = <SmartDevice>[];
    for (final adapter in _tapoDevices.values) {
      devices.add(adapter.toSmartDevice());
    }
    final fritz = _fritzAdapter;
    if (fritz != null) {
      if (refreshFritz) {
        devices.addAll(await fritz.discoverDevices());
      } else {
        devices.addAll(await fritz.discoverDevices());
      }
    }
    return devices;
  }

  Future<EnergyReading?> readEnergy(String deviceId) async {
    if (deviceId.startsWith('tapo:')) {
      final tapo = _tapoDevices[deviceId];
      return tapo?.fetchEnergy();
    }
    if (deviceId.startsWith('fritz:')) {
      if (deviceId == 'fritz:box') {
        return null;
      }
      final fritz = _fritzAdapter;
      if (fritz == null) {
        return null;
      }
      return fritz.readEnergy(deviceId);
    }
    return null;
  }

  Future<EnvironmentReading?> readEnvironment(String deviceId) async {
    if (deviceId.startsWith('fritz:')) {
      final fritz = _fritzAdapter;
      if (fritz == null) {
        return null;
      }
      return fritz.readEnvironment(deviceId);
    }
    return null;
  }

  Future<SmartDeviceReading> readDevice(String deviceId) async {
    final energy = await readEnergy(deviceId);
    final environment = await readEnvironment(deviceId);
    return SmartDeviceReading(energy: energy, environment: environment);
  }

  Future<NetworkCounters?> readOnlineCounters() async {
    final fritz = _fritzAdapter;
    if (fritz == null) {
      return null;
    }
    return fritz.readOnlineCounters();
  }

  Future<List<WifiClient>> listWifiClients() async {
    final fritz = _fritzAdapter;
    if (fritz == null) {
      return const [];
    }
    return fritz.listWifiClients();
  }

  void dispose() {
    for (final adapter in _tapoDevices.values) {
      adapter.dispose();
    }
    _tapoDevices.clear();
    _fritzAdapter?.dispose();
    _httpClient.close();
  }
}
