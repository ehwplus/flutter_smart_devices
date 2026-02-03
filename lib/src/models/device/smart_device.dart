import 'package:flutter_smart_devices/src/models/capability/device_capability.dart';
import 'package:flutter_smart_devices/src/models/device/smart_device_type.dart';
import 'package:flutter_smart_devices/src/models/device/smart_device_vendor.dart';
import 'package:meta/meta.dart';

@immutable
class SmartDevice {
  const SmartDevice({
    required this.id,
    required this.name,
    required this.vendor,
    required this.type,
    required this.capabilities,
    this.metadata = const {},
  });

  final String id;
  final String name;
  final SmartDeviceVendor vendor;
  final SmartDeviceType type;
  final Set<DeviceCapability> capabilities;
  final Map<String, Object?> metadata;

  SmartDevice copyWith({String? name, Set<DeviceCapability>? capabilities, Map<String, Object?>? metadata}) {
    return SmartDevice(
      id: id,
      name: name ?? this.name,
      vendor: vendor,
      type: type,
      capabilities: capabilities ?? this.capabilities,
      metadata: metadata ?? this.metadata,
    );
  }
}
