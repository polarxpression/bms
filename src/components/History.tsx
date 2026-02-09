import { useEffect, useState, useMemo } from 'react';
import { batteryService } from '../services/batteryService';
import { HistoryAnalysis, type GroupingType } from '../utils/historyAnalysis';
import type { HistoryEntry, Battery } from '../types';

export const History = () => {
  const [history, setHistory] = useState<HistoryEntry[]>([]);
  const [batteries, setBatteries] = useState<Battery[]>([]);
  const [loading, setLoading] = useState(true);
  const [grouping, setGrouping] = useState<GroupingType>('day');
  const [startDate, setStartDate] = useState<string>('');
  const [endDate, setEndDate] = useState<string>('');
  const [searchQuery, setSearchQuery] = useState('');

  useEffect(() => {
    const load = async () => {
      try {
        const [historyData, batteryData] = await Promise.all([
            batteryService.fetchHistory(),
            batteryService.fetchBatteries()
        ]);
        setHistory(historyData);
        setBatteries(batteryData);

        // Check for search query in URL
        const params = new URLSearchParams(window.location.search);
        const q = params.get('q');
        if (q) setSearchQuery(q);

      } catch (err) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    };
    load();
  }, []);

  const filteredHistory = useMemo(() => {
    return history.filter(entry => {
        // Search Filter
        if (searchQuery) {
            const query = searchQuery.toLowerCase();
            const battery = batteries.find(b => b.id === entry.batteryId);
            const matchesBattery = battery && (
                (battery.name?.toLowerCase().includes(query)) ||
                (battery.barcode?.toLowerCase().includes(query)) ||
                (battery.brand?.toLowerCase().includes(query)) ||
                (battery.model?.toLowerCase().includes(query))
            );
            const matchesName = entry.batteryName.toLowerCase().includes(query);
            
            if (!matchesBattery && !matchesName) return false;
        } else {
            // Global Filter: Only show outs from map
            if (entry.type === 'out' && entry.source !== 'map') return false;
        }
        
        // Date filter
        if (startDate || endDate) {
            const ts = entry.timestamp?.toDate ? entry.timestamp.toDate() : new Date(entry.timestamp);
            if (startDate && ts < new Date(startDate)) return false;
            if (endDate) {
                const end = new Date(endDate);
                end.setHours(23, 59, 59, 999);
                if (ts > end) return false;
            }
        }
        return true;
    });
  }, [history, batteries, startDate, endDate, searchQuery]);

  const groupedData = useMemo(() => {
    if (searchQuery) return [];
    return HistoryAnalysis.group(filteredHistory, grouping);
  }, [filteredHistory, grouping, searchQuery]);

  if (loading) return (
    <div className="flex flex-col items-center justify-center py-20">
        <div className="w-12 h-12 border-4 border-[#EC4899]/20 border-t-[#EC4899] rounded-full animate-spin mb-4"></div>
        <p className="text-gray-500 font-bold animate-pulse">Analisando histórico...</p>
    </div>
  );

  return (
    <div className="space-y-8">
        <div className="bg-[#141414] p-6 rounded-3xl border border-white/5 shadow-xl space-y-4">
            <div className="w-full relative group">
                <span className="material-icons absolute left-4 top-1/2 -translate-y-1/2 text-gray-500 group-focus-within:text-[#EC4899] transition-colors">search</span>
                <input 
                    type="text"
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    placeholder="Filtrar por Bateria (Nome, Marca, Modelo ou EAN)"
                    className="w-full bg-black/40 text-white pl-12 pr-4 py-3 rounded-xl border border-white/10 focus:border-[#EC4899]/50 outline-none transition-all"
                />
                {searchQuery && (
                    <button 
                        onClick={() => setSearchQuery('')}
                        className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-500 hover:text-white"
                    >
                        <span className="material-icons text-sm">close</span>
                    </button>
                )}
            </div>

            <div className="flex flex-col lg:flex-row gap-4 items-end">
                <div className="flex-1 w-full">
                    <label className="block text-[10px] font-black text-gray-500 uppercase tracking-widest mb-2 ml-1">Agrupar por</label>
                    <select 
                        value={grouping}
                        onChange={(e) => setGrouping(e.target.value as GroupingType)}
                        disabled={!!searchQuery}
                        className="w-full bg-black/40 text-white p-3 rounded-xl border border-white/10 focus:border-[#EC4899]/50 outline-none transition-all disabled:opacity-30 disabled:cursor-not-allowed"
                    >
                        <option value="day">Dia</option>
                        <option value="month">Mês</option>
                        <option value="trimester">Trimestre</option>
                        <option value="semester">Semestre</option>
                        <option value="year">Ano</option>
                    </select>
                </div>
                <div className="flex-[2] w-full grid grid-cols-2 gap-3">
                    <div>
                        <label className="block text-[10px] font-black text-gray-500 uppercase tracking-widest mb-2 ml-1">De</label>
                        <input 
                            type="date" 
                            value={startDate}
                            onChange={(e) => setStartDate(e.target.value)}
                            className="w-full bg-black/40 text-white p-3 rounded-xl border border-white/10 focus:border-[#EC4899]/50 outline-none transition-all"
                        />
                    </div>
                    <div>
                        <label className="block text-[10px] font-black text-gray-500 uppercase tracking-widest mb-2 ml-1">Até</label>
                        <input 
                            type="date" 
                            value={endDate}
                            onChange={(e) => setEndDate(e.target.value)}
                            className="w-full bg-black/40 text-white p-3 rounded-xl border border-white/10 focus:border-[#EC4899]/50 outline-none transition-all"
                        />
                    </div>
                </div>
                <button 
                    onClick={() => { setStartDate(''); setEndDate(''); setSearchQuery(''); }}
                    className="px-6 py-3 bg-white/5 hover:bg-white/10 text-gray-400 hover:text-white rounded-xl transition-all font-bold text-sm whitespace-nowrap"
                >
                    Limpar Filtros
                </button>
            </div>
        </div>

        {!searchQuery ? (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {groupedData.map((group) => (
                    <div key={group.label} className="bg-[#141414] p-6 rounded-[2rem] border border-white/5 hover:border-white/10 transition-all group shadow-lg">
                        <div className="flex items-center justify-between mb-6">
                            <h3 className="text-lg font-black text-white tracking-tight">{group.label}</h3>
                            <div className="w-10 h-10 rounded-xl bg-white/5 flex items-center justify-center">
                                <span className="material-icons text-gray-600">calendar_today</span>
                            </div>
                        </div>

                        <div className="grid grid-cols-2 gap-4">
                            <div className="bg-green-500/[0.03] p-4 rounded-2xl border border-green-500/10 group-hover:bg-green-500/[0.05] transition-colors">
                                <p className="text-[10px] font-black text-green-500/60 uppercase tracking-widest mb-1">Entradas</p>
                                <p className="text-2xl font-black text-green-400">+{group.ins}</p>
                            </div>
                            <div className="bg-red-500/[0.03] p-4 rounded-2xl border border-red-500/10 group-hover:bg-red-500/[0.05] transition-colors">
                                <p className="text-[10px] font-black text-red-500/60 uppercase tracking-widest mb-1">Saídas</p>
                                <p className="text-2xl font-black text-red-400">-{group.outs}</p>
                            </div>
                        </div>
                    </div>
                ))}
            </div>
        ) : (
            <div className="bg-[#141414] rounded-3xl border border-white/5 overflow-hidden">
                <div className="overflow-x-auto">
                    <table className="w-full text-left border-collapse">
                        <thead>
                            <tr className="bg-white/5 border-b border-white/5">
                                <th className="p-4 text-[10px] font-black text-gray-500 uppercase tracking-widest">Data</th>
                                <th className="p-4 text-[10px] font-black text-gray-500 uppercase tracking-widest">Bateria</th>
                                <th className="p-4 text-[10px] font-black text-gray-500 uppercase tracking-widest">Tipo</th>
                                <th className="p-4 text-[10px] font-black text-gray-500 uppercase tracking-widest text-center">Qtd</th>
                                <th className="p-4 text-[10px] font-black text-gray-500 uppercase tracking-widest">Motivo</th>
                                <th className="p-4 text-[10px] font-black text-gray-500 uppercase tracking-widest">Local</th>
                                <th className="p-4 text-[10px] font-black text-gray-500 uppercase tracking-widest">Fonte</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-white/5">
                            {filteredHistory.map((entry) => {
                                const ts = entry.timestamp?.toDate ? entry.timestamp.toDate() : new Date(entry.timestamp);
                                const isIn = entry.type === 'in';
                                return (
                                    <tr key={entry.id} className="hover:bg-white/[0.02] transition-colors">
                                        <td className="p-4 text-sm text-gray-300 font-mono">{ts.toLocaleString('pt-BR')}</td>
                                        <td className="p-4">
                                            <p className="text-white font-bold">{entry.batteryName}</p>
                                        </td>
                                        <td className="p-4">
                                            <span className={`px-2 py-1 rounded text-[10px] font-black uppercase tracking-widest ${isIn ? 'bg-green-500/20 text-green-400' : 'bg-red-500/20 text-red-400'}`}>
                                                {isIn ? 'Entrada' : 'Saída'}
                                            </span>
                                        </td>
                                        <td className="p-4 text-center">
                                            <span className={`text-lg font-black ${isIn ? 'text-green-400' : 'text-red-400'}`}>
                                                {isIn ? '+' : '-'}{entry.quantity}
                                            </span>
                                        </td>
                                        <td className="p-4 text-sm text-gray-400 italic capitalize">{entry.reason.replace('_', ' ')}</td>
                                        <td className="p-4">
                                            <span className="text-xs px-2 py-1 bg-white/5 rounded-lg text-gray-300 uppercase font-bold tracking-tight">
                                                {entry.location}
                                            </span>
                                        </td>
                                        <td className="p-4">
                                            {entry.source === 'map' ? (
                                                <span className="flex items-center gap-1 text-[10px] font-black text-blue-400 uppercase tracking-widest bg-blue-400/10 px-2 py-1 rounded">
                                                    <span className="material-icons text-[12px]">map</span>
                                                    Mapa
                                                </span>
                                            ) : (
                                                <span className="text-[10px] font-black text-gray-600 uppercase tracking-widest px-2 py-1">
                                                    {entry.source}
                                                </span>
                                            )}
                                        </td>
                                    </tr>
                                );
                            })}
                        </tbody>
                    </table>
                </div>
            </div>
        )}

        {((!searchQuery && groupedData.length === 0) || (searchQuery && filteredHistory.length === 0)) && (
            <div className="flex flex-col items-center justify-center py-20 bg-[#141414]/30 rounded-[2.5rem] border-2 border-dashed border-white/5">
                <span className="material-icons text-5xl mb-3 text-gray-700">history_toggle_off</span>
                <p className="text-gray-500 font-bold">Nenhum registro encontrado.</p>
            </div>
        )}
    </div>
  );
};
