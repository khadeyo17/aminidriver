class Vehicle {
  final int vehicleId;
  final int make;
  final int model;
  //final int categoryId;
  final String registrationNumber;
  final int year;
  final String? status;

  Vehicle({
    required this.vehicleId,
    required this.make,
    required this.model,
    //required this.categoryId,
    required this.registrationNumber,
    required this.year,
    this.status,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      vehicleId: json['vehicleId'],
      make: json['make'],
      model: json['model'],
      //categoryId: json['categoryId'],
      registrationNumber: json['registrationNumber'],
      year: json['year'],
      status: json['status'],
    );
  }
}
