import { useEffect, useState, useRef, useMemo } from 'react';
import { batteryService } from '../services/batteryService';
import type { Battery, BatteryMap } from '../types';

const CELL_SIZE = 120;
const CELL_SPACING = 8;
const GRID_CENTER_OFFSET = 2000; // Virtual center for infinite feel

export const MapComponent = () => {
  const [maps, setMaps] = useState<BatteryMap[]>([]);
  const [currentMap, setCurrentMap] = useState<BatteryMap | null>(null);
  const [cells, setCells] = useState<Record<string, string>>({}); // "x,y" -> batteryId
  const [batteries, setBatteries] = useState<Battery[]>([]);
  const [loading, setLoading] = useState(true);
  
  // Viewport State
  const [transform, setTransform] = useState({ x: -GRID_CENTER_OFFSET, y: -GRID_CENTER_OFFSET, scale: 1 });
  const [isDragging, setIsDragging] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);
  const dragStart = useRef({ x: 0, y: 0 });

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

  // Viewport Logic
  const handleMouseDown = (e: React.MouseEvent) => {
    if (e.button !== 0) return; // Only left click
    setIsDragging(true);
    dragStart.current = { x: e.clientX - transform.x, y: e.clientY - transform.y };
  };

  const handleMouseMove = (e: React.MouseEvent) => {
    if (!isDragging) return;
    setTransform(prev => ({
        ...prev,
        x: e.clientX - dragStart.current.x,
        y: e.clientY - dragStart.current.y
    }));
  };

  const handleMouseUp = () => setIsDragging(false);
  const handleWheel = (e: React.WheelEvent) => {
      const newScale = Math.min(Math.max(0.2, transform.scale - e.deltaY * 0.001), 2);
      setTransform(prev => ({ ...prev, scale: newScale }));
  };

  // Cell Logic
  const occupiedCells = useMemo(() => {
      return Object.entries(cells).map(([key, batteryId]) => {
          const [x, y] = key.split(',').map(Number);
          return { x, y, batteryId };
      });
  }, [cells]);

  const potentialSpots = useMemo(() => {
      const spots = new Set<string>();
      if (occupiedCells.length === 0) spots.add("0,0");
      
      occupiedCells.forEach(({ x, y }) => {
          const neighbors = [
              `${x + 1},${y}`,
              `${x - 1},${y}`,
              `${x},${y + 1}`,
              `${x},${y - 1}`
          ];
          neighbors.forEach(n => {
              if (!cells[n]) spots.add(n);
          });
      });
      return Array.from(spots).map(s => {
          const [x, y] = s.split(',').map(Number);
          return { x, y };
      });
  }, [occupiedCells, cells]);

  // Drag & Drop Items Logic
  const handleDragStart = (e: React.DragEvent, x: number, y: number, batteryId: string) => {
      e.dataTransfer.setData("application/json", JSON.stringify({ x, y, batteryId }));
      e.dataTransfer.effectAllowed = "move";
  };

  const handleDrop = async (e: React.DragEvent, targetX: number, targetY: number) => {
      e.preventDefault();
      if (!currentMap) return;
      
      try {
        const data = JSON.parse(e.dataTransfer.getData("application/json"));
        // From Map
        if (data.x !== undefined && data.y !== undefined) {
            const fromX = data.x;
            const fromY = data.y;
            const fromId = data.batteryId;

            // Check if target occupied (Swap)
            const targetId = cells[`${targetX},${targetY}`];
            if (targetId) {
                await batteryService.swapBatteriesOnMap(currentMap.id, fromX, fromY, targetX, targetY, fromId, targetId);
            } else {
                await batteryService.moveBatteryOnMap(currentMap.id, fromX, fromY, targetX, targetY, fromId);
            }
        } 
        // New Placement (from Sidebar/Picker - Not implemented yet, assumes internal move for now)
      } catch (err) {
          console.error("Drop error", err);
      }
  };

  const handleSidebarDrop = async (e: React.DragEvent, targetX: number, targetY: number) => {
      e.preventDefault();
      if (!currentMap) return;
      const batteryId = e.dataTransfer.getData("battery-id"); // Simple string for new items
      if (batteryId) {
          await batteryService.placeBatteryOnMap(currentMap.id, targetX, targetY, batteryId);
      } else {
          // Try internal move fallback
          handleDrop(e, targetX, targetY);
      }
  };

  const centerMap = () => {
      if (containerRef.current) {
          const { width, height } = containerRef.current.getBoundingClientRect();
          setTransform({
              x: (width / 2) - (GRID_CENTER_OFFSET + CELL_SIZE/2),
              y: (height / 2) - (GRID_CENTER_OFFSET + CELL_SIZE/2),
              scale: 1
          });
      }
  };

  // Initial Center
  useEffect(() => {
      centerMap();
  }, []);

  const getBattery = (id: string) => batteries.find(b => b.id === id);

  return (
    <div className="flex h-screen bg-[#050505] overflow-hidden">
        {/* Sidebar Picker */}
        <SidebarPicker batteries={batteries} />

        {/* Map Canvas */}
        <div className="flex-1 flex flex-col relative">
            {/* Header */}
            <div className="absolute top-4 left-4 z-50 flex gap-2">
                <select 
                    value={currentMap?.id} 
                    onChange={(e) => setCurrentMap(maps.find(m => m.id === e.target.value) || null)}
                    className="bg-[#141414]/90 backdrop-blur text-white px-4 py-2 rounded-xl border border-white/10 shadow-xl focus:border-[#EC4899] outline-none font-bold"
                >
                    {maps.map(m => <option key={m.id} value={m.id}>{m.name}</option>)}
                </select>
                <button 
                    onClick={centerMap}
                    className="bg-[#141414]/90 backdrop-blur text-white p-2 rounded-xl border border-white/10 shadow-xl hover:bg-white/10"
                    title="Centralizar"
                >
                    <span className="material-icons">center_focus_strong</span>
                </button>
            </div>

            <div 
                ref={containerRef}
                className="flex-1 bg-[#0a0a0a] cursor-grab active:cursor-grabbing relative overflow-hidden"
                onMouseDown={handleMouseDown}
                onMouseMove={handleMouseMove}
                onMouseUp={handleMouseUp}
                onMouseLeave={handleMouseUp}
                onWheel={handleWheel}
            >
                <div 
                    className="absolute origin-top-left transition-transform duration-75 ease-out will-change-transform"
                    style={{ 
                        transform: `translate(${transform.x}px, ${transform.y}px) scale(${transform.scale})`,
                        width: 4000, 
                        height: 4000 
                    }}
                >
                    <GridBackground />
                    
                    {/* Render Occupied Cells */}
                    {occupiedCells.map(({ x, y, batteryId }) => {
                        const battery = getBattery(batteryId);
                        if (!battery) return null;
                        return (
                            <div
                                key={`${x},${y}`}
                                className="absolute bg-[#1E1E1E] rounded-xl border border-blue-500/30 shadow-lg hover:border-green-400 hover:z-10 group"
                                style={{
                                    left: GRID_CENTER_OFFSET + x * (CELL_SIZE + CELL_SPACING),
                                    top: GRID_CENTER_OFFSET + y * (CELL_SIZE + CELL_SPACING),
                                    width: CELL_SIZE,
                                    height: CELL_SIZE,
                                }}
                                draggable
                                onDragStart={(e) => handleDragStart(e, x, y, batteryId)}
                                onDragOver={(e) => e.preventDefault()}
                                onDrop={(e) => handleDrop(e, x, y)}
                                onClick={(e) => { e.stopPropagation(); if(confirm('Remover?')) batteryService.removeBatteryFromMap(currentMap!.id, x, y); }}
                            >
                                <div className="w-full h-full p-2 flex flex-col items-center justify-center pointer-events-none">
                                    <span className="text-[10px] font-black text-blue-400 uppercase truncate w-full text-center">{battery.brand}</span>
                                    <div className="flex-1 flex items-center justify-center w-full">
                                        {battery.imageUrl ? (
                                            <img src={battery.imageUrl} className="max-h-full object-contain" />
                                        ) : (
                                            <span className="material-icons text-gray-600 text-3xl">battery_std</span>
                                        )}
                                    </div>
                                    <span className="text-[10px] font-bold text-white truncate w-full text-center">{battery.model}</span>
                                    <span className="text-[9px] text-gray-500">x{battery.packSize}</span>
                                </div>
                            </div>
                        );
                    })}

                    {/* Render Empty Spots */}
                    {potentialSpots.map(({ x, y }) => (
                        <div
                            key={`empty_${x},${y}`}
                            className="absolute rounded-xl border border-dashed border-white/10 hover:border-blue-500 hover:bg-blue-500/10 transition-colors flex items-center justify-center"
                            style={{
                                left: GRID_CENTER_OFFSET + x * (CELL_SIZE + CELL_SPACING),
                                top: GRID_CENTER_OFFSET + y * (CELL_SIZE + CELL_SPACING),
                                width: CELL_SIZE,
                                height: CELL_SIZE,
                            }}
                            onDragOver={(e) => e.preventDefault()}
                            onDrop={(e) => handleSidebarDrop(e, x, y)}
                        >
                            <span className="material-icons text-white/10">add</span>
                        </div>
                    ))}
                </div>
            </div>
        </div>
    </div>
  );
};

