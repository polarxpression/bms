import { useEffect, useState, useRef, useMemo } from 'react';
import { batteryService } from '../services/batteryService';
import type { Battery, BatteryMap } from '../types';
import { CellDetailsModal } from './CellDetailsModal';
import { MapManagerModal } from './MapManagerModal';
import { BatteryPickerModal } from './BatteryPickerModal';

const CELL_SIZE = 120;
const CELL_SPACING = 8;
const GRID_CENTER_OFFSET = 2000; // Virtual center for infinite feel

export const MapComponent = () => {
  const [maps, setMaps] = useState<BatteryMap[]>([]);
  const [currentMap, setCurrentMap] = useState<BatteryMap | null>(null);
  const [cells, setCells] = useState<Record<string, string>>({}); // "x,y" -> batteryId
  const [batteries, setBatteries] = useState<Battery[]>([]);
  const [loading, setLoading] = useState(true);
  
  // Modal State
  const [selectedCell, setSelectedCell] = useState<{ x: number; y: number; battery: Battery } | null>(null);
  const [showMapManager, setShowMapManager] = useState(false);
  const [pickerTargetCell, setPickerTargetCell] = useState<{x: number, y: number} | null>(null);
  const [highlightedBatteryId, setHighlightedBatteryId] = useState<string | null>(null);
  const [isSidebarCollapsed, setIsSidebarCollapsed] = useState(false);


  // Viewport State
  const [transform, setTransform] = useState({ x: -GRID_CENTER_OFFSET, y: -GRID_CENTER_OFFSET, scale: 1 });
  const [isDragging, setIsDragging] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);
  const dragStart = useRef({ x: 0, y: 0 });

  useEffect(() => {
    const unsubBatteries = batteryService.subscribeToBatteries(setBatteries);
    const unsubMaps = batteryService.subscribeToMaps((data) => {
        setMaps(data);
        const params = new URLSearchParams(window.location.search);
        const mapId = params.get('mapId');
        if (mapId) {
            setCurrentMap(data.find(m => m.id === mapId) || (data.length > 0 ? data[0] : null));
        } else if (data.length > 0 && !currentMap) {
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
        const unsubCells = batteryService.subscribeToMapCells(currentMap.id, (cellData) => {
            setCells(cellData);
            // Must be inside here to run AFTER cells are loaded
            handleHighlightParam(cellData);
        });
        return () => unsubCells();
    }
  }, [currentMap]);

  const focusOnCell = (cellX: number, cellY: number) => {
    if (!containerRef.current) return;
    const { width, height } = containerRef.current.getBoundingClientRect();
    
    const targetX = GRID_CENTER_OFFSET + (cellX * (CELL_SIZE + CELL_SPACING)) + (CELL_SIZE / 2);
    const targetY = GRID_CENTER_OFFSET + (cellY * (CELL_SIZE + CELL_SPACING)) + (CELL_SIZE / 2);

    setTransform(prev => ({
        ...prev,
        x: -targetX * prev.scale + width / 2,
        y: -targetY * prev.scale + height / 2,
    }));
  };

  const handleHighlightParam = (currentCells: Record<string, string>) => {
      const params = new URLSearchParams(window.location.search);
      const batteryId = params.get('highlight');
      if (batteryId) {
          setHighlightedBatteryId(batteryId);
          const foundKey = Object.keys(currentCells).find(key => currentCells[key] === batteryId);
          if (foundKey) {
              const [x, y] = foundKey.split(',').map(Number);
              // Use timeout to allow rendering before focusing
              setTimeout(() => focusOnCell(x, y), 100);
          }
          // Clean up URL
          window.history.replaceState({}, document.title, window.location.pathname);
      }
  };

  // Viewport Logic
  const handleMouseDown = (e: React.MouseEvent) => {
    if (e.button !== 0) return; // Only left click
    const target = e.target as HTMLElement;
    // Don't drag if interacting with a button, select, or a cell element
    if (target.closest('button, select, .map-cell')) {
        return;
    }
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

  const handleDropOnOccupied = async (e: React.DragEvent, targetX: number, targetY: number) => {
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
      } catch (err) {
          console.error("Drop error", err);
      }
  };

  const handleDropOnEmpty = async (e: React.DragEvent, targetX: number, targetY: number) => {
      e.preventDefault();
      if (!currentMap) return;
      
      try {
          const data = JSON.parse(e.dataTransfer.getData("application/json"));
          const fromX = data.x;
          const fromY = data.y;
          const fromId = data.batteryId;
          await batteryService.moveBatteryOnMap(currentMap.id, fromX, fromY, targetX, targetY, fromId);
      } catch (err) {
          // This happens if the drop source is not a map cell (e.g. from a picker)
          // We do nothing here, the click handler will open the picker.
          console.log("Drop on empty from non-map source, opening picker.");
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

  // Modal Action Handlers
  const handleAdjustGondola = async (amount: number) => {
      if (!selectedCell) return;
      await batteryService.adjustGondolaQuantity(selectedCell.battery, amount, 'map');
  };

  const handleRemoveFromMap = async () => {
    if (!selectedCell || !currentMap) return;
    await batteryService.removeBatteryFromMap(currentMap.id, selectedCell.x, selectedCell.y);
    setSelectedCell(null); // Close modal
  };

  const handleEdit = () => {
      if (!selectedCell) return;
      // TODO: Implement battery editing form/modal
      alert(`Editing ${selectedCell.battery.name}`);
  };

  const handlePlaceBattery = async (batteryId: string) => {
    if (!pickerTargetCell || !currentMap) return;
    await batteryService.placeBatteryOnMap(currentMap.id, pickerTargetCell.x, pickerTargetCell.y, batteryId);
    setPickerTargetCell(null);
  }


  return (
    <div className="flex h-screen bg-[#050505] overflow-hidden">
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
                    onClick={() => setShowMapManager(true)}
                    className="bg-[#141414]/90 backdrop-blur text-white p-2 rounded-xl border border-white/10 shadow-xl hover:bg-white/10"
                    title="Gerenciar Mapas"
                >
                    <span className="material-icons">edit_location_alt</span>
                </button>
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
                    className="absolute origin-top-left"
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
                        const isHighlighted = highlightedBatteryId === batteryId;
                        return (
                            <div
                                key={`${x},${y}`}
                                className={`absolute bg-[#1E1E1E] rounded-xl border shadow-lg group cursor-pointer transition-all duration-300
                                    ${isHighlighted ? 'border-pink-500 border-4 z-20 shadow-pink-500/50' : 'border-blue-500/30 hover:border-green-400 hover:z-10'}
                                `}
                                style={{
                                    left: GRID_CENTER_OFFSET + x * (CELL_SIZE + CELL_SPACING),
                                    top: GRID_CENTER_OFFSET + y * (CELL_SIZE + CELL_SPACING),
                                    width: CELL_SIZE,
                                    height: CELL_SIZE,
                                }}
                                draggable
                                onDragStart={(e) => handleDragStart(e, x, y, batteryId)}
                                onDragOver={(e) => e.preventDefault()}
                                onDrop={(e) => handleDropOnOccupied(e, x, y)}
                                onClick={() => {
                                    setSelectedCell({ x, y, battery });
                                    if(isHighlighted) setHighlightedBatteryId(null);
                                }}
                            >
                                <div className="w-full h-full p-2 flex flex-col items-center justify-center pointer-events-none">
                                    <span className="text-[10px] font-black text-blue-400 uppercase truncate w-full text-center">{battery.brand} • {battery.type}</span>
                                    <div className="flex-1 flex items-center justify-center w-full my-1">
                                        {battery.imageUrl ? (
                                            <img src={battery.imageUrl} className="max-h-full object-contain" />
                                        ) : (
                                            <span className="material-icons text-gray-600 text-3xl">battery_std</span>
                                        )}
                                    </div>
                                    <span className="text-xs font-bold text-white truncate w-full text-center">{battery.model}</span>
                                    <span className="text-[9px] text-gray-500">Pack x{battery.packSize} • Gôn: {battery.gondolaQuantity ?? 0}</span>
                                </div>
                                <div className="absolute top-1 right-1 material-icons text-white/20 text-base pointer-events-none">drag_indicator</div>
                            </div>
                        );
                    })}

                    {/* Render Empty Spots */}
                    {potentialSpots.map(({ x, y }) => (
                        <div
                            key={`empty_${x},${y}`}
                            className="absolute rounded-xl border-2 border-dashed border-white/10 hover:border-blue-500 hover:bg-blue-500/10 transition-colors flex items-center justify-center group cursor-pointer"
                            style={{
                                left: GRID_CENTER_OFFSET + x * (CELL_SIZE + CELL_SPACING),
                                top: GRID_CENTER_OFFSET + y * (CELL_SIZE + CELL_SPACING),
                                width: CELL_SIZE,
                                height: CELL_SIZE,
                            }}
                            onClick={() => setPickerTargetCell({x, y})}
                            onDragOver={(e) => e.preventDefault()}
                            onDrop={(e) => handleDropOnEmpty(e, x, y)}
                        >
                            <span className="material-icons text-white/20 group-hover:text-white/80 transition-colors">add</span>
                        </div>
                    ))}
                </div>
            </div>
        </div>

        {selectedCell && (
            <CellDetailsModal
                battery={selectedCell.battery}
                onClose={() => setSelectedCell(null)}
                onAdjustGondola={handleAdjustGondola}
                onRemove={handleRemoveFromMap}
                onEdit={handleEdit}
            />
        )}
        {showMapManager && (
            <MapManagerModal
                maps={maps}
                currentMapId={currentMap?.id || null}
                onClose={() => setShowMapManager(false)}
                onCreate={batteryService.createMap}
                onUpdate={batteryService.updateMap}
                onDelete={batteryService.deleteMap}
                onSelect={(id) => {
                    setCurrentMap(maps.find(m => m.id === id) || null);
                    setShowMapManager(false);
                }}
            />
        )}
        {pickerTargetCell && (
            <BatteryPickerModal 
                batteries={batteries}
                onClose={() => setPickerTargetCell(null)}
                onSelect={handlePlaceBattery}
            />
        )}
    </div>
  );
};

const GridBackground = () => (
    <div 
        className="absolute inset-0 pointer-events-none opacity-10"
        style={{
            backgroundImage: `
                linear-gradient(to right, #888 1px, transparent 1px),
                linear-gradient(to bottom, #888 1px, transparent 1px)
            `,
            backgroundSize: '128px 128px',
            // The transform should be handled by the parent's scale, this is just a pattern
        }} 
    />
);