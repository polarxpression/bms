import { db } from "../firebase/client";
import { 
  collection, 
  onSnapshot, 
  doc, 
  updateDoc, 
  addDoc, 
  deleteDoc, 
  getDocs,
  query,
  orderBy,
  serverTimestamp
} from "firebase/firestore";
import type { Battery, HistoryEntry, BatteryMap, AppSettings } from "../types";

const COLLECTION_NAME = "batteries";
const HISTORY_COLLECTION = "history";
const MAPS_COLLECTION = "maps";
const SETTINGS_COLLECTION = "settings";
const NOTIFICATIONS_COLLECTION = "notifications";

export const batteryService = {
  subscribeToSettings: (callback: (settings: AppSettings) => void) => {
    return onSnapshot(doc(db, SETTINGS_COLLECTION, "config"), (snapshot) => {
      if (snapshot.exists()) {
        callback(snapshot.data() as AppSettings);
      } else {
        // Default fallbacks if document doesn't exist
        callback({
          defaultGondolaCapacity: 20,
          defaultMinStockThreshold: 10,
          daysToAnalyze: 90
        });
      }
    });
  },

  updateSettings: async (settings: Partial<AppSettings>) => {
    const ref = doc(db, SETTINGS_COLLECTION, "config");
    await updateDoc(ref, settings).catch(async () => {
        const { setDoc } = await import("firebase/firestore");
        await setDoc(ref, settings);
    });
  },

  subscribeToBatteries: (callback: (batteries: Battery[]) => void, onError?: (err: any) => void) => {
    // Simplified query: removal of orderBy to avoid index issues
    const q = query(collection(db, COLLECTION_NAME));
    console.log("Subscribing to batteries...");
    
    return onSnapshot(q, (snapshot) => {
      console.log(`Received ${snapshot.docs.length} batteries`);
      const batteries = snapshot.docs.map(doc => {
        const data = doc.data();
        // Fallback for name if missing (matching Flutter logic)
        const name = data.name || `${data.brand || ''} ${data.model || ''}`.trim() || 'Item sem nome';
        return {
          id: doc.id,
          ...data,
          name
        };
      }) as Battery[];
      
      // Sort in memory to avoid needing a Firestore index
      batteries.sort((a, b) => (a.brand || '').localeCompare(b.brand || '') || (a.model || '').localeCompare(b.model || ''));
      
      callback(batteries);
    }, (error) => {
        console.error("Firestore Subscribe Batteries Error:", error);
        if (onError) onError(error);
    });
  },

  updateBattery: async (id: string, data: Partial<Battery>) => {
    const ref = doc(db, COLLECTION_NAME, id);
    await updateDoc(ref, {
      ...data,
      lastChanged: serverTimestamp()
    });
  },

  addBattery: async (battery: Omit<Battery, "id">) => {
    const docRef = await addDoc(collection(db, COLLECTION_NAME), {
      ...battery,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp()
    });
    return docRef.id;
  },

  deleteBattery: async (id: string) => {
    await deleteDoc(doc(db, COLLECTION_NAME, id));
  },

  adjustQuantity: async (battery: Battery, delta: number, isGondola: boolean = false, source: string = "web") => {
    const ref = doc(db, COLLECTION_NAME, battery.id);
    const field = isGondola ? "gondolaQuantity" : "quantity";
    const currentVal = isGondola ? (battery.gondolaQuantity || 0) : (battery.quantity || 0);
    const newVal = Math.max(0, currentVal + delta);
    
    const limit = battery.gondolaLimit > 0 ? battery.gondolaLimit : 20;
    const finalVal = isGondola ? Math.min(newVal, limit) : newVal;

    await updateDoc(ref, {
      [field]: finalVal,
      lastChanged: serverTimestamp()
    });
    
    if (delta !== 0) {
      await addDoc(collection(db, HISTORY_COLLECTION), {
        batteryId: battery.id,
        batteryName: battery.name || `${battery.brand} ${battery.model}`,
        type: delta > 0 ? "in" : "out",
        location: isGondola ? "gondola" : "stock",
        quantity: Math.abs(delta),
        reason: "adjustment",
        source: source,
        timestamp: serverTimestamp()
      });
    }
  },

  moveToGondola: async (battery: Battery, amount: number) => {
    if (amount <= 0) return;
    const currentGondola = battery.gondolaQuantity || 0;
    const limit = battery.gondolaLimit > 0 ? battery.gondolaLimit : 20;
    const newGondola = Math.min(currentGondola + amount, limit);
    const currentStock = battery.quantity || 0;
    const newStock = Math.max(0, currentStock - amount);
    
    const ref = doc(db, COLLECTION_NAME, battery.id);
    await updateDoc(ref, {
      gondolaQuantity: newGondola,
      quantity: newStock,
      lastChanged: serverTimestamp()
    });

    const bName = battery.name || `${battery.brand} ${battery.model}`;

    await addDoc(collection(db, HISTORY_COLLECTION), {
      batteryId: battery.id,
      batteryName: bName,
      type: "in",
      location: "gondola",
      quantity: amount,
      reason: "restock",
      source: "web",
      timestamp: serverTimestamp()
    });
    
    await addDoc(collection(db, HISTORY_COLLECTION), {
      batteryId: battery.id,
      batteryName: bName,
      type: "out",
      location: "stock",
      quantity: amount,
      reason: "restock",
      source: "web",
      timestamp: serverTimestamp()
    });
  },

  getMonthlyConsumption: async (daysToAnalyze: number = 90) => {
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - daysToAnalyze);
    // Simple query first
    const q = query(collection(db, HISTORY_COLLECTION), orderBy("timestamp", "desc"));
    const snapshot = await getDocs(q);
    const totalOuts: Record<string, number> = {};
    
    snapshot.docs.forEach(doc => {
      const data = doc.data();
      const ts = data.timestamp?.toDate ? data.timestamp.toDate() : new Date(data.timestamp);
      if (!ts || ts < cutoff) return;
      if (data.type === 'out' && data.reason !== 'restock') {
        const bid = data.batteryId;
        if (bid) totalOuts[bid] = (totalOuts[bid] || 0) + (data.quantity || 0);
      }
    });

    const months = daysToAnalyze / 30.0;
    const consumption: Record<string, number> = {};
    Object.keys(totalOuts).forEach(bid => {
      consumption[bid] = totalOuts[bid] / (months || 1);
    });
    return consumption;
  },

  getExternalBuyList: (batteries: Battery[], consumption: Record<string, number>, settings: AppSettings) => {
    const groups: Record<string, Battery[]> = {};
    batteries.forEach(b => {
      if (b.discontinued) return;
      const key = b.barcode?.trim() || `name:${(b.brand || '').toLowerCase()}|${(b.model || '').toLowerCase()}`;
      if (!groups[key]) groups[key] = [];
      groups[key].push(b);
    });

    const buyList: Battery[] = [];
    Object.values(groups).forEach(items => {
      let totalStock = 0;
      let totalGondola = 0;
      let maxGondolaLimit = 0;
      let anyManual = false;
      let maxManualThreshold = 0;
      let groupMonthlyConsumption = 0;
      let primary = items[0];

      items.forEach(b => {
        const loc = (b.location || '').toLowerCase();
        const isGondola = loc.includes('gondola') || loc.includes('gôndola');
        if (!isGondola) totalStock += (b.quantity || 0);
        totalGondola += (b.gondolaQuantity || 0);
        groupMonthlyConsumption += consumption[b.id] || 0;
        if (!b.useDefaultMinStock) {
          anyManual = true;
          if ((b.minStockThreshold || 0) > maxManualThreshold) maxManualThreshold = b.minStockThreshold || 0;
        }
        if ((b.gondolaLimit || 0) > maxGondolaLimit) maxGondolaLimit = b.gondolaLimit || 0;
        if (primary.location !== 'Estoque' && b.location === 'Estoque') primary = b;
      });

      let effectiveThreshold = anyManual ? maxManualThreshold : settings.defaultMinStockThreshold;
      const dynamicThreshold = Math.ceil(groupMonthlyConsumption);
      if (dynamicThreshold > effectiveThreshold) effectiveThreshold = dynamicThreshold;

      if (totalStock <= effectiveThreshold) {
        buyList.push({
          ...primary,
          quantity: totalStock,
          gondolaQuantity: totalGondola,
          minStockThreshold: effectiveThreshold,
          gondolaLimit: maxGondolaLimit || settings.defaultGondolaCapacity
        });
      }
    });
    return buyList;
  },

  getRestockSuggestions: (batteries: Battery[], settings: AppSettings) => {
    const suggestions: Battery[] = [];

    // 1. Identify all items currently on the Gondola
    const gondolaItems = batteries.filter(b => {
      const loc = (b.location || '').toLowerCase();
      return loc.includes('gondola') || loc.includes('gôndola');
    });

    // 2. Create a map of Barcode -> Total Stock Quantity
    const stockByBarcode: Record<string, number> = {};
    batteries.forEach(b => {
      const loc = (b.location || '').toLowerCase();
      const isGondola = loc.includes('gondola') || loc.includes('gôndola');
      if (!isGondola && (b.quantity || 0) > 0) {
        const bc = (b.barcode || '').trim();
        if (bc) {
          stockByBarcode[bc] = (stockByBarcode[bc] || 0) + (b.quantity || 0);
        }
      }
    });

    // 3. Evaluate Gondola Items
    gondolaItems.forEach(b => {
      const limit = b.gondolaLimit > 0 ? b.gondolaLimit : settings.defaultGondolaCapacity;
      if (limit <= 0) return;

      // Condition: Equal or below half of limit
      if ((b.gondolaQuantity || 0) <= (limit / 2.0)) {
        const bc = (b.barcode || '').trim();
        const availableStock = stockByBarcode[bc] || 0;

        if (availableStock > 0) {
          suggestions.push({
            ...b,
            quantity: availableStock, // Show TOTAL available stock across all matching barcodes
            gondolaLimit: limit
          });
        }
      }
    });

    return suggestions.sort((a, b) => {
      const neededA = (a.gondolaLimit || 0) - (a.gondolaQuantity || 0);
      const neededB = (b.gondolaLimit || 0) - (b.gondolaQuantity || 0);
      return neededB - neededA;
    });
  },

  subscribeToMaps: (callback: (maps: BatteryMap[]) => void) => {
    const q = query(collection(db, MAPS_COLLECTION));
    return onSnapshot(q, (snapshot) => {
      console.log(`Received ${snapshot.docs.length} maps`);
      callback(snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })) as BatteryMap[]);
    }, (err) => console.error("Map Subscribe Error:", err));
  },

  subscribeToMapCells: (mapId: string, callback: (cells: Record<string, string>) => void) => {
    const q = query(collection(db, MAPS_COLLECTION, mapId, "cells"));
    return onSnapshot(q, (snapshot) => {
      console.log(`Received ${snapshot.docs.length} cells for map ${mapId}`);
      const cells: Record<string, string> = {};
      snapshot.docs.forEach(doc => {
        const data = doc.data();
        cells[`${data.x},${data.y}`] = data.batteryId;
      });
      callback(cells);
    }, (err) => console.error("Cells Subscribe Error:", err));
  },

  placeBatteryOnMap: async (mapId: string, x: number, y: number, batteryId: string) => {
    const docId = `cell_${x}_${y}`;
    const ref = doc(db, MAPS_COLLECTION, mapId, "cells", docId);
    const { setDoc } = await import("firebase/firestore");
    await setDoc(ref, { x, y, batteryId, updatedAt: serverTimestamp() });
  },

  removeBatteryFromMap: async (mapId: string, x: number, y: number) => {
    const docId = `cell_${x}_${y}`;
    await deleteDoc(doc(db, MAPS_COLLECTION, mapId, "cells", docId));
  },

  moveBatteryOnMap: async (mapId: string, fromX: number, fromY: number, toX: number, toY: number, batteryId: string) => {
    const fromDocId = `cell_${fromX}_${fromY}`;
    const toDocId = `cell_${toX}_${toY}`;
    const { writeBatch } = await import("firebase/firestore");
    const batch = writeBatch(db);

    const fromRef = doc(db, MAPS_COLLECTION, mapId, "cells", fromDocId);
    const toRef = doc(db, MAPS_COLLECTION, mapId, "cells", toDocId);

    batch.delete(fromRef);
    batch.set(toRef, { x: toX, y: toY, batteryId, updatedAt: serverTimestamp() });

    await batch.commit();
  },

  swapBatteriesOnMap: async (mapId: string, x1: number, y1: number, x2: number, y2: number, id1: string, id2: string) => {
    const docId1 = `cell_${x1}_${y1}`;
    const docId2 = `cell_${x2}_${y2}`;
    const { writeBatch } = await import("firebase/firestore");
    const batch = writeBatch(db);

    const ref1 = doc(db, MAPS_COLLECTION, mapId, "cells", docId1);
    const ref2 = doc(db, MAPS_COLLECTION, mapId, "cells", docId2);

    batch.set(ref1, { x: x1, y: y1, batteryId: id2, updatedAt: serverTimestamp() });
    batch.set(ref2, { x: x2, y: y2, batteryId: id1, updatedAt: serverTimestamp() });

    await batch.commit();
  },

  fetchHistory: async () => {
    const q = query(collection(db, HISTORY_COLLECTION), orderBy("timestamp", "desc"));
    const snapshot = await getDocs(q);
    return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })) as HistoryEntry[];
  },

  // Notification Methods
  subscribeToNotifications: (callback: (notifications: any[]) => void) => {
    const q = query(collection(db, NOTIFICATIONS_COLLECTION), orderBy("timestamp", "desc"));
    return onSnapshot(q, (snapshot) => {
      callback(snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })));
    });
  },

  markNotificationAsRead: async (id: string) => {
    const ref = doc(db, NOTIFICATIONS_COLLECTION, id);
    await updateDoc(ref, { isRead: true });
  },

  clearAllNotifications: async () => {
    const q = query(collection(db, NOTIFICATIONS_COLLECTION));
    const snapshot = await getDocs(q);
    const { writeBatch } = await import("firebase/firestore");
    const batch = writeBatch(db);
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
  },

  // Map Helper
  findBatteryInMaps: async (batteryId: string): Promise<any[]> => {
    const mapsSnapshot = await getDocs(collection(db, MAPS_COLLECTION));
    const results: any[] = [];
    
    for (const mapDoc of mapsSnapshot.docs) {
      const cellsSnapshot = await getDocs(collection(db, MAPS_COLLECTION, mapDoc.id, "cells"));
      const found = cellsSnapshot.docs.some(cellDoc => cellDoc.data().batteryId === batteryId);
      if (found) {
        results.push({
          id: mapDoc.id,
          name: mapDoc.data().name,
          purpose: mapDoc.data().purpose
        });
      }
    }
    return results;
  }
};
