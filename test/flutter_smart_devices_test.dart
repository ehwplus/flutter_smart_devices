import 'dart:convert';

import 'package:flutter_smart_devices/flutter_smart_devices.dart';
import 'package:flutter_smart_devices/src/adapters/fritz_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('FritzBoxAdapter', () {
    late FritzBoxAdapter adapter;
    late MockClient client;

    setUp(() {
      client = MockClient((request) async {
        if (request.url.path.endsWith('/login_sid.lua') && request.method == 'GET') {
          const xml = '<SessionInfo><SID>0000000000000000</SID><Challenge>1234</Challenge><BlockTime>0</BlockTime><Rights/><Users><User>demo</User></Users></SessionInfo>';
          return http.Response(xml, 200);
        }
        if (request.url.path.endsWith('/login_sid.lua') && request.method == 'POST') {
          const xml = '<SessionInfo><SID>1111111111111111</SID><Challenge>1234</Challenge><BlockTime>0</BlockTime><Rights/><Users><User>demo</User></Users></SessionInfo>';
          return http.Response(xml, 200);
        }
        if (request.url.path.endsWith('/data.lua')) {
          final body = Uri.splitQueryString(request.body);
          if (body['page'] == 'sh_dev') {
            final payload = {
              'data': {
                'devices': [
                  {
                    'id': 17,
                    'displayName': 'Kuehlschrank',
                    'category': 'SOCKET',
                    'model': 'FRITZ!DECT 200',
                    'units': [
                      {
                        'skills': [
                          {'type': 'SmartHomeMultimeter', 'powerConsumptionInWatt': 42.0},
                          {'type': 'SmartHomeTemperatureSensor', 'currentInCelsius': 23.5}
                        ]
                      }
                    ],
                  },
                  {
                    'id': 18,
                    'displayName': 'Bad Sensor',
                    'category': 'THERMOSTAT',
                    'model': 'FRITZ!DECT 440',
                    'units': [
                      {
                        'skills': [
                          {'type': 'SmartHomeTemperatureSensor', 'currentInCelsius': 21.0},
                          {'type': 'SmartHomeHumiditySensor', 'currentRelativeHumidity': 47}
                        ]
                      }
                    ],
                  }
                ]
              },
              'sid': '1111111111111111',
            };
            return http.Response(jsonEncode(payload), 200);
          }
          if (body['page'] == 'netDev') {
            final payload = {
              'data': {
                'active': [
                  {'name': 'Laptop', 'mac': '00:11:22:33:44:55', 'ip': '192.168.178.20', 'active': true},
                ]
              }
            };
            return http.Response(jsonEncode(payload), 200);
          }
        }
        if (request.url.path.endsWith('/net/home_auto_query.lua')) {
          final payload = {
            'sum_Month': 1200,
            'sum_Year': 15000,
            'sum_Day': 120,
            'DeviceConnectState': '2',
            'DeviceID': '17',
            'DeviceSwitchState': '1',
            'tabType': '24h',
            'CurrentDateInSec': '1672093500',
            'RequestResult': true,
            'EnergyStat': {
              'ebene': 0,
              'anzahl': 1,
              'times_type': 1,
              'values': [1]
            }
          };
          return http.Response(jsonEncode(payload), 200);
        }
        if (request.url.path.endsWith('/internet/inetstat_monitor.lua')) {
          final payload = {
            'traffic': {
              'bytes_sent': 1024,
              'bytes_rcvd': 2048,
              'sum_bytes': 3072,
            }
          };
          return http.Response(jsonEncode(payload), 200);
        }
        return http.Response('Not Found', 404);
      });

      adapter = FritzBoxAdapter(
        const FritzBoxConfig(
          baseUrl: 'http://fritz.box',
          password: 'secret',
          username: 'demo',
        ),
        httpClient: client,
      );
    });

    test('discovers devices with capabilities', () async {
      final devices = await adapter.discoverDevices();
      expect(devices.length, 3); // Fritz!Box pseudo device + two real devices

      final plug = devices.firstWhere((d) => d.id == 'fritz:17');
      expect(plug.capabilities.contains(DeviceCapability.energy), isTrue);
      final sensor = devices.firstWhere((d) => d.id == 'fritz:18');
      expect(sensor.capabilities.contains(DeviceCapability.humidity), isTrue);
    });

    test('reads energy stats and environment data', () async {
      await adapter.discoverDevices();
      final energy = await adapter.readEnergy('fritz:17');
      expect(energy?.todayWh, 120);
      final environment = await adapter.readEnvironment('fritz:18');
      expect(environment?.temperatureCelsius, 21.0);
      expect(environment?.humidityPercent, 47);
      final counters = await adapter.readNetworkCounters();
      expect(counters?.totalBytes, 3072);
      final clients = await adapter.listWifiClients();
      expect(clients.first.name, 'Laptop');
    });
  });
}
