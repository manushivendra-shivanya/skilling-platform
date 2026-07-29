import 'simulation_content.dart';
import 'simulation_enums.dart' show DispositionType;

enum OperationalDraftStatus { draft, submitted }

enum DocumentSource { purchaseOrder, deliveryNote, both }

enum DocumentFindingType {
  quantityMismatch,
  unexpectedItem,
  missingItem,
  documentMismatch,
  other,
}

class DocumentFinding {
  const DocumentFinding({
    required this.id,
    required this.sourceDocument,
    required this.itemReference,
    required this.findingType,
    required this.learnerNotes,
    required this.createdAt,
    required this.updatedAt,
    required this.revisionNumber,
  });

  final String id;
  final DocumentSource sourceDocument;
  final String itemReference;
  final DocumentFindingType findingType;
  final String learnerNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revisionNumber;

  DocumentFinding copyWith({
    DocumentSource? sourceDocument,
    String? itemReference,
    DocumentFindingType? findingType,
    String? learnerNotes,
    DateTime? updatedAt,
    int? revisionNumber,
  }) => DocumentFinding(
    id: id,
    sourceDocument: sourceDocument ?? this.sourceDocument,
    itemReference: itemReference ?? this.itemReference,
    findingType: findingType ?? this.findingType,
    learnerNotes: learnerNotes ?? this.learnerNotes,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    revisionNumber: revisionNumber ?? this.revisionNumber,
  );

  JsonMap toJson() => {
    'id': id,
    'sourceDocument': sourceDocument.name,
    'itemReference': itemReference,
    'findingType': findingType.name,
    'learnerNotes': learnerNotes,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'revisionNumber': revisionNumber,
  };

  factory DocumentFinding.fromJson(JsonMap json) => DocumentFinding(
    id: json.string('id'),
    sourceDocument: DocumentSource.values.byName(json.string('sourceDocument')),
    itemReference: json.string('itemReference'),
    findingType: DocumentFindingType.values.byName(json.string('findingType')),
    learnerNotes: json.optionalString('learnerNotes') ?? '',
    createdAt: DateTime.parse(json.string('createdAt')),
    updatedAt: DateTime.parse(json.string('updatedAt')),
    revisionNumber: json.integer('revisionNumber'),
  );
}

class DocumentReviewDraft {
  const DocumentReviewDraft({
    required this.attemptId,
    required this.taskId,
    required this.findings,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.submittedAt,
  });

  final String attemptId;
  final String taskId;
  final List<DocumentFinding> findings;
  final OperationalDraftStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? submittedAt;

  DocumentReviewDraft copyWith({
    List<DocumentFinding>? findings,
    OperationalDraftStatus? status,
    DateTime? updatedAt,
    DateTime? submittedAt,
  }) => DocumentReviewDraft(
    attemptId: attemptId,
    taskId: taskId,
    findings: findings ?? this.findings,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    submittedAt: submittedAt ?? this.submittedAt,
  );

  JsonMap toJson() => {
    'attemptId': attemptId,
    'taskId': taskId,
    'findings': findings.map((item) => item.toJson()).toList(),
    'status': status.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'submittedAt': submittedAt?.toUtc().toIso8601String(),
  };

  factory DocumentReviewDraft.fromJson(JsonMap json) => DocumentReviewDraft(
    attemptId: json.string('attemptId'),
    taskId: json.string('taskId'),
    findings: json
        .mapList('findings')
        .map(DocumentFinding.fromJson)
        .toList(growable: false),
    status: OperationalDraftStatus.values.byName(json.string('status')),
    createdAt: DateTime.parse(json.string('createdAt')),
    updatedAt: DateTime.parse(json.string('updatedAt')),
    submittedAt: _optionalDate(json.optionalString('submittedAt')),
  );
}

enum CountMethod { individual, sealedCarton, estimated }

class ReceivingCountEntry {
  const ReceivingCountEntry({
    required this.id,
    required this.cartonId,
    required this.sku,
    required this.enteredQuantity,
    required this.countMethod,
    required this.learnerNotes,
    required this.createdAt,
    required this.updatedAt,
    required this.revisionNumber,
  });

  final String id;
  final String cartonId;
  final String sku;
  final int enteredQuantity;
  final CountMethod countMethod;
  final String learnerNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revisionNumber;

