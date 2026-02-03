import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter_fritzapi/flutter_fritzapi.dart';
import 'package:flutter_smart_devices/flutter_smart_devices.dart';
import 'package:http/http.dart' as http;

class FritzBoxAdapter {
  FritzBoxAdapter(this.config, {http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client(),
      _client = _HttpFritzApiClient(baseUrl: config.baseUrl, client: httpClient ?? http.Client());

  final FritzBoxConfig config;
  final http.Client _httpClient;
  final _HttpFritzApiClient _client;

  List<_FritzDeviceHandle> _cachedDevices = [];

  Future<void> ensureSession() async {
    if (_client.sessionId != null && _client.sessionId!.isNotEmpty) {
      return;
    }
    await _client.getSessionId(username: config.username, password: config.password);
  }

  Future<List<SmartDevice>> discoverDevices() async {
    await ensureSession();
    _cachedDevices = await _loadDevices();
    final devices = <SmartDevice>[
      SmartDevice(
        id: 'fritz:box',
        name: 'FRITZ!Box',
        vendor: SmartDeviceVendor.fritz,
        type: SmartDeviceType.fritzBox,
        capabilities: const {DeviceCapability.networkCounters, DeviceCapability.wifiClients},
        metadata: {'baseUrl': config.baseUrl},
      ),
      ..._cachedDevices.map((device) => device.toSmartDevice()),
    ];
    return devices;
  }

  Future<EnergyReport?> readEnergy(String smartDeviceId) async {
    final deviceId = _parseFritzId(smartDeviceId);
    if (deviceId == null) {
      return null;
    }
    await ensureSession();
    final stats = await _client.getEnergyStats(command: HomeAutoQueryCommand.EnergyStats_24h, deviceId: deviceId);
    if (stats == null) {
      return null;
    }
    return EnergyReport(todayWh: stats.sumDay.toDouble(), monthWh: stats.sumMonth.toDouble(), raw: stats);
  }

  Future<EnvironmentReading?> readEnvironment(String smartDeviceId) async {
    final deviceId = _parseFritzId(smartDeviceId);
    if (deviceId == null) {
      return null;
    }
    await ensureSession();
    final devices = await _loadDevices();
    final device = devices.firstWhereOrNull((dev) => dev.deviceId == deviceId);
    if (device == null) {
      return null;
    }
    return EnvironmentReading(
      temperatureCelsius: device.temperatureCelsius,
      humidityPercent: device.humidityPercent,
      raw: device.rawJson,
    );
  }

  Future<OnlineCount?> readOnlineCounters() async {
    await ensureSession();
    final sid = _client.sessionId;
    if (sid == null || sid.isEmpty) {
      return null;
    }

    // TODO: Implementation is not working

    final urls = [
      Uri.parse('${config.baseUrl}/online-monitor/online-counter'),
      //Uri.parse('${config.baseUrl}/internet/inetstat_monitor.lua?sid=$sid&useajax=1'),
      //Uri.parse('${config.baseUrl}/internet/inetstat_monitor.lua?sid=$sid'),
    ];

    return null;
  }

  Future<List<WifiClient>> listWifiClients() async {
    await ensureSession();
    final sid = _client.sessionId;
    if (sid == null || sid.isEmpty) {
      return const [];
    }
    final url = Uri.parse('${config.baseUrl}/data.lua');
    final response = await _client.post(url, body: {'sid': sid, 'xhrId': 'all', 'xhr': '1', 'page': 'netDev'});

    final parsed = _tryDecodeJson(response.body);
    if (parsed == null) {
      return const [];
    }

    final data = parsed['data'];
    if (data is! Map<String, dynamic>) {
      return const [];
    }

    final lists = <List<dynamic>>[
      if (data['active'] is List) data['active'] as List<dynamic>,
      if (data['passive'] is List) data['passive'] as List<dynamic>,
      if (data['anmd'] is List) data['anmd'] as List<dynamic>,
    ];

    final clients = <WifiClient>[];
    for (final list in lists) {
      for (final entry in list.whereType<Map<String, dynamic>>()) {
        final name =
            entry['name']?.toString() ??
            entry['details']?['name']?.toString() ??
            entry['ip']?.toString() ??
            'Unknown device';
        clients.add(
          WifiClient(
            name: name,
            ip: entry['ip']?.toString() ?? entry['ipv4']?.toString(),
            mac: entry['mac']?.toString() ?? entry['wlanMAC']?.toString(),
            connectionType: entry['type']?.toString() ?? entry['connectionType']?.toString(),
            isOnline: entry['active'] == true || entry['isActive'] == true,
          ),
        );
      }
    }
    return clients;
  }

  Future<List<_FritzDeviceHandle>> _loadDevices() async {
    await ensureSession();
    final sid = _client.sessionId;
    if (sid == null || sid.isEmpty) {
      return const [];
    }
    final url = Uri.parse('${config.baseUrl}/data.lua');
    final response = await _client.post(url, body: {'sid': sid, 'xhrId': 'all', 'xhr': '1', 'page': 'sh_dev'});
    final parsed = _tryDecodeJson(response.body);
    if (parsed == null) {
      return const [];
    }
    final devices = (parsed['data']?['devices'] as List?) ?? [];
    return devices.whereType<Map<String, dynamic>>().map(_FritzDeviceHandle.fromJson).nonNulls.toList();
  }

  int? _parseFritzId(String smartDeviceId) {
    final rawId = smartDeviceId.contains(':') ? smartDeviceId.split(':').last : smartDeviceId;
    return int.tryParse(rawId);
  }

  Map<String, dynamic>? _tryDecodeJson(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _httpClient.close();
  }
}

class _FritzDeviceHandle {
  _FritzDeviceHandle({
    required this.deviceId,
    required this.name,
    required this.model,
    required this.type,
    required this.capabilities,
    this.temperatureCelsius,
    this.humidityPercent,
    this.powerW,
    required this.rawJson,
  });

  final int deviceId;
  final String name;
  final String model;
  final SmartDeviceType type;
  final Set<DeviceCapability> capabilities;
  final double? temperatureCelsius;
  final double? humidityPercent;
  final double? powerW;
  final Map<String, dynamic> rawJson;

  SmartDevice toSmartDevice() {
    return SmartDevice(
      id: 'fritz:$deviceId',
      name: name,
      vendor: SmartDeviceVendor.fritz,
      type: type,
      capabilities: capabilities,
      metadata: {'model': model, 'deviceId': deviceId},
    );
  }

  static _FritzDeviceHandle? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! int && id is! num) {
      return null;
    }
    final deviceId = id is int ? id : (id as num).toInt();
    final model = json['model']?.toString() ?? json['device']?['model']?.toString() ?? '';
    final name = json['displayName']?.toString() ?? model;
    final category = json['category']?.toString();

    final units =
        (json['units'] as List?)?.whereType<Map<String, dynamic>>() ?? const Iterable<Map<String, dynamic>>.empty();
    final skills = units
        .expand(
          (unit) =>
              (unit['skills'] as List?)?.whereType<Map<String, dynamic>>() ??
              const Iterable<Map<String, dynamic>>.empty(),
        )
        .toList();

    final temperature = _extractNumber(skills, const ['currentInCelsius', 'temperature', 'celsius']);
    final humidity = _extractNumber(skills, const [
      'humidity',
      'currentRelativeHumidity',
      'currentInPercent',
      'relativeHumidity',
    ]);
    final power = _extractNumber(skills, const ['powerConsumptionInWatt', 'power', 'power_per_hour']);

    final capabilities = <DeviceCapability>{};
    SmartDeviceType type = SmartDeviceType.fritzDect200;

    if (category == 'THERMOSTAT' || model.contains('440')) {
      type = SmartDeviceType.fritzSmartControl440;
      if (temperature != null) {
        capabilities.add(DeviceCapability.temperature);
      }
      if (humidity != null) {
        capabilities.add(DeviceCapability.humidity);
      }
    } else {
      type = SmartDeviceType.fritzDect200;
      capabilities.add(DeviceCapability.energy);
      if (temperature != null) {
        capabilities.add(DeviceCapability.temperature);
      }
    }

    return _FritzDeviceHandle(
      deviceId: deviceId,
      name: name,
      model: model,
      type: type,
      capabilities: capabilities,
      temperatureCelsius: temperature,
      humidityPercent: humidity,
      powerW: power,
      rawJson: json,
    );
  }
}

