import type { HistoryEntry, Battery } from "../types";

export interface NestedGroup {
  id: string;
  label: string;
  ins: number;
  outs: number;
  battery?: Battery;
  entries: HistoryEntry[];
  subgroups: NestedGroup[];
  type: 'brand' | 'model' | 'year' | 'month' | 'day';
}

export class HistoryAnalysis {
  static buildHierarchy(entries: HistoryEntry[], batteries: Battery[], topLevel: 'brand' | 'model'): NestedGroup[] {
    const batteryMap: Record<string, Battery> = {};
    batteries.forEach(b => { batteryMap[b.id] = b; });

    // 1. Group by Top Level (Brand or Model)
    const topGroups: Record<string, { entries: HistoryEntry[], battery?: Battery }> = {};
    
    entries.forEach(entry => {
      const battery = batteryMap[entry.batteryId];
      let key = "";
      if (topLevel === 'brand') {
        key = battery?.brand || entry.batteryName.split(' ')[0] || 'Desconhecido';
      } else {
        key = entry.batteryId; // Group by ID to be safe, label will be name
      }

      if (!topGroups[key]) {
        topGroups[key] = { entries: [], battery };
      }
      topGroups[key].entries.push(entry);
    });

    return Object.entries(topGroups).map(([key, value]) => {
      const label = topLevel === 'model' 
        ? (value.battery?.name || value.entries[0].batteryName)
        : key;
        
      const group: NestedGroup = {
        id: `top_${key}`,
        label,
        battery: value.battery,
        entries: value.entries,
        type: topLevel,
        ins: 0, outs: 0,
        subgroups: this._groupByYear(value.entries, batteries)
      };
      
      // Calculate totals from entries
      value.entries.forEach(e => {
        if (e.type === 'in') group.ins += e.quantity;
        else group.outs += e.quantity;
      });

      return group;
    }).sort((a, b) => a.label.localeCompare(b.label));
  }

  private static _groupByYear(entries: HistoryEntry[], batteries: Battery[]): NestedGroup[] {
    const years: Record<string, HistoryEntry[]> = {};
    entries.forEach(e => {
      const date = e.timestamp?.toDate ? e.timestamp.toDate() : new Date(e.timestamp);
      const year = date.getFullYear().toString();
      if (!years[year]) years[year] = [];
      years[year].push(e);
    });

    return Object.entries(years).map(([year, yearEntries]) => {
      const group: NestedGroup = {
        id: `year_${year}_${Math.random()}`,
        label: year,
        type: 'year',
        ins: 0, outs: 0,
        entries: yearEntries,
        subgroups: this._groupByMonth(yearEntries)
      };
      yearEntries.forEach(e => {
        if (e.type === 'in') group.ins += e.quantity;
        else group.outs += e.quantity;
      });
      return group;
    }).sort((a, b) => b.label.localeCompare(a.label));
  }

  private static _groupByMonth(entries: HistoryEntry[]): NestedGroup[] {
    const months: Record<string, { name: string, entries: HistoryEntry[], sortKey: number }> = {};
    entries.forEach(e => {
      const date = e.timestamp?.toDate ? e.timestamp.toDate() : new Date(e.timestamp);
      const monthNum = date.getMonth();
      const monthName = date.toLocaleDateString('pt-BR', { month: 'long' });
      if (!months[monthName]) {
        months[monthName] = { name: monthName, entries: [], sortKey: monthNum };
      }
      months[monthName].entries.push(e);
    });

    return Object.values(months).map(m => {
      const group: NestedGroup = {
        id: `month_${m.name}_${Math.random()}`,
        label: m.name.charAt(0).toUpperCase() + m.name.slice(1),
        type: 'month',
        ins: 0, outs: 0,
        entries: m.entries,
        subgroups: [] // We stop at month for now, entries will be shown in table
      };
      m.entries.forEach(e => {
        if (e.type === 'in') group.ins += e.quantity;
        else group.outs += e.quantity;
      });
      return group;
    }).sort((a, b) => {
        const monthsOrder = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'];
        return monthsOrder.indexOf(b.label.toLowerCase()) - monthsOrder.indexOf(a.label.toLowerCase());
    });
  }
}