  ReceivingCountEntry copyWith({
    int? enteredQuantity,
    CountMethod? countMethod,
    String? learnerNotes,
    DateTime? updatedAt,
    int? revisionNumber,
  }) => ReceivingCountEntry(
    id: id,
    cartonId: cartonId,
    sku: sku,
    enteredQuantity: enteredQuantity ?? this.enteredQuantity,
    countMethod: countMethod ?? this.countMethod,
    learnerNotes: learnerNotes ?? this.learnerNotes,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    revisionNumber: revisionNumber ?? this.revisionNumber,
  );

  JsonMap toJson() => {
    'id': id,
    'cartonId': cartonId,
    'sku': sku,
    'enteredQuantity': enteredQuantity,
    'countMethod': countMethod.name,
    'learnerNotes': learnerNotes,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'revisionNumber': revisionNumber,
  };

  factory ReceivingCountEntry.fromJson(JsonMap json) => ReceivingCountEntry(
    id: json.string('id'),
    cartonId: json.string('cartonId'),
    sku: json.string('sku'),
    enteredQuantity: json.integer('enteredQuantity'),
    countMethod: CountMethod.values.byName(json.string('countMethod')),
    learnerNotes: json.optionalString('learnerNotes') ?? '',
    createdAt: DateTime.parse(json.string('createdAt')),
    updatedAt: DateTime.parse(json.string('updatedAt')),
    revisionNumber: json.integer('revisionNumber'),
  );
}

class ReceivingCountDraft {
  const ReceivingCountDraft({
    required this.attemptId,
    required this.taskId,
    required this.shipmentConfirmed,
    required this.countEntries,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.submittedAt,
  });

  final String attemptId;
  final String taskId;
  final bool shipmentConfirmed;
  final List<ReceivingCountEntry> countEntries;
  final OperationalDraftStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? submittedAt;

  ReceivingCountDraft copyWith({
    bool? shipmentConfirmed,
    List<ReceivingCountEntry>? countEntries,
    OperationalDraftStatus? status,
    DateTime? updatedAt,
    DateTime? submittedAt,
  }) => ReceivingCountDraft(
    attemptId: attemptId,
    taskId: taskId,
    shipmentConfirmed: shipmentConfirmed ?? this.shipmentConfirmed,
    countEntries: countEntries ?? this.countEntries,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    submittedAt: submittedAt ?? this.submittedAt,
  );

  JsonMap toJson() => {
    'attemptId': attemptId,
    'taskId': taskId,
    'shipmentConfirmed': shipmentConfirmed,
    'countEntries': countEntries.map((item) => item.toJson()).toList(),
    'status': status.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'submittedAt': submittedAt?.toUtc().toIso8601String(),
  };

  factory ReceivingCountDraft.fromJson(JsonMap json) => ReceivingCountDraft(
    attemptId: json.string('attemptId'),
    taskId: json.string('taskId'),
    shipmentConfirmed: json.boolean('shipmentConfirmed'),
    countEntries: json
        .mapList('countEntries')
        .map(ReceivingCountEntry.fromJson)
        .toList(growable: false),
    status: OperationalDraftStatus.values.byName(json.string('status')),
    createdAt: DateTime.parse(json.string('createdAt')),
    updatedAt: DateTime.parse(json.string('updatedAt')),
    submittedAt: _optionalDate(json.optionalString('submittedAt')),
  );
}

enum CartonFinding {
  compliant('compliant'),
  packagingDamage('packaging_damage'),
  nearExpiry('near_expiry'),
  incorrectSku('incorrect_sku'),
  quantityShortage('quantity_shortage'),
  unreadableBarcode('unreadable_barcode');

  const CartonFinding(this.wireName);
  final String wireName;

  static CartonFinding fromWireName(String value) =>
      values.firstWhere((item) => item.wireName == value);
}

class CartonInspectionEntry {
  const CartonInspectionEntry({
    required this.id,
    required this.cartonId,
    required this.finding,
    required this.learnerNotes,
    required this.createdAt,
    required this.updatedAt,
    required this.revisionNumber,
  });

  final String id;
  final String cartonId;
  final CartonFinding finding;
  final String learnerNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revisionNumber;

  CartonInspectionEntry copyWith({
    CartonFinding? finding,
    String? learnerNotes,
    DateTime? updatedAt,
    int? revisionNumber,
  }) => CartonInspectionEntry(
    id: id,
    cartonId: cartonId,
    finding: finding ?? this.finding,
    learnerNotes: learnerNotes ?? this.learnerNotes,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    revisionNumber: revisionNumber ?? this.revisionNumber,
  );

  JsonMap toJson() => {
    'id': id,
    'cartonId': cartonId,
    'finding': finding.wireName,
    'learnerNotes': learnerNotes,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'revisionNumber': revisionNumber,
  };

