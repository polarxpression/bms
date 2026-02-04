import { useEffect, useState, useMemo } from 'react';
import { batteryService } from '../services/batteryService';
import type { Battery, AppSettings } from '../types';

export const ExternalBuy = () => {
  const [batteries, setBatteries] = useState<Battery[]>([]);
  const [settings, setSettings] = useState<AppSettings>({
    defaultGondolaCapacity: 20,
    defaultMinStockThreshold: 10,
    daysToAnalyze: 90
  });
  const [consumption, setConsumption] = useState<Record<string, number>>({});
  const [loading, setLoading] = useState(true);
  const [selectedBrand, setSelectedBrand] = useState<string>('');
  const [selectedType, setSelectedType] = useState<string>('');
  const [roundTo, setRoundTo] = useState<number>(0);

  useEffect(() => {
    let unsubBatteries: () => void;
    let unsubSettings: () => void;

    const fetchData = async () => {
      setLoading(true);
      unsubSettings = batteryService.subscribeToSettings((s) => {
          setSettings(s);
      });

      // Initially use the current settings or default
      const cons = await batteryService.getMonthlyConsumption(settings.daysToAnalyze);
      setConsumption(cons);
      
      unsubBatteries = batteryService.subscribeToBatteries((data) => {
        setBatteries(data);
        setLoading(false);
      });
    };

    fetchData();

    return () => {
        if (unsubBatteries) unsubBatteries();
        if (unsubSettings) unsubSettings();
    };
  }, [settings.daysToAnalyze]);

  const buyList = useMemo(() => {
    return batteryService.getExternalBuyList(batteries, consumption, settings);
  }, [batteries, consumption, settings]);

  const brands = useMemo<string[]>(() => 
    Array.from(new Set(buyList.map((b: Battery) => b.brand).filter(Boolean))).sort() as string[], 
  [buyList]);

  const types = useMemo<string[]>(() => 
    Array.from(new Set(buyList.map((b: Battery) => b.type).filter(Boolean))).sort() as string[], 
  [buyList]);

  const filteredList = useMemo(() => {
    return buyList.filter((b: Battery) => {
      if (selectedBrand && b.brand !== selectedBrand) return false;
      if (selectedType && b.type !== selectedType) return false;
      return true;
    });
  }, [buyList, selectedBrand, selectedType]);

  const exportCSV = () => {
    if (filteredList.length === 0) return;
    
    const headers = ["Marca", "Modelo", "Tipo", "EAN", "Estoque Atual", "Minimo", "Sugestao Compra"];
    const rows = filteredList.map((b: Battery) => {
      let needed = Math.max(0, b.minStockThreshold - b.quantity);
      if (roundTo > 0) {
        needed = Math.ceil(needed / roundTo) * roundTo;
      }
      return [
        b.brand,
        b.model,
        b.type || "",
        b.barcode,
        b.quantity,
        b.minStockThreshold,
        needed
      ];
    });

    const csvContent = [headers, ...rows].map(e => e.join(",")).join("\n");
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.setAttribute("href", url);
    link.setAttribute("download", `reposicao_externa_${new Date().toISOString().split('T')[0]}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  if (loading) return <div className="p-8 text-center text-gray-500">Analisando histórico e estoque...</div>;

  return (
    <div className="space-y-6">
        {/* Toolbar & Filters */}
        <div className="bg-[#141414] p-6 rounded-2xl border border-white/5 space-y-6 shadow-xl relative overflow-hidden">
            <div className="flex flex-col lg:flex-row gap-6">
                <div className="flex-1">
                    <label className="block text-[10px] font-black text-gray-500 uppercase tracking-widest mb-2 ml-1">Marca</label>
                    <select 
                        value={selectedBrand} 
                        onChange={e => setSelectedBrand(e.target.value)}
                        className="w-full bg-black/40 text-white p-3 rounded-xl border border-white/10 focus:border-[#EC4899]/50 outline-none transition-all"
                    >
                        <option value="">Todas as Marcas</option>
                        {brands.map((b: string) => <option key={b} value={b}>{b}</option>)}
                    </select>
                </div>
                <div className="flex-1">
                    <label className="block text-[10px] font-black text-gray-500 uppercase tracking-widest mb-2 ml-1">Tipo</label>
                    <select 
                        value={selectedType} 
                        onChange={e => setSelectedType(e.target.value)}
                        className="w-full bg-black/40 text-white p-3 rounded-xl border border-white/10 focus:border-[#EC4899]/50 outline-none transition-all"
                    >
                        <option value="">Todos os Tipos</option>
                        {types.map((t: string) => <option key={t} value={t}>{t}</option>)}
                    </select>
                </div>
                <div className="flex-1">
                    <label className="block text-[10px] font-black text-gray-500 uppercase tracking-widest mb-2 ml-1">Arredondar para (Múltiplos)</label>
                    <input 
                        type="number" 
                        placeholder="Ex: 12 para dúzias"
                        value={roundTo || ''}
                        onChange={e => setRoundTo(Number(e.target.value))}
                        className="w-full bg-black/40 text-white p-3 rounded-xl border border-white/10 focus:border-[#EC4899]/50 outline-none transition-all placeholder:text-gray-700"
                    />
                </div>
                <div className="flex items-end">
                    <button 
                        onClick={exportCSV}
                        disabled={filteredList.length === 0}
                        className="w-full lg:w-auto px-8 py-3.5 bg-blue-600 hover:bg-blue-700 disabled:opacity-30 text-white rounded-xl font-black uppercase tracking-widest text-xs flex items-center justify-center transition-all shadow-lg shadow-blue-500/20 active:scale-95"
                    >
                        <span className="material-icons text-sm mr-2">download</span>
                        Exportar CSV
                    </button>
                </div>
            </div>
        </div>

        {/* List */}
        <div className="grid grid-cols-1 gap-3">
            {filteredList.length === 0 ? (
                <div className="flex flex-col items-center justify-center py-16 text-gray-500 bg-[#141414]/30 rounded-2xl border border-dashed border-white/10">
                    <span className="material-icons text-5xl mb-3 text-green-500/50">check_circle</span>
                    <p className="text-lg font-medium">Estoque abastecido!</p>
                    <p className="text-sm">Nenhum item abaixo do nível crítico.</p>
                </div>
            ) : (
                filteredList.map((b: Battery) => {
                    let needed = Math.max(0, b.minStockThreshold - b.quantity);
                    if (roundTo > 0) {
                        needed = Math.ceil(needed / roundTo) * roundTo;
                    }
                    const isDynamic = b.notes?.startsWith('dynamic:');
                    const dynamicRate = isDynamic ? b.notes?.split(':')[1] : null;

                    return (
                        <div key={b.id} className="bg-[#141414] p-4 rounded-xl border border-white/5 flex flex-col md:flex-row md:items-center justify-between group hover:border-blue-500/30 transition-colors">
                            <div className="flex items-center mb-4 md:mb-0">
                                <div className={`w-12 h-12 rounded-xl flex items-center justify-center mr-4 ${isDynamic ? 'bg-purple-500/10 text-purple-400' : 'bg-blue-500/10 text-blue-400'}`}>
                                    <span className="material-icons text-2xl">{isDynamic ? 'auto_graph' : 'shopping_basket'}</span>
                                </div>
                                <div>
                                    <h3 className="font-bold text-white text-lg">{b.brand} {b.model}</h3>
                                    <div className="flex flex-wrap items-center gap-2 mt-1">
                                        <span className="text-xs bg-white/5 px-2 py-0.5 rounded text-gray-400">{b.type}</span>
                                        <span className="text-xs text-gray-500">Estoque: <b className="text-white">{b.quantity}</b></span>
                                        <span className="text-xs text-gray-500">Mínimo: <b className="text-white">{b.minStockThreshold}</b></span>
                                        {isDynamic && (
                                            <span className="text-[10px] font-bold text-purple-400 uppercase tracking-tighter bg-purple-400/10 px-1.5 py-0.5 rounded border border-purple-400/20">
                                                Consumo: ~{dynamicRate}/mês
                                            </span>
                                        )}
                                    </div>
                                </div>
                            </div>
                            
                            <div className={`px-6 py-3 rounded-xl font-bold text-lg text-center md:text-left ${isDynamic ? 'bg-purple-500/10 text-purple-400' : 'bg-blue-500/10 text-blue-400'} border border-transparent group-hover:border-current/20 transition-all`}>
                                <span className="text-xs block uppercase opacity-60 font-black mb-0.5">Comprar</span>
                                +{needed}
                            </div>
                        </div>
                    );
                })
            )}
        </div>

        {/* Config Info */}
        <div className="flex items-center justify-between p-4 bg-blue-500/5 rounded-xl border border-blue-500/10">
            <div className="flex items-center text-xs text-blue-400">
                <span className="material-icons text-sm mr-2">info</span>
                <span>Cálculo baseado nos últimos <b>{settings.daysToAnalyze} dias</b> de histórico (Configuração do Sistema).</span>
            </div>
        </div>
    </div>
  );
};
