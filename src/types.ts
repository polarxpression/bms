export enum BatteryLocation {
  Gondola = 'gondola',
  Stock = 'stock',
}

export enum SortOption {
  Name = 'name',
  Brand = 'brand',
  Type = 'type',
  StockQty = 'stockQty',
  GondolaQty = 'gondolaQty',
}

export interface Battery {
  id: string;
  name?: string;
  model: string;
  brand: string;
  type?: string;
  quantity: number; // Stock quantity
  gondolaQuantity: number;
  packSize: number;
  barcode: string;
  discontinued?: boolean;
  location?: string;
  imageUrl?: string;
  createdAt?: any; // Timestamp or Date
  updatedAt?: any; // Timestamp or Date
  lastUsed?: any; // Timestamp or Date
  
  // Dimensions / Specs
  width?: number;
  height?: number;
  filesize?: number;
  duration?: number;
  voltage?: string;
  chemistry?: string;

  // Metadata
  score?: number;
  pool?: string;
  fav?: boolean;
  favcount?: number;
  source?: string;
  rating?: string;
  notes?: string;
  
  // Business Logic
  gondolaLimit: number;
  minStockThreshold: number;
  useDefaultMinStock?: boolean;
  purchaseDate?: any;
  lastChanged?: any;
  expiryDate?: any;
  linkedBatteryId?: string;
  
  // Legacy / Other
  gondolaName?: string;
}

export interface HistoryEntry {
  id: string;
  batteryId: string;
  batteryName: string;
  type: 'in' | 'out';
  location: string;
  quantity: number;
  reason: string;
  source: string;
  timestamp: any;
}

export interface BatteryMap {
  id: string;
  name: string;
  purpose: string;
  createdAt: any;
}

export interface MapCell {
  x: number;
  y: number;
  batteryId: string;
  updatedAt: any;
}

export interface AppSettings {
  defaultGondolaCapacity: number;
  defaultMinStockThreshold: number;
  daysToAnalyze: number;
  imgbbApiKey?: string;
}

export interface AppNotification {
  id: string;
  title: string;
  message: string;
  timestamp: any;
  isRead: boolean;
  type?: 'update' | 'reminder' | 'system';
  actionUrl?: string;
}