  factory CartonInspectionEntry.fromJson(JsonMap json) => CartonInspectionEntry(
    id: json.string('id'),
    cartonId: json.string('cartonId'),
    finding: CartonFinding.fromWireName(json.string('finding')),
    learnerNotes: json.optionalString('learnerNotes') ?? '',
    createdAt: DateTime.parse(json.string('createdAt')),
    updatedAt: DateTime.parse(json.string('updatedAt')),
    revisionNumber: json.integer('revisionNumber'),
  );
}

enum BarcodeStatus { readable, unreadable }

class BarcodeScanEntry {
  const BarcodeScanEntry({
    required this.id,
    required this.cartonId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.revisionNumber,
  });

  final String id;
  final String cartonId;
  final BarcodeStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revisionNumber;

  BarcodeScanEntry copyWith({
    BarcodeStatus? status,
    DateTime? updatedAt,
    int? revisionNumber,
  }) => BarcodeScanEntry(
    id: id,
    cartonId: cartonId,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    revisionNumber: revisionNumber ?? this.revisionNumber,
  );

  JsonMap toJson() => {
    'id': id,
    'cartonId': cartonId,
    'status': status.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'revisionNumber': revisionNumber,
  };

  factory BarcodeScanEntry.fromJson(JsonMap json) => BarcodeScanEntry(
    id: json.string('id'),
    cartonId: json.string('cartonId'),
    status: BarcodeStatus.values.byName(json.string('status')),
    createdAt: DateTime.parse(json.string('createdAt')),
    updatedAt: DateTime.parse(json.string('updatedAt')),
    revisionNumber: json.integer('revisionNumber'),
  );
}

class InspectionDraft {
  const InspectionDraft({
    required this.attemptId,
    required this.cartonInspections,
    required this.barcodeScans,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.submittedAt,
  });

  final String attemptId;
  final List<CartonInspectionEntry> cartonInspections;
  final List<BarcodeScanEntry> barcodeScans;
  final OperationalDraftStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? submittedAt;

  InspectionDraft copyWith({
    List<CartonInspectionEntry>? cartonInspections,
    List<BarcodeScanEntry>? barcodeScans,
    OperationalDraftStatus? status,
    DateTime? updatedAt,
    DateTime? submittedAt,
  }) => InspectionDraft(
    attemptId: attemptId,
    cartonInspections: cartonInspections ?? this.cartonInspections,
    barcodeScans: barcodeScans ?? this.barcodeScans,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    submittedAt: submittedAt ?? this.submittedAt,
  );

  JsonMap toJson() => {
    'attemptId': attemptId,
    'cartonInspections': cartonInspections
        .map((item) => item.toJson())
        .toList(),
    'barcodeScans': barcodeScans.map((item) => item.toJson()).toList(),
    'status': status.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'submittedAt': submittedAt?.toUtc().toIso8601String(),
  };

  factory InspectionDraft.fromJson(JsonMap json) => InspectionDraft(
    attemptId: json.string('attemptId'),
    cartonInspections: json
        .mapList('cartonInspections')
        .map(CartonInspectionEntry.fromJson)
        .toList(growable: false),
    barcodeScans: json
        .mapList('barcodeScans')
        .map(BarcodeScanEntry.fromJson)
        .toList(growable: false),
    status: OperationalDraftStatus.values.byName(json.string('status')),
    createdAt: DateTime.parse(json.string('createdAt')),
    updatedAt: DateTime.parse(json.string('updatedAt')),
    submittedAt: _optionalDate(json.optionalString('submittedAt')),
  );
}

class DispositionEntry {
  const DispositionEntry({
    required this.id,
    required this.cartonId,
    required this.disposition,
    required this.reason,
    required this.createdAt,
    required this.updatedAt,
    required this.revisionNumber,
  });

  final String id;
  final String cartonId;
  final DispositionType disposition;
  final String reason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revisionNumber;

  DispositionEntry copyWith({
    DispositionType? disposition,
    String? reason,
    DateTime? updatedAt,
    int? revisionNumber,
  }) => DispositionEntry(
    id: id,
    cartonId: cartonId,
    disposition: disposition ?? this.disposition,
    reason: reason ?? this.reason,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    revisionNumber: revisionNumber ?? this.revisionNumber,
  );

  JsonMap toJson() => {
    'id': id,
    'cartonId': cartonId,
    'disposition': disposition.wireName,
    'reason': reason,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'revisionNumber': revisionNumber,
  };