class _HttpFritzApiClient extends FritzApiClient {
  _HttpFritzApiClient({required super.baseUrl, required http.Client client}) : _client = client;

  final http.Client _client;

  @override
  Future<EnergyStats?> getEnergyStats({required HomeAutoQueryCommand command, required int deviceId}) async {
    assert(sessionId != null && sessionId!.isNotEmpty, 'SessionId must not be null or empty');

    final url = Uri.parse(
      '$baseUrl/net/home_auto_query.lua?sid=${sessionId!}&command=${command.name}&id=$deviceId&xhr=1',
    );
    final response = await get(url, headers: {});
    final rawBody = response.body;
    final decoded = jsonDecode(rawBody);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final normalized = _coerceNumericStrings(decoded);
    try {
      return EnergyStats.fromJson(normalized);
    } catch (error, stack) {
      Error.throwWithStackTrace(
        StateError('Failed to parse energy stats for device $deviceId: $error\nPayload: $normalized'),
        stack,
      );
    }
  }

  @override
  Future<FritzApiResponse> get(Uri url, {Map<String, String>? headers}) async {
    final response = await _client.get(url, headers: headers);
    final body = utf8.decode(response.bodyBytes);
    return FritzApiResponse(statusCode: response.statusCode, body: body);
  }

  @override
  Future<FritzApiResponse> post(Uri url, {Map<String, String>? headers, required Map<String, String> body}) async {
    final response = await _client.post(url, headers: headers, body: body);
    final responseBody = utf8.decode(response.bodyBytes);
    return FritzApiResponse(statusCode: response.statusCode, body: responseBody);
  }
}

