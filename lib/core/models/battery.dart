import 'package:cloud_firestore/cloud_firestore.dart';

class Battery {
  String id;
  String name;
  String type;
  String brand;
  String model;
  String barcode;
  String imageUrl;
  int quantity;
  int lowStockThreshold;
  // NEW: Minimum stock threshold for external buying
  int minStockThreshold;
  DateTime purchaseDate;
  DateTime lastChanged;
  
  String voltage;
  String chemistry;
  String notes;
  DateTime? expiryDate;
  String location;
  int gondolaLimit;
  int packSize;
  
  // NEW: Track gondola quantity separately from stock
  int gondolaQuantity;
  bool discontinued;

  Battery({
    required this.id,
    required this.name,
    required this.type,
    required this.brand,
    required this.model,
    required this.barcode,
    this.imageUrl = '',
    required this.quantity,
    this.lowStockThreshold = 2,
    this.minStockThreshold = 0,
    required this.purchaseDate,
    required this.lastChanged,
    this.voltage = '',
    this.chemistry = '',
    this.notes = '',
    this.expiryDate,
    this.location = '',
    this.gondolaLimit = 0,
    this.packSize = 1,
    this.gondolaQuantity = 0,
    this.discontinued = false,
  });

  factory Battery.fromMap(Map<String, dynamic> data, String docId) {
    String brand = data['brand'] ?? '';
    String model = data['model'] ?? '';
    String type = data['type'] ?? '';
    
    String defaultName = brand.isNotEmpty || model.isNotEmpty 
        ? '$brand $model'.trim() 
        : (type.isNotEmpty ? 'Pilha $type' : 'Item sem nome');

    String loc = data['location'] ?? '';
    bool isGondolaLoc = loc.toLowerCase().contains('gondola') || loc.toLowerCase().contains('gôndola');
    
    int rawQty = data['quantity'] ?? 0;
    int rawGondolaQty = data['gondolaQuantity'] ?? 0;
    
    // MIGRATION FIX: If gondolaQuantity is missing OR 0, but location is Gondola,
    // and we have a positive main quantity, map the main quantity to gondolaQuantity.
    // This handles legacy data where 'quantity' represented the shelf count.
    if ((data['gondolaQuantity'] == null || rawGondolaQty == 0) && isGondolaLoc && rawQty > 0) {
      rawGondolaQty = rawQty;
      rawQty = 0;
    }

    return Battery(
      id: docId,
      name: (data['name'] == null || data['name'].toString().isEmpty || data['name'] == 'Unknown' || data['name'] == 'Unnamed') 
          ? defaultName 
          : data['name'],
      type: type.isEmpty ? 'AA' : type,
      brand: brand,
      model: model,
      barcode: data['barcode'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      quantity: rawQty,
      lowStockThreshold: data['lowStockThreshold'] ?? 2,
      minStockThreshold: data['minStockThreshold'] ?? 0,
      purchaseDate: (data['purchaseDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastChanged: (data['lastChanged'] as Timestamp?)?.toDate() ?? DateTime.now(),
      voltage: data['voltage'] ?? '',
      chemistry: data['chemistry'] ?? '',
      notes: data['notes'] ?? '',
      expiryDate: (data['expiryDate'] as Timestamp?)?.toDate(),
      location: loc,
      gondolaLimit: data['gondolaLimit'] ?? 0,
      packSize: data['packSize'] ?? 1,
      gondolaQuantity: rawGondolaQty,
      discontinued: data['discontinued'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'brand': brand,
      'model': model,
      'barcode': barcode,
      'imageUrl': imageUrl,
      'quantity': quantity,
      'lowStockThreshold': lowStockThreshold,
      'minStockThreshold': minStockThreshold,
      'purchaseDate': Timestamp.fromDate(purchaseDate),
      'lastChanged': Timestamp.fromDate(lastChanged),
      'voltage': voltage,
      'chemistry': chemistry,
      'notes': notes,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'location': location,
      'gondolaLimit': gondolaLimit,
      'packSize': packSize,
      'gondolaQuantity': gondolaQuantity,
      'discontinued': discontinued,
    };
  }
}