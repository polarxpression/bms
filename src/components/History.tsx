import { useEffect, useState, useMemo } from 'react';
import { batteryService } from '../services/batteryService';
import { HistoryAnalysis, type NestedGroup } from '../utils/historyAnalysis';
import { SearchQueryParser } from '../utils/searchQueryParser';
import type { HistoryEntry, Battery } from '../types';

export const History = () => {
  const [history, setHistory] = useState<HistoryEntry[]>([]);
  const [batteries, setBatteries] = useState<Battery[]>([]);
  const [loading, setLoading] = useState(true);
  const [topLevelGrouping, setTopLevelGrouping] = useState<'model' | 'brand'>('brand');
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
    const query = searchQuery.toLowerCase().trim();
    
    return history.filter(entry => {
        if (query) {
            const battery = batteries.find(b => b.id === entry.batteryId);
            const searchableItem = battery ? { 
                ...battery, 
                ...entry, 
                type: battery.type, 
                movement: entry.type 
            } : entry;
            if (!SearchQueryParser.matches(searchableItem, searchQuery)) return false;
        } else {
            if (entry.type === 'out' && entry.source !== 'map') return false;
        }
        
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

  const hierarchicalData = useMemo(() => {
    return HistoryAnalysis.buildHierarchy(filteredHistory, batteries, topLevelGrouping);
  }, [filteredHistory, batteries, topLevelGrouping]);

  if (loading) return (
    <div className="flex flex-col items-center justify-center py-20">
        <div className="w-12 h-12 border-4 border-[#EC4899]/20 border-t-[#EC4899] rounded-full animate-spin mb-4"></div>
        <p className="text-gray-500 font-bold animate-pulse">Organizando histórico...</p>
    </div>
  );

  return (
    <div className="space-y-8">
        {/* Filters */}
        <div className="bg-[#141414] p-6 rounded-3xl border border-white/5 shadow-xl space-y-4">
            <div className="w-full relative group">
                <span className="material-icons absolute left-4 top-1/2 -translate-y-1/2 text-gray-500 group-focus-within:text-[#EC4899] transition-colors">search</span>
                <input 
                    type="text"
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    placeholder="Filtrar histórico (Bateria, Marca, Tipo, Motivo...)"
                    className="w-full bg-black/40 text-white pl-12 pr-4 py-3 rounded-xl border border-white/10 focus:border-[#EC4899]/50 outline-none transition-all"
                />
                {searchQuery && (
                    <button onClick={() => setSearchQuery('')} className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-500 hover:text-white">
                        <span className="material-icons text-sm">close</span>
                    </button>
                )}
            </div>

            <div className="flex flex-col lg:flex-row gap-4 items-end">
                <div className="flex-1 w-full">
                    <label className="block text-[10px] font-black text-gray-500 uppercase tracking-widest mb-2 ml-1">Organizar por</label>
                    <select 
                        value={topLevelGrouping}
                        onChange={(e) => setTopLevelGrouping(e.target.value as 'model' | 'brand')}
                        className="w-full bg-black/40 text-white p-3 rounded-xl border border-white/10 focus:border-[#EC4899]/50 outline-none transition-all"
                    >
                        <option value="model">Bateria (Modelo)</option>
                        <option value="brand">Marca</option>
                    </select>
                </div>
                <div className="flex-[2] w-full grid grid-cols-2 gap-3">
                    <DateInput label="De" value={startDate} onChange={setStartDate} />
                    <DateInput label="Até" value={endDate} onChange={setEndDate} />
                </div>
                <button 
                    onClick={() => { setStartDate(''); setEndDate(''); setSearchQuery(''); }}
                    className="px-6 py-3 bg-white/5 hover:bg-white/10 text-gray-400 hover:text-white rounded-xl transition-all font-bold text-sm"
                >
                    Limpar
                </button>
            </div>
        </div>

        {/* Unified Hierarchical View */}
        <div className="space-y-4">
            {searchQuery && filteredHistory.length > 0 && (
                <div className="mb-4 px-4 py-2 bg-[#EC4899]/10 border border-[#EC4899]/20 rounded-xl inline-flex items-center gap-2">
                    <span className="material-icons text-sm text-[#EC4899]">info</span>
                    <span className="text-[10px] font-black text-white uppercase tracking-widest">
                        Mostrando {filteredHistory.length} resultados para "{searchQuery}"
                    </span>
                </div>
            )}

            {hierarchicalData.length === 0 ? (
                <div className="flex flex-col items-center justify-center py-20 bg-[#141414]/30 rounded-[2.5rem] border-2 border-dashed border-white/5">
                    <span className="material-icons text-5xl mb-3 text-gray-700">history_toggle_off</span>
                    <p className="text-gray-500 font-bold">Nenhum registro encontrado.</p>
                </div>
            ) : (
                hierarchicalData.map(group => (
                    <GroupNode 
                        key={group.id} 
                        group={group} 
                        level={0} 
                        batteries={batteries} 
                    />
                ))
            )}
        </div>
    </div>
  );
};

const GroupNode = ({ group, level, batteries }: { group: NestedGroup, level: number, batteries: Battery[] }) => {
    const [isExpanded, setIsExpanded] = useState(level === 0 && group.subgroups.length === 1); 
    const b = group.battery;
    const hasSubgroups = group.subgroups && group.subgroups.length > 0;

    return (
        <div className={`
            bg-[#141414] rounded-[2rem] border border-white/5 overflow-hidden transition-all duration-300
            ${level === 0 ? 'shadow-2xl mb-4 hover:border-white/10' : 'ml-6 mt-2 border-l-2 border-l-[#EC4899]/20 rounded-l-none bg-black/20 shadow-none'}
        `}>
            {/* Header */}
            <div 
                className={`p-6 cursor-pointer flex flex-col md:flex-row md:items-center justify-between gap-4 ${isExpanded ? 'bg-white/5' : 'hover:bg-white/[0.02]'}`}
                onClick={() => setIsExpanded(!isExpanded)}
            >
                <div className="flex items-center gap-4 flex-1 min-w-0">
                    <div className={`
                        w-14 h-14 rounded-2xl flex items-center justify-center shrink-0 shadow-inner
                        ${group.type === 'model' ? 'bg-[#EC4899]/10 text-[#EC4899]' : 
                          group.type === 'brand' ? 'bg-blue-500/10 text-blue-400' : 
                          group.type === 'year' ? 'bg-purple-500/10 text-purple-400' : 
                          group.type === 'month' ? 'bg-amber-500/10 text-amber-400' : 'bg-white/5 text-gray-500'}
                    `}>
                        <span className="material-icons text-2xl">
                            {group.type === 'model' ? 'battery_charging_full' : 
                             group.type === 'brand' ? 'branding_watermark' : 
                             group.type === 'year' ? 'event' : 
                             group.type === 'month' ? 'calendar_view_month' : 'folder'}
                        </span>
                    </div>
                    <div className="min-w-0">
                        <h3 className={`font-black tracking-tight truncate ${level === 0 ? 'text-xl text-white' : 'text-base text-gray-200'}`}>
                            {group.label}
                        </h3>
                        {level === 0 && b && group.type === 'model' && (
                            <p className="text-xs text-gray-500 font-bold uppercase tracking-widest mt-1">
                                {b.brand} • {b.type} • Estoque: <span className="text-[#EC4899]">{b.quantity}</span>
                            </p>
                        )}
                    </div>
                </div>

                <div className="flex items-center gap-4">
                    <div className="flex items-center bg-black/40 rounded-xl p-1 border border-white/5">
                        <div className="px-4 py-2 text-center border-r border-white/5">
                            <p className="text-[9px] font-black text-green-500/60 uppercase">Entradas</p>
                            <p className="text-base font-black text-green-400">+{group.ins}</p>
                        </div>
                        <div className="px-4 py-2 text-center">
                            <p className="text-[9px] font-black text-red-500/60 uppercase">Saídas</p>
                            <p className="text-base font-black text-red-400">-{group.outs}</p>
                        </div>
                    </div>
                    <div className={`w-10 h-10 rounded-full flex items-center justify-center transition-transform duration-300 ${isExpanded ? 'rotate-180 bg-[#EC4899] text-white' : 'bg-white/5 text-gray-500'}`}>
                        <span className="material-icons">expand_more</span>
                    </div>
                </div>
            </div>

            {/* Content */}
            {isExpanded && (
                <div className="p-4 pt-0 animate-fade-in">
                    {hasSubgroups ? (
                        <div className="space-y-2">
                            {group.subgroups.map(sub => (
                                <GroupNode key={sub.id} group={sub} level={level + 1} batteries={batteries} />
                            ))}
                        </div>
                    ) : (
                        <div className="mt-2 overflow-x-auto rounded-3xl border border-white/5 bg-black/40 ml-6">
                            <HistoryTable entries={group.entries} batteries={batteries} />
                        </div>
                    )}
                </div>
            )}
        </div>
    );
};

const HistoryTable = ({ entries, batteries }: { entries: HistoryEntry[], batteries: Battery[] }) => {
    const translateReason = (reason: string) => {
        const map: Record<string, string> = {
            'adjustment': 'Ajuste Manual',
            'restock': 'Reposição',
            'sale': 'Venda/Saída',
            'external_buy': 'Compra Externa'
        };
        return map[reason.toLowerCase()] || reason.replace(/_/g, ' ');
    };

    return (
        <table className="w-full text-left border-collapse">
            <thead>
                <tr className="bg-black/20 text-[10px] font-black text-gray-500 uppercase tracking-[0.2em] border-b border-white/5">
                    <th className="p-4 pl-8">Data</th>
                    <th className="p-4">Bateria</th>
                    <th className="p-4">Tipo</th>
                    <th className="p-4">Mov.</th>
                    <th className="p-4 text-center">Qtd</th>
                    <th className="p-4">Motivo</th>
                    <th className="p-4">Local</th>
                    <th className="p-4 pr-8 text-right">Fonte</th>
                </tr>
            </thead>
            <tbody className="divide-y divide-white/5">
                {entries.sort((a,b) => {
                    const tsA = a.timestamp?.toDate ? a.timestamp.toDate() : new Date(a.timestamp);
                    const tsB = b.timestamp?.toDate ? b.timestamp.toDate() : new Date(b.timestamp);
                    return tsB - tsA;
                }).map((entry) => {
                    const ts = entry.timestamp?.toDate ? entry.timestamp.toDate() : new Date(entry.timestamp);
                    const isIn = entry.type === 'in';
                    const battery = batteries.find(bat => bat.id === entry.batteryId);
                    return (
                        <tr key={entry.id} className="hover:bg-white/[0.03] transition-colors">
                            <td className="p-4 pl-8 text-xs text-gray-400 font-mono">{ts.toLocaleString('pt-BR')}</td>
                            <td className="p-4">
                                <p className="text-white font-bold text-sm">{entry.batteryName}</p>
                            </td>
                            <td className="p-4">
                                <span className="text-[10px] font-black text-gray-500 uppercase tracking-widest bg-white/5 px-2 py-1 rounded">
                                    {battery?.type || 'BATERIA'}
                                </span>
                            </td>
                            <td className="p-4">
                                <span className={`px-2 py-1 rounded text-[10px] font-black uppercase tracking-widest ${isIn ? 'bg-green-500/10 text-green-400' : 'bg-red-500/10 text-red-400'}`}>
                                    {isIn ? 'Entrada' : 'Saída'}
                                </span>
                            </td>
                            <td className="p-4 text-center">
                                <span className={`text-lg font-black ${isIn ? 'text-green-400' : 'text-red-400'}`}>
                                    {isIn ? '+' : '-'}{entry.quantity}
                                </span>
                            </td>
                            <td className="p-4 text-xs text-gray-300 italic font-medium">{translateReason(entry.reason)}</td>
                            <td className="p-4">
                                <span className="text-xs px-2 py-1 bg-white/5 rounded-lg text-gray-400 uppercase font-bold tracking-tight">
                                    {entry.location}
                                </span>
                            </td>
                            <td className="p-4 pr-8 text-right">
                                <span className="text-[10px] font-black text-gray-600 uppercase tracking-widest">
                                    {entry.source}
                                </span>
                            </td>
                        </tr>
                    );
                })}
            </tbody>
        </table>
    );
};

const DateInput = ({ label, value, onChange }: { label: string, value: string, onChange: (v: string) => void }) => (
    <div>
        <label className="block text-[10px] font-black text-gray-500 uppercase tracking-widest mb-2 ml-1">{label}</label>
        <input 
            type="date" 
            value={value}
            onChange={(e) => onChange(e.target.value)}
            className="w-full bg-black/40 text-white p-3 rounded-xl border border-white/10 focus:border-[#EC4899]/50 outline-none transition-all text-xs"
        />
    </div>
);