Map<String, dynamic> _coerceNumericStrings(Map<String, dynamic> input) {
  final output = Map<String, dynamic>.from(input);

  void parseIntKey(String key) {
    final value = output[key];
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        output[key] = parsed;
      }
    }
  }

  parseIntKey('sum_Month');
  parseIntKey('sum_Year');
  parseIntKey('sum_Day');

  if (output['EnergyStat'] is Map<String, dynamic>) {
    final energyStat = Map<String, dynamic>.from(output['EnergyStat'] as Map<String, dynamic>);
    void parseEnergyInt(String key) {
      final value = energyStat[key];
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          energyStat[key] = parsed;
        }
      }
    }

    parseEnergyInt('ebene');
    parseEnergyInt('anzahl');
    parseEnergyInt('times_type');
    if (energyStat['values'] is List) {
      energyStat['values'] = (energyStat['values'] as List).map((v) => v is String ? int.tryParse(v) ?? v : v).toList();
    }
    output['EnergyStat'] = energyStat;
  }

  return output;
}

double? _extractNumber(List<Map<String, dynamic>> maps, List<String> keys) {
  for (final map in maps) {
    for (final key in keys) {
      final value = map[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
      if (value is Map) {
        for (final nested in value.values) {
          if (nested is num) {
            return nested.toDouble();
          }
          if (nested is String) {
            final parsed = double.tryParse(nested);
            if (parsed != null) {
              return parsed;
            }
          }
        }
      }
      if (value is List) {
        final numEntry = value.whereType<num>().firstOrNull;
        if (numEntry != null) {
          return numEntry.toDouble();
        }
      }
    }
  }
  return null;
}

OnlineCount? _extractNetworkTotals(Map<String, dynamic> json) {
  final totals = <String, int>{};
  void walk(dynamic value) {
    if (value is Map<String, dynamic>) {
      value.forEach((key, child) {
        final lower = key.toLowerCase();
        if (child is num &&
            (lower.contains('bytes_sent') ||
                lower.contains('bytesrcvd') ||
                lower.contains('bytes_received') ||
                lower == 'sum_bytes')) {
          totals[lower] = child.toInt();
        } else {
          walk(child);
        }
      });
    } else if (value is Iterable) {
      for (final child in value) {
        walk(child);
      }
    }
  }

  walk(json);
  final sent = totals.entries.firstWhereOrNull((e) => e.key.contains('sent'))?.value ?? 0;
  final received =
      totals.entries.firstWhereOrNull((e) => e.key.contains('rcvd') || e.key.contains('received'))?.value ?? 0;
  final total =
      totals.entries.firstWhereOrNull((e) => e.key.contains('sum') || e.key.contains('total'))?.value ??
      (sent + received);
  if (total == 0 && sent == 0 && received == 0) {
    return null;
  }
  return OnlineCount(totalBytes: total, bytesSent: sent, bytesReceived: received, raw: json);
}