  factory DispositionEntry.fromJson(JsonMap json) => DispositionEntry(
    id: json.string('id'),
    cartonId: json.string('cartonId'),
    disposition: DispositionType.fromWireName(json.string('disposition')),
    reason: json.optionalString('reason') ?? '',
    createdAt: DateTime.parse(json.string('createdAt')),
    updatedAt: DateTime.parse(json.string('updatedAt')),
    revisionNumber: json.integer('revisionNumber'),
  );
}

class DispositionDraft {
  const DispositionDraft({
    required this.attemptId,
    required this.entries,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.submittedAt,
  });

  final String attemptId;
  final List<DispositionEntry> entries;
  final OperationalDraftStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? submittedAt;

  DispositionDraft copyWith({
    List<DispositionEntry>? entries,
    OperationalDraftStatus? status,
    DateTime? updatedAt,
    DateTime? submittedAt,
  }) => DispositionDraft(
    attemptId: attemptId,
    entries: entries ?? this.entries,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    submittedAt: submittedAt ?? this.submittedAt,
  );

  JsonMap toJson() => {
    'attemptId': attemptId,
    'entries': entries.map((item) => item.toJson()).toList(),
    'status': status.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'submittedAt': submittedAt?.toUtc().toIso8601String(),
  };

  factory DispositionDraft.fromJson(JsonMap json) => DispositionDraft(
    attemptId: json.string('attemptId'),
    entries: json
        .mapList('entries')
        .map(DispositionEntry.fromJson)
        .toList(growable: false),
    status: OperationalDraftStatus.values.byName(json.string('status')),
    createdAt: DateTime.parse(json.string('createdAt')),
    updatedAt: DateTime.parse(json.string('updatedAt')),
    submittedAt: _optionalDate(json.optionalString('submittedAt')),
  );
}

class DiscrepancyReportDraft {
  const DiscrepancyReportDraft({
    required this.attemptId,
    this.shortageRecorded = false,
    this.unauthorizedSkuRecorded = false,
    this.damageRecorded = false,
    this.barcodeIssueRecorded = false,
    this.nearExpiryRecorded = false,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.submittedAt,
  });

  final String attemptId;
  final bool shortageRecorded;
  final bool unauthorizedSkuRecorded;
  final bool damageRecorded;
  final bool barcodeIssueRecorded;
  final bool nearExpiryRecorded;
  final OperationalDraftStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? submittedAt;

  DiscrepancyReportDraft copyWith({
    bool? shortageRecorded,
    bool? unauthorizedSkuRecorded,
    bool? damageRecorded,
    bool? barcodeIssueRecorded,
    bool? nearExpiryRecorded,
    OperationalDraftStatus? status,
    DateTime? updatedAt,
    DateTime? submittedAt,
  }) => DiscrepancyReportDraft(
    attemptId: attemptId,
    shortageRecorded: shortageRecorded ?? this.shortageRecorded,
    unauthorizedSkuRecorded:
        unauthorizedSkuRecorded ?? this.unauthorizedSkuRecorded,
    damageRecorded: damageRecorded ?? this.damageRecorded,
    barcodeIssueRecorded: barcodeIssueRecorded ?? this.barcodeIssueRecorded,
    nearExpiryRecorded: nearExpiryRecorded ?? this.nearExpiryRecorded,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    submittedAt: submittedAt ?? this.submittedAt,
  );

  JsonMap toJson() => {
    'attemptId': attemptId,
    'shortageRecorded': shortageRecorded,
    'unauthorizedSkuRecorded': unauthorizedSkuRecorded,
    'damageRecorded': damageRecorded,
    'barcodeIssueRecorded': barcodeIssueRecorded,
    'nearExpiryRecorded': nearExpiryRecorded,
    'status': status.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'submittedAt': submittedAt?.toUtc().toIso8601String(),
  };

  factory DiscrepancyReportDraft.fromJson(JsonMap json) =>
      DiscrepancyReportDraft(
        attemptId: json.string('attemptId'),
        shortageRecorded: json.boolean('shortageRecorded'),
        unauthorizedSkuRecorded: json.boolean('unauthorizedSkuRecorded'),
        damageRecorded: json.boolean('damageRecorded'),
        barcodeIssueRecorded: json.boolean('barcodeIssueRecorded'),
        nearExpiryRecorded: json.boolean('nearExpiryRecorded'),
        status: OperationalDraftStatus.values.byName(json.string('status')),
        createdAt: DateTime.parse(json.string('createdAt')),
        updatedAt: DateTime.parse(json.string('updatedAt')),
        submittedAt: _optionalDate(json.optionalString('submittedAt')),
      );
}

DateTime? _optionalDate(String? value) =>
    value == null ? null : DateTime.parse(value);
