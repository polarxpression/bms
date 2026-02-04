import { useEffect, useState, useMemo } from 'react';
import { batteryService } from '../services/batteryService';
import type { Battery, AppSettings } from '../types';
import { SearchQueryParser } from '../utils/searchQueryParser';

export const Dashboard = () => {
  const [batteries, setBatteries] = useState<Battery[]>([]);
  const [settings, setSettings] = useState<AppSettings>({
    defaultGondolaCapacity: 20,
    defaultMinStockThreshold: 10,
    daysToAnalyze: 90
  });
  const [filterQuery, setFilterQuery] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsubBatteries = batteryService.subscribeToBatteries((data) => {
      setBatteries(data);
      setLoading(false);
    });
    const unsubSettings = batteryService.subscribeToSettings(setSettings);
    
    return () => {
        unsubBatteries();
        unsubSettings();
    };
  }, []);

  const totalBatteries = useMemo(() => 
    batteries.reduce((acc, b) => acc + (b.quantity || 0), 0), 
  [batteries]);

  const suggestions = useMemo(() => {
    return batteryService.getRestockSuggestions(batteries, settings);
  }, [batteries, settings]);

  const filteredSuggestions = useMemo(() => {
    if (!filterQuery) return suggestions;
    return suggestions.filter(b => SearchQueryParser.matches(b, filterQuery));
  }, [suggestions, filterQuery]);

  const handleRestock = async (b: Battery) => {
      const limit = b.gondolaLimit > 0 ? b.gondolaLimit : settings.defaultGondolaCapacity;
      const current = b.gondolaQuantity || 0;
      const needed = Math.max(0, limit - current);
      const canMove = Math.min(needed, b.quantity || 0);
      
      if (canMove > 0) {
          await batteryService.moveToGondola(b, canMove);
      }
  };

  if (loading) return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-6 animate-pulse">
        <div className="h-32 bg-white/5 rounded-3xl"></div>
        <div className="h-32 bg-white/5 rounded-3xl"></div>
    </div>
  );

  return (
    <div className="space-y-10">
        {/* Stats Row */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <StatBox label="Total em Estoque" value={totalBatteries} icon="inventory" color="#EC4899" />
            <StatBox label="Sugestões Ativas" value={suggestions.length} icon="bolt" color="#F59E0B" />
            <div className="hidden lg:block bg-gradient-to-br from-[#141414] to-[#0d0d0d] p-6 rounded-3xl border border-white/5 relative overflow-hidden">
                <div className="relative z-10">
                    <p className="text-[10px] font-black text-gray-500 uppercase tracking-widest mb-1">Status Global</p>
                    <div className="flex items-center gap-2">
                        <div className="w-2 h-2 rounded-full bg-green-500 shadow-[0_0_8px_#22c55e]"></div>
                        <p className="text-xl font-bold text-white">Operacional</p>
                    </div>
                    <p className="text-xs text-gray-500 mt-2">Dados sincronizados em tempo real com Firebase</p>
                </div>
                <div className="absolute -right-4 -bottom-4 opacity-5">
                    <span className="material-icons text-9xl">wifi</span>
                </div>
            </div>
        </div>

        {/* Action Bar */}
        <div className="flex flex-col md:flex-row gap-4 items-center">
            <div className="relative flex-1 w-full group">
                <span className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                    <span className="material-icons text-gray-500 group-focus-within:text-[#EC4899] transition-colors">search</span>
                </span>
                <input 
                    type="text"
                    placeholder="Filtrar sugestões de reposição..."
                    className="w-full bg-[#141414] text-white pl-12 pr-12 py-4 rounded-2xl border border-white/5 focus:border-[#EC4899]/50 focus:bg-[#1c1c1c] focus:outline-none transition-all placeholder:text-gray-600 shadow-xl"
                    value={filterQuery}
                    onChange={(e) => setFilterQuery(e.target.value)}
                />
                {filterQuery && (
                    <button 
                        onClick={() => setFilterQuery('')}
                        className="absolute inset-y-0 right-0 pr-4 flex items-center text-gray-500 hover:text-white transition-colors"
                    >
                        <span className="material-icons text-xl">cancel</span>
                    </button>
                )}
            </div>
        </div>

        {/* List Section */}
        <div className="animate-fade-in-up">
            <div className="flex items-center justify-between mb-6">
                <h2 className="text-2xl font-black text-white tracking-tight flex items-center">
                    <span className="w-8 h-8 rounded-lg bg-[#EC4899]/20 flex items-center justify-center mr-3">
                        <span className="material-icons text-sm text-[#EC4899]">auto_awesome</span>
                    </span>
                    Sugestões de Reposição
                </h2>
                <span className="text-xs font-bold text-gray-500 uppercase tracking-widest">{filteredSuggestions.length} Itens</span>
            </div>
            
            {filteredSuggestions.length === 0 ? (
                <div className="flex flex-col items-center justify-center py-20 bg-[#141414]/30 rounded-[2.5rem] border-2 border-dashed border-white/5">
                    <div className="w-16 h-16 rounded-full bg-green-500/10 flex items-center justify-center mb-4">
                        <span className="material-icons text-3xl text-green-500">done_all</span>
                    </div>
                    <p className="text-gray-400 font-bold">Tudo em ordem!</p>
                    <p className="text-sm text-gray-600 mt-1 text-center max-w-xs">Nenhuma bateria precisa ser movida para a gôndola no momento.</p>
                </div>
            ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                    {filteredSuggestions.map((b, idx) => (
                        <RestockCard 
                            key={b.id} 
                            battery={b} 
                            onRestock={() => handleRestock(b)} 
                            style={{ animationDelay: `${idx * 50}ms` }}
                        />
                    ))}
                </div>
            )}
        </div>
    </div>
  );
};

