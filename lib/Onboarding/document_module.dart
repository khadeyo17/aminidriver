class DocumentModel {
  final String id;
  final int documentType;
  final String filePath;
  final String status;
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
      documentType: (json['documentType']),
      filePath: json['filePath'],
      // status: (json['status']),
      status: json['status'].toString(),
      dateCreated: DateTime.parse(json['dateCreated']),
    );
  }

  // static DocumentType _parseDocumentType(dynamic value) {
  //   if (value is int) {
  //     return DocumentType.values[value]; // assumes ordinal value matches
  //   } else if (value is String) {
  //     return DocumentType.values.firstWhere(
  //       (e) => e.name.toLowerCase() == value.toLowerCase(),
  //       orElse: () => DocumentType.otherDocuments,
  //     );
  //   } else {
  //     return DocumentType.otherDocuments;
  //   }
  // }

  // static DocumentStatus _parseDocumentStatus(dynamic value) {
  //   if (value is int) {
  //     return DocumentStatus.values[value];
  //   } else if (value is String) {
  //     return DocumentStatus.values.firstWhere(
  //       (e) => e.name.toLowerCase() == value.toLowerCase(),
  //       orElse: () => DocumentStatus.notUploaded,
  //     );
  //   } else {
  //     return DocumentStatus.underReview;
  //   }
  // }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'documentType': documentType,
      'filePath': filePath,
      'status': status,
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

// enum DocumentStatus { underReview, approved, rejected, notUploaded }

// extension DocumentStatusExtension on DocumentStatus {
//   String get label {
//     switch (this) {
//       case DocumentStatus.approved:
//         return 'Approved';
//       case DocumentStatus.rejected:
//         return 'Rejected';
//       case DocumentStatus.underReview:
//       default:
//         return 'Under Review';
//     }
//   }
// }