const SidebarPicker = ({ batteries }: { batteries: Battery[] }) => {
    const [query, setQuery] = useState('');
    
    const gondolaItems = useMemo(() => {
        return batteries.filter(b => {
            const loc = (b.location || '').toLowerCase();
            const isGondola = loc.includes('gondola') || loc.includes('gôndola');
            const matches = b.name?.toLowerCase().includes(query.toLowerCase()) || 
                            b.brand?.toLowerCase().includes(query.toLowerCase());
            return isGondola && matches;
        });
    }, [batteries, query]);

    const handleDragStart = (e: React.DragEvent, id: string) => {
        e.dataTransfer.setData("battery-id", id);
        e.dataTransfer.effectAllowed = "copy";
    };

    return (
        <div className="w-72 bg-[#141414] border-r border-white/5 flex flex-col z-20 shadow-2xl">
            <div className="p-4 border-b border-white/5">
                <h3 className="text-sm font-black text-white uppercase tracking-widest mb-3">Estoque Gôndola</h3>
                <div className="relative">
                    <span className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                        <span className="material-icons text-gray-500 text-sm">search</span>
                    </span>
                    <input 
                        type="text" 
                        placeholder="Filtrar..." 
                        value={query}
                        onChange={e => setQuery(e.target.value)}
                        className="w-full bg-black/40 text-white pl-9 pr-3 py-2 rounded-lg border border-white/5 focus:border-[#EC4899] outline-none text-xs"
                    />
                </div>
            </div>
            <div className="flex-1 overflow-y-auto custom-scrollbar p-2 space-y-2">
                {gondolaItems.map(b => (
                    <div 
                        key={b.id}
                        draggable
                        onDragStart={(e) => handleDragStart(e, b.id)}
                        className="bg-white/5 p-3 rounded-xl border border-white/5 hover:bg-white/10 cursor-grab active:cursor-grabbing flex items-center gap-3"
                    >
                        <div className="w-8 h-8 rounded bg-black/40 flex items-center justify-center overflow-hidden">
                            {b.imageUrl ? <img src={b.imageUrl} className="w-full h-full object-cover" /> : <span className="material-icons text-xs text-gray-600">battery_std</span>}
                        </div>
                        <div className="flex-1 min-w-0">
                            <p className="text-xs font-bold text-white truncate">{b.name}</p>
                            <p className="text-[10px] text-gray-500">{b.quantity} un</p>
                        </div>
                        <span className="material-icons text-gray-600 text-sm">drag_indicator</span>
                    </div>
                ))}
            </div>
        </div>
    );
};

const GridBackground = () => (
    <div 
        className="absolute inset-0 pointer-events-none opacity-20"
        style={{
            backgroundImage: `
                linear-gradient(to right, #333 1px, transparent 1px),
                linear-gradient(to bottom, #333 1px, transparent 1px)
            `,
            backgroundSize: '128px 128px',
            transform: `translate(${GRID_CENTER_OFFSET}px, ${GRID_CENTER_OFFSET}px)` // Align with virtual center logic but simpler pattern
        }} 
    />
);