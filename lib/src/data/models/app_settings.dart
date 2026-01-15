import 'package:flutter/foundation.dart';

@immutable
class AppSettings {
  final int gondolaCapacity;
  final bool showDiscontinuedBatteries;

  const AppSettings({
    this.gondolaCapacity = 20, // Default value from web app
    this.showDiscontinuedBatteries = false,
  });

  // fromJson
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      gondolaCapacity: json['gondolaCapacity'] as int? ?? 20,
      showDiscontinuedBatteries:
          json['showDiscontinuedBatteries'] as bool? ?? false,
    );
  }

  // toJson
  Map<String, dynamic> toJson() {
    return {
      'gondolaCapacity': gondolaCapacity,
      'showDiscontinuedBatteries': showDiscontinuedBatteries,
    };
  }

  // copyWith
  AppSettings copyWith({
    int? gondolaCapacity,
    bool? showDiscontinuedBatteries,
  }) {
    return AppSettings(
      gondolaCapacity: gondolaCapacity ?? this.gondolaCapacity,
      showDiscontinuedBatteries:
          showDiscontinuedBatteries ?? this.showDiscontinuedBatteries,
    );
  }
}
