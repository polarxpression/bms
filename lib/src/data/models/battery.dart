import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum BatteryLocation { gondola, stock }

@immutable
class Battery {
  final String id;
  final String model;
  final String brand;
  final String? type;
  final num quantity;
  final int packSize;
  final String barcode;
  final bool? discontinued;
  final BatteryLocation? location;
  final String? imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastUsed;
  final num? score;
  final num? width;
  final num? height;
  final num? filesize;
  final num? duration;
  final String? pool;
  final bool? fav;
  final int? favcount;
  final String? source;
  final String? rating;
  final String? gondola;
  final int? gondolaCapacity;
  final String? gondolaName;

  const Battery({
    required this.id,
    required this.model,
    required this.brand,
    this.type,
    required this.quantity,
    required this.packSize,
    required this.barcode,
    this.discontinued,
    this.location,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
    this.lastUsed,
    this.score,
    this.width,
    this.height,
    this.filesize,
    this.duration,
    this.pool,
    this.fav,
    this.favcount,
    this.source,
    this.rating,
    this.gondola,
    this.gondolaCapacity,
    this.gondolaName,
  });

  factory Battery.fromJson(Map<String, dynamic> json) {
    return Battery(
      id: json['id'] as String,
      model: json['model'] as String,
      brand: json['brand'] as String,
      type: json['type'] as String?,
      quantity: json['quantity'] as num,
      packSize: json['packSize'] as int,
      barcode: json['barcode'] as String,
      discontinued: json['discontinued'] as bool?,
      location: json['location'] != null
          ? () {
              final loc = json['location'].toString().trim().toLowerCase();
              if (loc.contains('gondola') || loc.contains('gôndola')) {
                return BatteryLocation.gondola;
              }
              return BatteryLocation.stock;
            }()
          : null,
      imageUrl: json['imageUrl'] as String?,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
      lastUsed: (json['lastUsed'] as Timestamp?)?.toDate(),
      score: json['score'] as num?,
      width: json['width'] as num?,
      height: json['height'] as num?,
      filesize: json['filesize'] as num?,
      duration: json['duration'] as num?,
      pool: json['pool'] as String?,
      fav: json['fav'] as bool?,
      favcount: json['favcount'] as int?,
      source: json['source'] as String?,
      rating: json['rating'] as String?,
      gondola: json['gondola'] as String?,
      gondolaCapacity: json['gondolaCapacity'] as int?,
      gondolaName: json['gondolaName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'model': model,
      'brand': brand,
      'type': type,
      'quantity': quantity,
      'packSize': packSize,
      'barcode': barcode,
      'discontinued': discontinued,
      'location': location?.name,
      'imageUrl': imageUrl,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'lastUsed': lastUsed != null ? Timestamp.fromDate(lastUsed!) : null,
      'score': score,
      'width': width,
      'height': height,
      'filesize': filesize,
      'duration': duration,
      'pool': pool,
      'fav': fav,
      'favcount': favcount,
      'source': source,
      'rating': rating,
      'gondola': gondola,
      'gondolaCapacity': gondolaCapacity,
      'gondolaName': gondolaName,
    };
  }

  Battery copyWith({
    String? id,
    String? model,
    String? brand,
    String? type,
    num? quantity,
    int? packSize,
    String? barcode,
    bool? discontinued,
    BatteryLocation? location,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastUsed,
    num? score,
    num? width,
    num? height,
    num? filesize,
    num? duration,
    String? pool,
    bool? fav,
    int? favcount,
    String? source,
    String? rating,
    String? gondola,
    int? gondolaCapacity,
    String? gondolaName,
  }) {
    return Battery(
      id: id ?? this.id,
      model: model ?? this.model,
      brand: brand ?? this.brand,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      packSize: packSize ?? this.packSize,
      barcode: barcode ?? this.barcode,
      discontinued: discontinued ?? this.discontinued,
      location: location ?? this.location,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastUsed: lastUsed ?? this.lastUsed,
      score: score ?? this.score,
      width: width ?? this.width,
      height: height ?? this.height,
      filesize: filesize ?? this.filesize,
      duration: duration ?? this.duration,
      pool: pool ?? this.pool,
      fav: fav ?? this.fav,
      favcount: favcount ?? this.favcount,
      source: source ?? this.source,
      rating: rating ?? this.rating,
      gondola: gondola ?? this.gondola,
      gondolaCapacity: gondolaCapacity ?? this.gondolaCapacity,
      gondolaName: gondolaName ?? this.gondolaName,
    );
  }
}
