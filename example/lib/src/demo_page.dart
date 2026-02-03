import 'package:flutter/material.dart';
import 'package:flutter_smart_devices/flutter_smart_devices.dart';

class SmartDevicesDemoPage extends StatefulWidget {
  const SmartDevicesDemoPage({super.key});

  @override
  State<SmartDevicesDemoPage> createState() => _SmartDevicesDemoPageState();
}

class _SmartDevicesDemoPageState extends State<SmartDevicesDemoPage> {
  final hub = SmartDevicesHub();

  final tapoHostController = TextEditingController();
  final tapoEmailController = TextEditingController();
  final tapoPasswordController = TextEditingController();
  final tapoStartDateController = TextEditingController();
  final tapoEndDateController = TextEditingController();
  SmartDeviceType tapoModel = SmartDeviceType.tapoP115;
  EnergyReport? tapoEnergy;
  EnergyReadings? tapoEnergyReadings;
  SmartDevice? tapoDevice;
  EnergyReadingIntervalType tapoReadingInterval = EnergyReadingIntervalType.hourly;
  bool tapoBusy = false;

  final fritzBaseUrlController = TextEditingController(text: 'http://fritz.box');
  final fritzUserController = TextEditingController();
  final fritzPasswordController = TextEditingController();
  bool fritzBusy = false;
  List<SmartDevice> fritzDevices = [];
  Map<String, SmartDeviceReading> readings = {};
  OnlineCount? counters;
  List<WifiClient> wifiClients = [];
  String? fritzError;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    tapoStartDateController.text = _formatDateTime(now.subtract(const Duration(days: 1)), withTime: true);
    tapoEndDateController.text = _formatDateTime(now, withTime: true);
  }

  @override
  void dispose() {
    tapoHostController.dispose();
    tapoEmailController.dispose();
    tapoPasswordController.dispose();
    tapoStartDateController.dispose();
    tapoEndDateController.dispose();
    fritzBaseUrlController.dispose();
    fritzUserController.dispose();
    fritzPasswordController.dispose();
    hub.dispose();
    super.dispose();
  }

  Future<void> _addTapoPlug() async {
    if (tapoHostController.text.isEmpty || tapoEmailController.text.isEmpty || tapoPasswordController.text.isEmpty) {
      _showMessage('Please provide host, email and password for Tapo.');
      return;
    }
    setState(() {
      tapoBusy = true;
      tapoEnergy = null;
      tapoEnergyReadings = null;
    });
    try {
      final device = await hub.addTapoPlug(
        TapoDeviceConfig(
          host: tapoHostController.text.trim(),
          email: tapoEmailController.text.trim(),
          password: tapoPasswordController.text,
          model: tapoModel,
        ),
      );
      tapoDevice = device;
      tapoEnergy = await hub.readEnergyReport(device.id);
    } catch (error) {
      _showMessage('Failed to read Tapo plug: $error');
    } finally {
      if (mounted) {
        setState(() {
          tapoBusy = false;
        });
      }
    }
  }

  Future<void> _loadTapoReadings() async {
    final device = tapoDevice;
    if (device == null) {
      _showMessage('Please add a Tapo plug first.');
      return;
    }

    final start = _parseDateTime(tapoStartDateController.text, label: 'Start date');
    if (start == null) {
      return;
    }

    DateTime? end;
    if (tapoReadingInterval == EnergyReadingIntervalType.hourly ||
        tapoReadingInterval == EnergyReadingIntervalType.activity) {
      end = _parseDateTime(tapoEndDateController.text, label: 'End date');
      if (end == null) {
        return;
      }
    } else if (tapoEndDateController.text.trim().isNotEmpty) {
      end = _parseDateTime(tapoEndDateController.text, label: 'End date');
      if (end == null) {
        return;
      }
    }

    setState(() {
      tapoBusy = true;
      tapoEnergyReadings = null;
    });
    try {
      final readings = await hub.readEnergyReadings(
        device.id,
        intervalType: tapoReadingInterval,
        startDate: start,
        endDate: end,
      );
      setState(() {
        tapoEnergyReadings = readings;
      });
    } catch (error) {
      _showMessage('Failed to read Tapo energy readings: $error');
    } finally {
      if (mounted) {
        setState(() {
          tapoBusy = false;
        });
      }
    }
  }

  Future<void> _connectFritz() async {
    if (fritzPasswordController.text.isEmpty) {
      _showMessage('Please provide a FRITZ!Box password.');
      return;
    }
    setState(() {
      fritzBusy = true;
      fritzError = null;
      readings = {};
    });
    try {
      await hub.configureFritzBox(
        FritzBoxConfig(
          baseUrl: fritzBaseUrlController.text.trim(),
          username: fritzUserController.text.trim().isEmpty ? null : fritzUserController.text.trim(),
          password: fritzPasswordController.text,
        ),
      );
      fritzDevices = await hub.listDevices();
    } catch (error) {
      fritzError = 'Failed to connect to FRITZ!Box: $error';
    } finally {
      if (mounted) {
        setState(() {
          fritzBusy = false;
        });
      }
    }
  }

  Future<void> _refreshDevice(SmartDevice device) async {
    setState(() {
      fritzBusy = true;
    });
    try {
      final reading = await hub.readDevice(device.id);
      setState(() {
        readings[device.id] = reading;
      });
    } catch (error) {
      final message = 'Failed to read ${device.name}: $error';
      _showMessage(message);
      print(message);
    } finally {
      if (mounted) {
        setState(() {
          fritzBusy = false;
        });
      }
    }
  }

  Future<void> _loadNetworkCounters() async {
    setState(() {
      fritzBusy = true;
    });
    try {
      final result = await hub.readOnlineCount();
      setState(() {
        counters = result;
      });
    } catch (error) {
      _showMessage('Failed to read network counters: $error');
    } finally {
      if (mounted) {
        setState(() {
          fritzBusy = false;
        });
      }
    }
  }

  Future<void> _loadWifiClients() async {
    setState(() {
      fritzBusy = true;
    });
    try {
      final clients = await hub.listWifiClients();
      setState(() {
        wifiClients = clients;
      });
    } catch (error) {
      _showMessage('Failed to read Wi-Fi clients: $error');
    } finally {
      if (mounted) {
        setState(() {
          fritzBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Devices Demo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connect TP-Link Tapo plugs and FRITZ! devices with a unified API.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            _buildTapoCard(),
            const SizedBox(height: 16),
            _buildFritzCard(),
            const SizedBox(height: 16),
            _buildFritzDevices(),
            const SizedBox(height: 16),
            _buildFritzBoxData(),
          ],
        ),
      ),
    );
  }

  Widget _buildTapoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TP-Link Tapo', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: tapoHostController,
              decoration: const InputDecoration(labelText: 'Device IP/host'),
            ),
            TextField(
              controller: tapoEmailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: tapoPasswordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            DropdownButton<SmartDeviceType>(
              value: tapoModel,
              items: const [
                DropdownMenuItem(value: SmartDeviceType.tapoP115, child: Text('Tapo P115')),
                DropdownMenuItem(value: SmartDeviceType.tapoP100, child: Text('Tapo P100')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    tapoModel = value;
                  });
                }
              },
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: tapoBusy ? null : _addTapoPlug,
              icon: tapoBusy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.power),
              label: const Text('Add plug and fetch energy'),
            ),
            if (tapoEnergy != null) ...[
              const SizedBox(height: 8),
              Text('Today: ${tapoEnergy?.todayWh?.toStringAsFixed(1)} Wh'),
              Text('Month: ${tapoEnergy?.monthWh?.toStringAsFixed(1)} Wh'),
            ],
            const Divider(height: 24),
            Text('Energy readings', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButton<EnergyReadingIntervalType>(
              value: tapoReadingInterval,
              items: const [
                DropdownMenuItem(value: EnergyReadingIntervalType.hourly, child: Text('Hourly')),
                DropdownMenuItem(value: EnergyReadingIntervalType.activity, child: Text('Activity')),
                DropdownMenuItem(value: EnergyReadingIntervalType.daily, child: Text('Daily (quarter)')),
                DropdownMenuItem(value: EnergyReadingIntervalType.monthly, child: Text('Monthly (year)')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    tapoReadingInterval = value;
                  });
                }
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: tapoStartDateController,
              decoration: const InputDecoration(
                labelText: 'Start date (ISO)',
                helperText: 'Example: 2026-02-01 or 2026-02-01T12:00',
              ),
            ),
            TextField(
              controller: tapoEndDateController,
              decoration: const InputDecoration(
                labelText: 'End date (ISO)',
                helperText: 'Required for hourly/activity. Optional otherwise.',
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: tapoBusy ? null : _loadTapoReadings,
              icon: tapoBusy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.query_stats),
              label: const Text('Fetch energy readings'),
            ),
            if (tapoEnergyReadings != null) ...[
              const SizedBox(height: 8),
              Text(
                'Entries: ${tapoEnergyReadings!.entries.length} '
                '(${tapoEnergyReadings!.intervalType.name})',
              ),
              if (tapoEnergyReadings!.entries.isNotEmpty) ...[
                Text(
                  'First: ${tapoEnergyReadings!.entries.first.dateTimeFrom} '
                  '→ ${tapoEnergyReadings!.entries.first.dateTimeTo} '
                  '(${tapoEnergyReadings!.entries.first.value?.toStringAsFixed(1) ?? '-' } Wh)',
                ),
                Text(
                  'Last: ${tapoEnergyReadings!.entries.last.dateTimeFrom} '
                  '→ ${tapoEnergyReadings!.entries.last.dateTimeTo} '
                  '(${tapoEnergyReadings!.entries.last.value?.toStringAsFixed(1) ?? '-' } Wh)',
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFritzCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('FRITZ!Box', style: Theme.of(context).textTheme.titleMedium),
                if (fritzBusy) const CircularProgressIndicator(strokeWidth: 2),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: fritzBaseUrlController,
              decoration: const InputDecoration(labelText: 'Base URL'),
            ),
            TextField(
              controller: fritzUserController,
              decoration: const InputDecoration(labelText: 'User (optional)'),
            ),
            TextField(
              controller: fritzPasswordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: fritzBusy ? null : _connectFritz,
              child: const Text('Connect and discover devices'),
            ),
            if (fritzError != null) ...[
              const SizedBox(height: 8),
              Text(fritzError!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFritzDevices() {
    if (fritzDevices.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Discovered devices', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final device in fritzDevices.where((d) => d.vendor == SmartDeviceVendor.fritz && d.id != 'fritz:box'))
              ListTile(
                title: Text(device.name),
                subtitle: Text('${device.type.name} · ${device.capabilities.map((c) => c.name).join(', ')}'),
                trailing: ElevatedButton(
                  onPressed: fritzBusy ? null : () => _refreshDevice(device),
                  child: const Text('Read'),
                ),
              ),
            if (readings.isNotEmpty) _buildReadings(),
          ],
        ),
      ),
    );
  }

  Widget _buildReadings() {
    final entries = readings.entries.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const Text('Latest readings'),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${entry.key}: '
              'temp=${entry.value.environment?.temperatureCelsius?.toStringAsFixed(1) ?? '-'} C, '
              'humidity=${entry.value.environment?.humidityPercent?.toStringAsFixed(0) ?? '-'} %, '
              'today=${entry.value.energyReport?.todayWh?.toStringAsFixed(1) ?? '-'} Wh',
            ),
          ),
      ],
    );
  }

  Widget _buildFritzBoxData() {
    if (!fritzDevices.any((d) => d.id == 'fritz:box' && d.vendor == SmartDeviceVendor.fritz)) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('FRITZ!Box data', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: fritzBusy ? null : _loadNetworkCounters,
                  child: const Text('Read online counters'),
                ),
                ElevatedButton(onPressed: fritzBusy ? null : _loadWifiClients, child: const Text('List Wi-Fi clients')),
              ],
            ),
            if (counters != null) ...[
              const SizedBox(height: 8),
              Text('Traffic total: ${counters!.totalBytes} bytes'),
              Text('Sent: ${counters!.bytesSent} bytes'),
              Text('Received: ${counters!.bytesReceived} bytes'),
            ],
            if (wifiClients.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Wi-Fi clients:'),
              for (final client in wifiClients) Text('- ${client.name} (${client.ip ?? 'unknown ip'})'),
            ],
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDateTime(DateTime date, {required bool withTime}) {
    final iso = date.toIso8601String();
    if (withTime) {
      return iso.substring(0, 16);
    }
    return iso.substring(0, 10);
  }

  DateTime? _parseDateTime(String raw, {required String label}) {
    final value = raw.trim();
    if (value.isEmpty) {
      _showMessage('$label is required.');
      return null;
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) {
      _showMessage('$label is not a valid ISO date.');
    }
    return parsed;
  }
}
