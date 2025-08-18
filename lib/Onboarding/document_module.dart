// class DocumentModel {
//   final int id;
//   final DocumentType documentType;
//   final String filePath;
//   final DocumentStatus status;
//   final DateTime dateCreated;

//   DocumentModel({
//     required this.id,
//     required this.documentType,
//     required this.filePath,
//     required this.status,
//     required this.dateCreated,
//   });

//   factory DocumentModel.fromJson(Map<String, dynamic> json) {
//     return DocumentModel(
//       id: json['id'],
//       documentType: _parseDocumentType(json['documentType']),
//       filePath: json['filePath'],
//       status: _parseDocumentStatus(json['status']),
//       dateCreated: DateTime.parse(json['dateCreated']),
//     );
//   }

//   static DocumentType _parseDocumentType(String value) {
//     return DocumentType.values.firstWhere(
//       (e) => e.name.toLowerCase() == value.toLowerCase(),
//       orElse: () => DocumentType.otherDocuments,
//     );
//   }

//   static DocumentStatus _parseDocumentStatus(String value) {
//     return DocumentStatus.values.firstWhere(
//       (e) => e.name.toLowerCase() == value.toLowerCase(),
//       orElse: () => DocumentStatus.underReview,
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'id': id,
//       'documentType': documentType.name,
//       'filePath': filePath,
//       'status': status.name,
//       'dateCreated': dateCreated.toIso8601String(),
//     };
//   }
// }

// enum DocumentType {
//   profilePic,
//   idFront,
//   idBack,
//   drivingLicense,
//   policeClearance,
//   psvBadge,
//   logbook,
//   vehiclePicture,
//   insuranceCover,
//   otherDocuments,
//   psvCertificate,
//   healthCertificate,
// }

// enum DocumentStatus { underReview, approved, rejected }
class DocumentModel {
  final String id;
  final DocumentType documentType;
  final String filePath;
  final DocumentStatus status;
  final DateTime dateCreated;

  DocumentModel({
    required this.id,
    required this.documentType,
    required this.filePath,
    required this.status,
    required this.dateCreated,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'],
      documentType: _parseDocumentType(json['documentType']),
      filePath: json['filePath'],
      status: _parseDocumentStatus(json['status']),
      dateCreated: DateTime.parse(json['dateCreated']),
    );
  }

  static DocumentType _parseDocumentType(dynamic value) {
    if (value is int) {
      return DocumentType.values[value]; // assumes ordinal value matches
    } else if (value is String) {
      return DocumentType.values.firstWhere(
        (e) => e.name.toLowerCase() == value.toLowerCase(),
        orElse: () => DocumentType.otherDocuments,
      );
    } else {
      return DocumentType.otherDocuments;
    }
  }

  // static DocumentType _parseDocumentType(String value) {
  //   return DocumentType.values.firstWhere(
  //     (e) => e.name.toLowerCase() == value.toLowerCase(),
  //     orElse: () => DocumentType.otherDocuments,
  //   );
  // }
  static DocumentStatus _parseDocumentStatus(dynamic value) {
    if (value is int) {
      return DocumentStatus.values[value];
    } else if (value is String) {
      return DocumentStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == value.toLowerCase(),
        orElse: () => DocumentStatus.underReview,
      );
    } else {
      return DocumentStatus.underReview;
    }
  }
  // static DocumentStatus _parseDocumentStatus(String value) {
  //   return DocumentStatus.values.firstWhere(
  //     (e) => e.name.toLowerCase() == value.toLowerCase(),
  //     orElse: () => DocumentStatus.underReview,
  //   );
  // }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'documentType': documentType.name,
      'filePath': filePath,
      'status': status.name,
      'dateCreated': dateCreated.toIso8601String(),
    };
  }

  /// Returns a readable label for the given DocumentStatus
  //   static String getStatusLabel(DocumentStatus status) {
  //     switch (status) {
  //       case DocumentStatus.approved:
  //         return 'Approved';
  //       case DocumentStatus.rejected:
  //         return 'Rejected';
  //       case DocumentStatus.underReview:
  //       default:
  //         return 'Under Review';
  //     }
  //   }
}

enum DocumentType {
  profilePic,
  idFront,
  idBack,
  drivingLicense,
  policeClearance,
  psvBadge,
  logbook,
  vehiclePicture,
  insuranceCover,
  otherDocuments,
  psvCertificate,
  healthCertificate,
  CertificateOfIncorporation,
}

enum DocumentStatus { underReview, approved, rejected }

extension DocumentStatusExtension on DocumentStatus {
  String get label {
    switch (this) {
      case DocumentStatus.approved:
        return 'Approved';
      case DocumentStatus.rejected:
        return 'Rejected';
      case DocumentStatus.underReview:
      default:
        return 'Under Review';
    }
  }
}
