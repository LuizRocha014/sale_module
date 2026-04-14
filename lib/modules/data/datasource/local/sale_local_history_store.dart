import 'dart:convert';

import 'package:sale_module/modules/domain/entities/sale_history.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stock_module/modules/data/models/api_parse.dart';

/// Últimas vendas registradas neste aparelho (com itens), por filial.
class SaleLocalHistoryStore {
  static const _key = 'sale_module_local_sales_v1';
  static const _maxPerBranch = 40;

  Future<List<SaleHistoryRecord>> load(String branchId) async {
    final b = branchId.trim();
    if (b.isEmpty) return [];
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return [];
      final out = <SaleHistoryRecord>[];
      for (final e in decoded) {
        if (e is! Map) continue;
        final r = SaleHistoryRecord.fromLocalJson(asMap(e));
        if (r.branchId == b && r.saleId.isNotEmpty) out.add(r);
      }
      out.sort((a, c) {
        final ta = a.occurredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tb = c.occurredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<void> append(SaleHistoryRecord record) async {
    final b = record.branchId.trim();
    final id = record.saleId.trim();
    if (b.isEmpty || id.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    final existing = await loadAll(p);
    final next = existing.where((e) => !(e.branchId == b && e.saleId == id)).toList();
    next.insert(0, record);
    final trimmed = _trimPerBranch(next);
    await p.setString(
      _key,
      jsonEncode(trimmed.map((e) => e.toJson()).toList()),
    );
  }

  Future<SaleHistoryRecord?> find(String branchId, String saleId) async {
    final b = branchId.trim();
    final id = saleId.trim();
    if (b.isEmpty || id.isEmpty) return null;
    final list = await load(b);
    for (final r in list) {
      if (r.saleId == id) return r;
    }
    return null;
  }

  Future<List<SaleHistoryRecord>> loadAll(SharedPreferences p) async {
    final raw = p.getString(_key);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return [];
      return decoded
          .map((e) => SaleHistoryRecord.fromLocalJson(asMap(e)))
          .where((r) => r.saleId.isNotEmpty && r.branchId.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<SaleHistoryRecord> _trimPerBranch(List<SaleHistoryRecord> all) {
    final byBranch = <String, List<SaleHistoryRecord>>{};
    for (final r in all) {
      byBranch.putIfAbsent(r.branchId, () => []).add(r);
    }
    final out = <SaleHistoryRecord>[];
    for (final entry in byBranch.entries) {
      var list = entry.value;
      list.sort((a, c) {
        final ta = a.occurredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tb = c.occurredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });
      if (list.length > _maxPerBranch) {
        list = list.sublist(0, _maxPerBranch);
      }
      out.addAll(list);
    }
    return out;
  }
}
