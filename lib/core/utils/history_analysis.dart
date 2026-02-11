import 'package:bms/core/models/history_entry.dart';
import 'package:bms/core/models/battery.dart';
import 'package:intl/intl.dart';

enum GroupingType { model, brand, year, month }

class HierarchicalGroup {
  final String id;
  final String label;
  int ins;
  int outs;
  final Battery? battery;
  final List<HistoryEntry> entries;
  final List<HierarchicalGroup> subgroups;
  final GroupingType type;

  HierarchicalGroup({
    required this.id,
    required this.label,
    this.ins = 0,
    this.outs = 0,
    this.battery,
    required this.entries,
    required this.subgroups,
    required this.type,
  });
}

class HistoryAnalysis {
  static List<HierarchicalGroup> buildHierarchy(
    List<HistoryEntry> entries,
    List<Battery> batteries,
    GroupingType topLevel,
  ) {
    final Map<String, Battery> batteryMap = {
      for (var b in batteries) b.id: b,
    };

    // 1. Group by Top Level (Brand or Model)
    final Map<String, List<HistoryEntry>> topGroups = {};

    for (var entry in entries) {
      final battery = batteryMap[entry.batteryId];
      String key;
      if (topLevel == GroupingType.brand) {
        key = battery?.brand ?? entry.batteryName.split(' ')[0];
        if (key.isEmpty) key = 'Desconhecido';
      } else {
        key = entry.batteryId; // Group by ID, label will be name
      }

      if (!topGroups.containsKey(key)) {
        topGroups[key] = [];
      }
      topGroups[key]!.add(entry);
    }

    final results = topGroups.entries.map((e) {
      final key = e.key;
      final value = e.value;
      final battery = batteryMap[value[0].batteryId];

      final label = topLevel == GroupingType.model
          ? (battery?.name ?? value[0].batteryName)
          : key;

      final group = HierarchicalGroup(
        id: 'top_$key',
        label: label,
        battery: battery,
        entries: value,
        type: topLevel,
        subgroups: topLevel == GroupingType.brand
            ? _groupByModel(value, batteryMap)
            : _groupByYear(value),
      );

      // Calculate totals
      for (var entry in value) {
        if (entry.type == 'in') {
          group.ins += entry.quantity;
        } else {
          group.outs += entry.quantity;
        }
      }

      return group;
    }).toList();

    results.sort((a, b) => a.label.compareTo(b.label));
    return results;
  }

  static List<HierarchicalGroup> _groupByModel(
    List<HistoryEntry> entries,
    Map<String, Battery> batteryMap,
  ) {
    final Map<String, List<HistoryEntry>> models = {};
    for (var e in entries) {
      final id = e.batteryId;
      if (!models.containsKey(id)) models[id] = [];
      models[id]!.add(e);
    }

    final results = models.entries.map((e) {
      final id = e.key;
      final modelEntries = e.value;
      final battery = batteryMap[id];

      final group = HierarchicalGroup(
        id: 'model_$id',
        label: battery?.name ?? modelEntries[0].batteryName,
        type: GroupingType.model,
        battery: battery,
        entries: modelEntries,
        subgroups: _groupByYear(modelEntries),
      );

      for (var entry in modelEntries) {
        if (entry.type == 'in') {
          group.ins += entry.quantity;
        } else {
          group.outs += entry.quantity;
        }
      }
      return group;
    }).toList();

    results.sort((a, b) => a.label.compareTo(b.label));
    return results;
  }

  static List<HierarchicalGroup> _groupByYear(List<HistoryEntry> entries) {
    final Map<String, List<HistoryEntry>> years = {};
    for (var e in entries) {
      final year = e.timestamp.year.toString();
      if (!years.containsKey(year)) years[year] = [];
      years[year]!.add(e);
    }

    final results = years.entries.map((e) {
      final year = e.key;
      final yearEntries = e.value;

      final group = HierarchicalGroup(
        id: 'year_$year',
        label: year,
        type: GroupingType.year,
        entries: yearEntries,
        subgroups: _groupByMonth(yearEntries),
      );

      for (var entry in yearEntries) {
        if (entry.type == 'in') {
          group.ins += entry.quantity;
        } else {
          group.outs += entry.quantity;
        }
      }
      return group;
    }).toList();

    results.sort((a, b) => b.label.compareTo(a.label));
    return results;
  }

  static List<HierarchicalGroup> _groupByMonth(List<HistoryEntry> entries) {
    final Map<int, List<HistoryEntry>> months = {};
    for (var e in entries) {
      final month = e.timestamp.month;
      if (!months.containsKey(month)) months[month] = [];
      months[month]!.add(e);
    }

    final results = months.entries.map((e) {
      final monthNum = e.key;
      final monthEntries = e.value;
      final date = DateTime(monthEntries[0].timestamp.year, monthNum);
      final monthName = DateFormat('MMMM', 'pt_BR').format(date);

      final group = HierarchicalGroup(
        id: 'month_$monthName',
        label: monthName[0].toUpperCase() + monthName.substring(1),
        type: GroupingType.month,
        entries: monthEntries,
        subgroups: [], // Stop at month
      );

      for (var entry in monthEntries) {
        if (entry.type == 'in') {
          group.ins += entry.quantity;
        } else {
          group.outs += entry.quantity;
        }
      }
      return group;
    }).toList();

    results.sort((a, b) {
      // Sort by month number descending
      final monthA = months.keys.firstWhere((k) {
        final date = DateTime(2000, k);
        final name = DateFormat('MMMM', 'pt_BR').format(date);
        return (name[0].toUpperCase() + name.substring(1)) == a.label;
      }, orElse: () => 0);
      final monthB = months.keys.firstWhere((k) {
        final date = DateTime(2000, k);
        final name = DateFormat('MMMM', 'pt_BR').format(date);
        return (name[0].toUpperCase() + name.substring(1)) == b.label;
      }, orElse: () => 0);
      return monthB.compareTo(monthA);
    });

    return results;
  }
}