const StatBox = ({ label, value, icon, color }: { label: string, value: number, icon: string, color: string }) => (
    <div className="bg-[#141414] p-8 rounded-3xl border border-white/5 relative overflow-hidden group hover:border-white/10 transition-all shadow-2xl">
        <div className="absolute top-0 right-0 p-6 opacity-5 group-hover:opacity-10 group-hover:scale-110 transition-all duration-500">
            <span className="material-icons text-8xl" style={{ color }}>{icon}</span>
        </div>
        <div className="relative z-10">
            <div className="w-12 h-12 rounded-2xl flex items-center justify-center mb-4 shadow-inner" style={{ backgroundColor: `${color}15` }}>
                <span className="material-icons" style={{ color }}>{icon}</span>
            </div>
            <p className="text-xs font-black uppercase tracking-[0.2em] mb-1 opacity-60" style={{ color }}>{label}</p>
            <p className="text-5xl font-black text-white tracking-tighter">{value}</p>
        </div>
        <div className="absolute bottom-0 left-0 h-1 w-0 group-hover:w-full transition-all duration-700" style={{ backgroundColor: color }}></div>
    </div>
);

const RestockCard = ({ battery, onRestock, style }: { battery: Battery, onRestock: () => void, style?: any }) => {
    const [showMaps, setShowMaps] = useState(false);
    const [maps, setMaps] = useState<any[]>([]);
    const [loadingMaps, setLoadingMaps] = useState(false);

    const limit = battery.gondolaLimit || 20;
    const current = battery.gondolaQuantity || 0;
    const percentage = Math.min(100, (current / limit) * 100);
    const needed = Math.max(0, limit - current);
    const canMove = Math.min(needed, battery.quantity);
    const isOutOfStock = battery.quantity === 0;

    const handleShowMaps = async () => {
        setShowMaps(true);
        setLoadingMaps(true);
        try {
            const results = await batteryService.findBatteryInMaps(battery.id);
            setMaps(results);
        } catch (err) {
            console.error(err);
        } finally {
            setLoadingMaps(false);
        }
    };

    return (
        <div 
            className="bg-[#141414] p-6 rounded-3xl border border-white/5 hover:border-[#EC4899]/30 transition-all group animate-fade-in-up shadow-lg hover:shadow-[#EC4899]/5 relative"
            style={style}
        >
            <div className="flex items-start justify-between mb-6">
                <div className="flex items-center">
                    <div className={`w-12 h-12 rounded-2xl flex items-center justify-center mr-4 shadow-xl ${isOutOfStock ? 'bg-red-500/10 text-red-500' : 'bg-[#EC4899]/10 text-[#EC4899]'}`}>
                        <span className="material-icons text-2xl">{isOutOfStock ? 'production_quantity_limits' : 'priority_high'}</span>
                    </div>
                    <div>
                        <h3 className="font-extrabold text-base text-white leading-tight">{battery.brand}</h3>
                        <p className="text-xs text-gray-500 font-medium uppercase tracking-wider">{battery.model}</p>
                    </div>
                </div>
                <div className="flex items-center gap-2">
                    <button 
                        onClick={handleShowMaps}
                        className="w-8 h-8 rounded-lg bg-blue-500/10 text-blue-400 hover:bg-blue-500/20 flex items-center justify-center transition-colors"
                        title="Ver nos Mapas"
                    >
                        <span className="material-icons text-sm">map</span>
                    </button>
                    <div className="px-3 py-1 bg-white/5 rounded-full">
                        <p className="text-[10px] font-black text-gray-500">{battery.type}</p>
                    </div>
                </div>
            </div>
            
            <div className="space-y-4 mb-6">
                <div className="flex justify-between items-end mb-1">
                    <span className="text-[10px] font-black text-gray-500 uppercase tracking-widest">Nível da Gôndola</span>
                    <span className="text-xs font-bold text-white">{current} <span className="text-gray-600">/ {limit}</span></span>
                </div>
                <div className="h-2 w-full bg-black/40 rounded-full overflow-hidden p-[2px]">
                    <div 
                        className={`h-full rounded-full transition-all duration-1000 ${percentage < 30 ? 'bg-red-500 shadow-[0_0_8px_#ef4444]' : 'bg-[#EC4899] shadow-[0_0_8px_#ec4899]'}`}
                        style={{ width: `${percentage}%` }}
                    ></div>
                </div>
                <div className="flex justify-between items-center bg-black/20 p-3 rounded-2xl border border-white/5">
                    <div className="flex flex-col">
                        <span className="text-[9px] uppercase font-black text-gray-600 tracking-wider">Disponível em Estoque</span>
                        <span className={`text-sm font-black ${isOutOfStock ? 'text-red-500' : 'text-green-400'}`}>{battery.quantity} unidades</span>
                    </div>
                    <div className="w-8 h-8 rounded-lg bg-white/5 flex items-center justify-center">
                        <span className="material-icons text-gray-500 text-sm">inventory</span>
                    </div>
                </div>
            </div>

            <div className="flex items-center gap-3">
                <div className={`flex-1 flex items-center justify-center h-12 rounded-2xl text-xs font-black uppercase tracking-widest ${isOutOfStock ? 'bg-red-500/10 text-red-500 border border-red-500/20' : 'bg-[#EC4899]/10 text-[#EC4899] border border-[#EC4899]/20'}`}>
                    Repor {canMove}
                </div>
                <button 
                    onClick={onRestock}
                    disabled={canMove <= 0}
                    className="w-12 h-12 flex items-center justify-center rounded-2xl bg-[#EC4899] text-white hover:bg-[#D61F69] hover:scale-105 active:scale-95 disabled:opacity-20 disabled:hover:scale-100 shadow-lg shadow-pink-500/20 transition-all group/btn"
                >
                    <span className="material-icons group-hover/btn:translate-x-1 transition-transform">arrow_forward</span>
                </button>
            </div>

            {/* Map Modal Overlay */}
            {showMaps && (
                <div className="absolute inset-0 z-50 bg-[#141414] rounded-3xl p-6 flex flex-col animate-fade-in">
                    <div className="flex items-center justify-between mb-4">
                        <h4 className="text-sm font-black text-white uppercase tracking-widest">Localização</h4>
                        <button onClick={() => setShowMaps(false)} className="text-gray-500 hover:text-white transition-colors">
                            <span className="material-icons text-lg">close</span>
                        </button>
                    </div>
                    <div className="flex-1 overflow-y-auto custom-scrollbar space-y-2">
                        {loadingMaps ? (
                            <div className="flex items-center justify-center py-8">
                                <div className="w-6 h-6 border-2 border-blue-500/20 border-t-blue-500 rounded-full animate-spin"></div>
                            </div>
                        ) : maps.length === 0 ? (
                            <p className="text-xs text-gray-600 text-center py-4">Não posicionado em mapas.</p>
                        ) : (
                            maps.map(m => (
                                <a key={m.id} href={`/bms/map?highlight=${battery.id}&mapId=${m.id}`} className="flex items-center gap-3 p-3 bg-white/5 rounded-xl hover:bg-white/10 transition-colors border border-white/5">
                                    <span className="material-icons text-blue-500 text-sm">location_on</span>
                                    <div>
                                        <p className="text-xs font-bold text-white">{m.name}</p>
                                        <p className="text-[10px] text-gray-500">{m.purpose}</p>
                                    </div>
                                    <span className="material-icons text-gray-700 ml-auto text-sm">chevron_right</span>
                                </a>
                            ))
                        )}
                    </div>
                </div>
            )}
        </div>
    );
};

