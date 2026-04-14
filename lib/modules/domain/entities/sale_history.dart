import 'package:stock_module/modules/data/models/api_parse.dart';

/// Linha de uma venda já registrada (leitura).
class SaleHistoryLine {
  SaleHistoryLine({
    required this.productId,
    this.productName,
    required this.quantity,
    this.unitPrice,
  });

  final String productId;
  final String? productName;
  final double quantity;
  final double? unitPrice;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'unitPrice': unitPrice,
      };

  factory SaleHistoryLine.fromJson(Map<String, dynamic> m) {
    return SaleHistoryLine(
      productId: _reqString(m, const ['productId', 'ProductId']),
      productName: _optString(m, const ['productName', 'ProductName', 'name', 'Name']),
      quantity: _reqDouble(m, const ['quantity', 'Quantity']),
      unitPrice: _optDouble(m, const ['unitPrice', 'UnitPrice', 'price', 'Price']),
    );
  }
}

/// Resumo ou detalhe de uma venda (`GET /api/inventory/sales` ou cache local).
class SaleHistoryRecord {
  SaleHistoryRecord({
    required this.saleId,
    required this.branchId,
    this.occurredAt,
    this.isInternalUse = false,
    this.totalAmount,
    this.lines,
    this.internalUsePurpose,
    this.outputProductName,
    this.outputQuantity,
  });

  final String saleId;
  final String branchId;
  final DateTime? occurredAt;
  final bool isInternalUse;
  final double? totalAmount;

  /// Quando null ou vazio, carregar com [GetSaleDetailUseCase].
  final List<SaleHistoryLine>? lines;

  /// `company` | `newProduct` quando [isInternalUse].
  final String? internalUsePurpose;

  final String? outputProductName;
  final double? outputQuantity;

  bool get hasLines => lines != null && lines!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'saleId': saleId,
        'branchId': branchId,
        'occurredAt': occurredAt?.toUtc().toIso8601String(),
        'isInternalUse': isInternalUse,
        'totalAmount': totalAmount,
        'lines': lines?.map((e) => e.toJson()).toList(),
        'internalUsePurpose': internalUsePurpose,
        'outputProductName': outputProductName,
        'outputQuantity': outputQuantity,
      };

  factory SaleHistoryRecord.fromLocalJson(Map<String, dynamic> m) {
    final linesRaw = m['lines'];
    List<SaleHistoryLine>? lines;
    if (linesRaw is List) {
      lines = linesRaw
          .map((e) => SaleHistoryLine.fromJson(asMap(e)))
          .toList();
    }
    return SaleHistoryRecord(
      saleId: _reqString(m, const ['saleId', 'SaleId']),
      branchId: _reqString(m, const ['branchId', 'BranchId']),
      occurredAt: _parseDate(m['occurredAt'] ?? m['at']),
      isInternalUse: m['isInternalUse'] == true,
      totalAmount: _optDouble(m, const ['totalAmount', 'TotalAmount', 'total', 'Total']),
      lines: lines,
      internalUsePurpose: _optString(m, const ['internalUsePurpose', 'InternalUsePurpose']),
      outputProductName: _optString(m, const ['outputProductName', 'OutputProductName']),
      outputQuantity: _optDouble(m, const ['outputQuantity', 'OutputQuantity']),
    );
  }
}

String _reqString(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return '';
}

String? _optString(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  return null;
}

double _reqDouble(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is num) return v.toDouble();
    if (v is String) {
      final p = double.tryParse(v.replaceAll(',', '.'));
      if (p != null) return p;
    }
  }
  return 0;
}

double? _optDouble(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is num) return v.toDouble();
    if (v is String) {
      final p = double.tryParse(v.replaceAll(',', '.'));
      if (p != null) return p;
    }
  }
  return null;
}

DateTime? _parseDate(dynamic v) {
  if (v is String) return DateTime.tryParse(v);
  return null;
}
