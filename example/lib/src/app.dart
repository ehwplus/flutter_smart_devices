import 'package:flutter/material.dart';
import 'package:flutter_smart_devices_example/src/demo_page.dart';

class SmartDevicesExampleApp extends StatelessWidget {
  const SmartDevicesExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Devices Demo',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const SmartDevicesDemoPage(),
    );
  }
}
