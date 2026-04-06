enum VehicleCategory {
  passenger,
  matatu,
  cargo,
  movers,
  ambulance,
  breakdown,
  waterBowser,
  exhauster,
  carhire,
  mechanical,
  machinery,
}

extension VehicleCategoryExtension on VehicleCategory {
  String get displayName {
    switch (this) {
      case VehicleCategory.passenger:
        return 'Ride Booking';
      case VehicleCategory.matatu:
        return 'Matatu/Bus';
      case VehicleCategory.cargo:
        return 'Cargo Transport';
      case VehicleCategory.movers:
        return 'Movers';
      case VehicleCategory.ambulance:
        return 'Ambulance';
      case VehicleCategory.breakdown:
        return 'Breakdown Services';
      case VehicleCategory.waterBowser:
        return 'Water Bowser';
      case VehicleCategory.exhauster:
        return 'Exhauster';
      case VehicleCategory.carhire:
        return 'Car Hire';
      case VehicleCategory.mechanical:
        return 'Mechanical Services';
      case VehicleCategory.machinery:
        return 'Machinery';
    }
  }

  String get apiValue => name; // Will be sent as string like "movers"
}

class VehicleCategoryModel {
  final int id;
  final VehicleCategory type;

  VehicleCategoryModel({required this.id, required this.type});
  factory VehicleCategoryModel.fromJson(Map<String, dynamic> json) {
    final int index = json['categoryType'] ?? -1;
    return VehicleCategoryModel(
      id: json['id'],
      type:
          parseVehicleCategory(index) ?? VehicleCategory.passenger, // Fallback
    );
  }
  // factory VehicleCategoryModel.fromJson(Map<String, dynamic> json) {
  //   return VehicleCategoryModel(
  //     id: json['id'],
  //     type: VehicleCategory.values[json['categoryType']??-1],
  //   );
  // }
  // //VehicleCategory? get categoryEnum => parseVehicleCategory(type);
  //   VehicleCategory? get categoryEnum = parseVehicleCategory(index) ?? VehicleCategory.passenger, // Fallback

  String get displayName => type.displayName;
  String get apiValue => type.apiValue;
}

// factory VehicleCategoryModel.fromJson(Map<String, dynamic> json) {
//   final int index = json['categoryType'] ?? -1;
//   return VehicleCategoryModel(
//     id: json['id'],
//     type: parseVehicleCategory(index) ?? VehicleCategory.passenger, // Fallback
//   );
// }
VehicleCategory? parseVehicleCategory(int index) {
  if (index < 0 || index >= VehicleCategory.values.length) {
    return null;
  }
  return VehicleCategory.values[index];
}
