import { useEffect, useState, useMemo } from 'react';
import { batteryService } from '../services/batteryService';
import type { Battery, BatteryMap } from '../types';

const CELL_SIZE = 140;
const GRID_SIZE = 20; // 20x20 grid

export const MapComponent = () => {
  const [maps, setMaps] = useState<BatteryMap[]>([]);
  const [currentMap, setCurrentMap] = useState<BatteryMap | null>(null);
  const [cells, setCells] = useState<Record<string, string>>({}); // "x,y" -> batteryId
  const [batteries, setBatteries] = useState<Battery[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedBatteryId, setSelectedBatteryId] = useState<string>('');

  useEffect(() => {
    const unsubBatteries = batteryService.subscribeToBatteries(setBatteries);
    const unsubMaps = batteryService.subscribeToMaps((data) => {
        setMaps(data);
        if (data.length > 0 && !currentMap) {
            setCurrentMap(data[0]);
        }
        setLoading(false);
    });
    return () => {
        unsubBatteries();
        unsubMaps();
    };
  }, []);

  useEffect(() => {
    if (currentMap) {
        const unsubCells = batteryService.subscribeToMapCells(currentMap.id, setCells);
        return () => unsubCells();
    }
  }, [currentMap]);

  const handleCellClick = async (x: number, y: number) => {
      if (!currentMap) return;
      const key = `${x},${y}`;
      const existing = cells[key];

      if (existing) {
          if (confirm("Remover bateria desta posição?")) {
              await batteryService.removeBatteryFromMap(currentMap.id, x, y);
          }
      } else if (selectedBatteryId) {
          await batteryService.placeBatteryOnMap(currentMap.id, x, y, selectedBatteryId);
      }
  };

  const gondolaBatteries = useMemo(() => 
    batteries.filter(b => b.location?.toLowerCase().includes('gondola') || b.location?.toLowerCase().includes('gôndola')), 
  [batteries]);

  if (loading) return <div className="p-8 text-center text-gray-500">Carregando mapas...</div>;

  return (
    <div className="flex flex-col h-[calc(100vh-200px)]">
        {/* Map Header */}
        <div className="bg-[#141414] p-4 rounded-t-xl border border-white/5 flex flex-wrap items-center justify-between gap-4">
            <div className="flex items-center gap-4">
                <select 
                    value={currentMap?.id} 
                    onChange={(e) => setCurrentMap(maps.find(m => m.id === e.target.value) || null)}
                    className="bg-black/40 text-white px-4 py-2 rounded-lg border border-white/10 focus:border-[#EC4899] outline-none font-bold"
                >
                    {maps.map(m => <option key={m.id} value={m.id}>{m.name}</option>)}
                </select>
                <div className="text-xs text-gray-500">
                    {currentMap?.purpose}
                </div>
            </div>

            <div className="flex items-center gap-2">
                <label className="text-xs font-bold text-gray-500 uppercase">Selecionar para colocar:</label>
                <select 
                    value={selectedBatteryId}
                    onChange={(e) => setSelectedBatteryId(e.target.value)}
                    className="bg-black/40 text-[#EC4899] px-3 py-2 rounded-lg border border-[#EC4899]/20 focus:border-[#EC4899] outline-none text-sm font-medium"
                >
                    <option value="">(Nenhuma - Clique para remover)</option>
                    {gondolaBatteries.map(b => (
                        <option key={b.id} value={b.id}>{b.brand} {b.model}</option>
                    ))}
                </select>
            </div>
        </div>

        {/* Map Grid */}
        <div className="flex-1 bg-[#0a0a0a] border-x border-b border-white/5 overflow-auto relative custom-scrollbar p-20">
            <div 
                className="relative bg-black/20 rounded-lg border border-white/5"
                style={{ 
                    width: GRID_SIZE * CELL_SIZE, 
                    height: GRID_SIZE * CELL_SIZE,
                    backgroundImage: 'radial-gradient(circle, #222 1px, transparent 1px)',
                    backgroundSize: `${CELL_SIZE}px ${CELL_SIZE}px`
                }}
            >
                {Array.from({ length: GRID_SIZE }).map((_, y) => 
                    Array.from({ length: GRID_SIZE }).map((_, x) => {
                        const batteryId = cells[`${x},${y}`];
                        const battery = batteries.find(b => b.id === batteryId);
                        
                        return (
                            <div 
                                key={`${x},${y}`}
                                onClick={() => handleCellClick(x, y)}
                                className={`absolute flex flex-col items-center justify-center p-2 border transition-all cursor-pointer group
                                    ${battery ? 'bg-[#1E1E1E] border-blue-500/50 shadow-lg' : 'bg-white/5 border-white/5 hover:bg-white/10 hover:border-[#EC4899]/30'}
                                `}
                                style={{ 
                                    left: x * CELL_SIZE, 
                                    top: y * CELL_SIZE, 
                                    width: CELL_SIZE - 8, 
                                    height: CELL_SIZE - 8,
                                    margin: 4,
                                    borderRadius: 12
                                }}
                            >
                                {battery ? (
                                    <>
                                        <div className="text-[10px] font-black text-blue-400 uppercase truncate w-full text-center">{battery.brand}</div>
                                        <div className="flex-1 flex items-center justify-center py-1">
                                            {battery.imageUrl ? (
                                                <img src={battery.imageUrl} className="max-h-full max-w-full object-contain" />
                                            ) : (
                                                <span className="material-icons text-gray-600 text-3xl">battery_std</span>
                                            )}
                                        </div>
                                        <div className="text-[11px] font-bold text-white truncate w-full text-center leading-tight">{battery.model}</div>
                                        <div className="text-[9px] text-gray-500 font-bold mt-1">Gôn: {battery.gondolaQuantity}</div>
                                    </>
                                ) : (
                                    <span className="material-icons text-gray-800 group-hover:text-[#EC4899]/50 transition-colors">add</span>
                                )}
                            </div>
                        );
                    })
                )}
            </div>
        </div>
        
        <div className="p-4 bg-[#141414] rounded-b-xl border-x border-b border-white/5 text-[10px] text-gray-500 flex justify-between">
            <span>Dica: Selecione uma bateria no topo e clique em um espaço vazio para posicionar.</span>
            <span>Grade: {GRID_SIZE}x{GRID_SIZE}</span>
        </div>
    </div>
  );
};
