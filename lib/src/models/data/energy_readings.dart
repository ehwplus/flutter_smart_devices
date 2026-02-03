import 'package:flutter/material.dart';

class EnergyReadings {
  const EnergyReadings({required this.entries, required this.intervalType});

  final EnergyReadingIntervalType intervalType;

  final List<EnergyReading> entries;
}

class EnergyReading {
  const EnergyReading({this.value, required this.dateTimeFrom, required this.dateTimeTo, this.raw});

  final double? value;

  /// Iso formatted start date from
  final String dateTimeFrom;

  /// Iso formatted end date to
  final String dateTimeTo;

  final Object? raw;

  DateTimeRange get interval => DateTimeRange(start: DateTime.parse(dateTimeFrom), end: DateTime.parse(dateTimeTo));
}

enum EnergyReadingIntervalType {
  // 15 min interval
  fifteenMinutes,
  // hourly interval
  hourly,
  // interval for one activity, usually from some minutes to some hours
  activity,
  // 24 hours interval
  daily,
  // 7 days interval
  weekly,
  // 30 days interval
  monthly,
  // year interval
  yearly,
}
