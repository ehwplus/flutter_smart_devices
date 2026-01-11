# flutter_smart_devices

Unified access layer for TP-Link Tapo plugs and FRITZ! smart home gear. The package wraps
[flutter_tapo](https://github.com/ehwplus/flutter_tapo) and
[flutter_fritzapi](https://github.com/ehwplus/flutter_fritzapi) so Flutter apps can configure
devices once and read their data through a single API.

## Supported devices

- TP-Link Tapo P100 / P115: energy readings
- FRITZ!DECT 200: energy readings, temperature (if exposed by the box)

## Planned devices

- FRITZ!Smart Control 440: temperature and humidity
- FRITZ!Box: network counters (traffic) and Wi-Fi clients (useful for device discovery)

## Getting started

1. Add the dependency (Git based):
   ```yaml
   dependencies:
     flutter_smart_devices:
       git:
         url: https://github.com/ehwplus/flutter_smart_devices.git
   ```
   The repository contains `dependency_overrides` pointing to `third_party/` for local development.
2. Run `flutter pub get`.

## Usage

```dart
import 'package:flutter_smart_devices/flutter_smart_devices.dart';

final hub = SmartDevicesHub();

// TP-Link Tapo plug
final tapo = await hub.addTapoPlug(
  TapoDeviceConfig(
    host: '192.168.178.40',
    email: 'you@example.com',
    password: 'tapo-password',
    model: SmartDeviceType.tapoP115,
  ),
);
final tapoEnergy = await hub.readEnergy(tapo.id);

// FRITZ!Box and Smart Home devices
await hub.configureFritzBox(
  const FritzBoxConfig(
    baseUrl: 'http://fritz.box',
    username: 'fritz-user', // optional
    password: 'fritz-password',
  ),
);
final devices = await hub.listDevices(); // includes FRITZ!Box pseudo device
final energy = await hub.readEnergy('fritz:17'); // FRITZ!DECT 200
final climate = await hub.readEnvironment('fritz:18'); // FRITZ!Smart Control 440
final counters = await hub.readNetworkCounters();
final wifiClients = await hub.listWifiClients();
```

`SmartDevice` instances expose their capabilities so you can decide which readings to request.
Energy data is normalized to Wh (day/month where available).

## Example app

Run the included demo to configure devices and test calls:

```
cd example
flutter run
```

The app lets you enter Tapo credentials, connect to the FRITZ!Box, discover devices, and fetch
energy/temperature/humidity/network data directly from the UI.
