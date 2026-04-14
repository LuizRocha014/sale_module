import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sale_module/modules/domain/entities/internal_use_purpose.dart';
import 'package:sale_module/modules/domain/entities/register_sale_params.dart';
import 'package:sale_module/modules/domain/entities/sale_history.dart';
import 'package:stock_module/modules/data/datasource/remote/stock_inventory_remote_datasource.dart';
import 'package:stock_module/modules/data/models/api_parse.dart';
import 'package:stock_module/modules/data/stock_api_settings.dart';

class SaleRemoteDataSource {
  SaleRemoteDataSource({required this.settings});

  final StockApiSettings settings;
  final http.Client _client = http.Client();

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = settings.normalizedBase;
    final u = Uri.parse('$base$path');
    if (query == null || query.isEmpty) return u;
    return u.replace(queryParameters: query);
  }

  Map<String, String> _headers() {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final t = settings.accessToken?.trim();
    if (t != null && t.isNotEmpty) {
      h['Authorization'] = t.toLowerCase().startsWith('bearer ') ? t : 'Bearer $t';
    }
    return h;
  }

  void _throwIfError(http.Response r, String context) {
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    String msg = 'HTTP ${r.statusCode}';
    try {
      final body = jsonDecode(r.body);
      if (body is Map && body['error'] != null) msg = '$msg: ${body['error']}';
    } catch (_) {
      if (r.body.isNotEmpty) {
        msg = '$msg — ${r.body.length > 120 ? '${r.body.substring(0, 120)}…' : r.body}';
      }
    }
    throw StockInventoryApiException('$context: $msg');
  }

  Future<RegisterSaleResult> postInventorySale(RegisterSaleParams params) async {
    final body = <String, dynamic>{
      'branchId': params.branchId,
      'isInternalUse': params.isInternalUse,
      'lines': params.lines
          .map(
            (e) => <String, dynamic>{
              'productId': e.productId,
              'quantity': e.quantity,
              'unitPrice': e.unitPrice,
            },
          )
          .toList(),
    };
    if (params.isInternalUse && params.internalUsePurpose != null) {
      body['internalUsePurpose'] = params.internalUsePurpose!.name;
      if (params.internalUsePurpose == InternalUsePurpose.newProduct) {
        if (params.outputProductId != null) {
          body['outputProductId'] = params.outputProductId;
        }
        if (params.outputQuantity != null) {
          body['outputQuantity'] = params.outputQuantity;
        }
      }
    }
    final r = await _client.post(
      _uri('/api/inventory/sales'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    _throwIfError(r, 'POST /api/inventory/sales');
    if (r.body.isEmpty) return RegisterSaleResult();
    final decoded = jsonDecode(r.body);
    if (decoded is! Map<String, dynamic>) return RegisterSaleResult();
    return RegisterSaleResult(
      saleId: mapString(decoded, const ['saleId', 'SaleId']),
      stockMovementId: mapString(decoded, const ['stockMovementId', 'StockMovementId']),
    );
  }

  /// `GET /api/inventory/sales?branchId=` — contrato esperado: lista de vendas.
  Future<List<SaleHistoryRecord>> fetchSalesList({required String branchId}) async {
    final r = await _client.get(
      _uri('/api/inventory/sales', {'branchId': branchId}),
      headers: _headers(),
    );
    _throwIfError(r, 'GET /api/inventory/sales');
    if (r.body.trim().isEmpty) return [];
    final list = decodeJsonList(r.body);
    final out = <SaleHistoryRecord>[];
    for (final e in list) {
      final m = asMap(e);
      if (m.isEmpty) continue;
      final rec = _parseSaleMap(m, branchId);
      if (rec.saleId.isNotEmpty) out.add(rec);
    }
    return out;
  }

  /// `GET /api/inventory/sales/{saleId}?branchId=`
  Future<SaleHistoryRecord> fetchSaleDetail({
    required String saleId,
    required String branchId,
  }) async {
    final id = Uri.encodeComponent(saleId);
    final r = await _client.get(
      _uri('/api/inventory/sales/$id', {'branchId': branchId}),
      headers: _headers(),
    );
    _throwIfError(r, 'GET /api/inventory/sales/$id');
    if (r.body.trim().isEmpty) {
      throw StockInventoryApiException('Resposta vazia do servidor.');
    }
    final decoded = jsonDecode(r.body);
    final Map<String, dynamic> m;
    if (decoded is Map<String, dynamic>) {
      m = decoded;
    } else if (decoded is Map) {
      m = Map<String, dynamic>.from(decoded);
    } else {
      m = {};
    }
    if (m.isEmpty) {
      throw StockInventoryApiException('Resposta inválida.');
    }
    final rec = _parseSaleMap(m, branchId);
    if (rec.saleId.isEmpty) {
      throw StockInventoryApiException('Identificador da venda não encontrado na resposta.');
    }
    return rec;
  }

  SaleHistoryRecord _parseSaleMap(Map<String, dynamic> root, String defaultBranchId) {
    var m = root;
    final nested = root['sale'] ?? root['data'] ?? root['Sale'];
    if (nested is Map) {
      m = Map<String, dynamic>.from(nested);
    }

    final saleId = mapString(m, const ['saleId', 'SaleId', 'id', 'Id']) ??
        mapString(root, const ['saleId', 'SaleId', 'id', 'Id']) ??
        '';
    final branch = mapString(m, const ['branchId', 'BranchId']) ??
        mapString(root, const ['branchId', 'BranchId']) ??
        defaultBranchId;

    final linesRaw = m['lines'] ?? m['Lines'] ?? m['items'] ?? m['Items'] ?? root['lines'];
    final lines = _parseLineList(linesRaw);

    final occurredAt = mapDate(m, const [
          'createdAt',
          'CreatedAt',
          'occurredAt',
          'OccurredAt',
          'date',
          'Date',
        ]) ??
        mapDate(root, const ['createdAt', 'CreatedAt']);

    final isInternal = _readBool(m, const ['isInternalUse', 'IsInternalUse']) ||
        _readBool(root, const ['isInternalUse', 'IsInternalUse']);

    final total = mapNum(m, const ['total', 'Total', 'totalAmount', 'TotalAmount'])?.toDouble() ??
        mapNum(root, const ['total', 'Total', 'totalAmount', 'TotalAmount'])?.toDouble();

    final purpose = mapString(m, const ['internalUsePurpose', 'InternalUsePurpose']) ??
        mapString(root, const ['internalUsePurpose', 'InternalUsePurpose']);
    final outName = mapString(m, const ['outputProductName', 'OutputProductName']) ??
        mapString(root, const ['outputProductName', 'OutputProductName']);
    final outQty = mapNum(m, const ['outputQuantity', 'OutputQuantity'])?.toDouble() ??
        mapNum(root, const ['outputQuantity', 'OutputQuantity'])?.toDouble();

    return SaleHistoryRecord(
      saleId: saleId,
      branchId: branch.isEmpty ? defaultBranchId : branch,
      occurredAt: occurredAt,
      isInternalUse: isInternal,
      totalAmount: total,
      lines: lines.isEmpty ? null : lines,
      internalUsePurpose: purpose,
      outputProductName: outName,
      outputQuantity: outQty,
    );
  }

  List<SaleHistoryLine> _parseLineList(dynamic raw) {
    if (raw is! List || raw.isEmpty) return [];
    final out = <SaleHistoryLine>[];
    for (final e in raw) {
      final m = asMap(e);
      if (m.isEmpty) continue;
      final pid = mapString(m, const ['productId', 'ProductId']) ?? '';
      final qty = mapNum(m, const ['quantity', 'Quantity'])?.toDouble() ?? 0;
      if (pid.isEmpty && qty <= 0) continue;
      out.add(
        SaleHistoryLine(
          productId: pid.isEmpty ? '—' : pid,
          productName: mapString(m, const ['productName', 'ProductName', 'name', 'Name']),
          quantity: qty,
          unitPrice: mapNum(m, const ['unitPrice', 'UnitPrice', 'price', 'Price'])?.toDouble(),
        ),
      );
    }
    return out;
  }

  bool _readBool(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is bool) return v;
      if (v is String) {
        final t = v.trim().toLowerCase();
        if (t == 'true' || t == '1') return true;
      }
      if (v is num) return v != 0;
    }
    return false;
  }
}
