import 'package:sale_module/modules/data/datasource/local/sale_local_history_store.dart';
import 'package:sale_module/modules/data/datasource/remote/sale_remote_datasource.dart';
import 'package:sale_module/modules/domain/entities/register_sale_params.dart';
import 'package:sale_module/modules/domain/entities/sale_history.dart';
import 'package:sale_module/modules/domain/repositories/sale_repository.dart';
import 'package:stock_module/modules/data/datasource/remote/stock_inventory_remote_datasource.dart';

class SaleRepositoryImpl implements ISaleRepository {
  SaleRepositoryImpl(this._remote, this._local);

  final SaleRemoteDataSource _remote;
  final SaleLocalHistoryStore _local;

  @override
  Future<RegisterSaleResult> registerSale(RegisterSaleParams params) =>
      _remote.postInventorySale(params);

  @override
  Future<List<SaleHistoryRecord>> listSaleHistory(String branchId) async {
    final local = await _local.load(branchId);
    List<SaleHistoryRecord> api = [];
    try {
      api = await _remote.fetchSalesList(branchId: branchId);
    } catch (_) {}
    return _mergeHistory(api, local);
  }

  @override
  Future<SaleHistoryRecord> getSaleDetail({
    required String saleId,
    required String branchId,
  }) async {
    SaleHistoryRecord? remote;
    try {
      remote = await _remote.fetchSaleDetail(saleId: saleId, branchId: branchId);
    } catch (_) {
      remote = null;
    }
    final local = await _local.find(branchId, saleId);
    if (remote != null && remote.hasLines) return remote;
    if (local != null && local.hasLines) {
      final base = remote ?? local;
      return SaleHistoryRecord(
        saleId: base.saleId,
        branchId: base.branchId,
        occurredAt: remote?.occurredAt ?? local.occurredAt,
        isInternalUse: remote?.isInternalUse ?? local.isInternalUse,
        totalAmount: remote?.totalAmount ?? local.totalAmount,
        lines: local.lines,
        internalUsePurpose: remote?.internalUsePurpose ?? local.internalUsePurpose,
        outputProductName: remote?.outputProductName ?? local.outputProductName,
        outputQuantity: remote?.outputQuantity ?? local.outputQuantity,
      );
    }
    if (remote != null) return remote;
    if (local != null) return local;
    throw StockInventoryApiException('Venda não encontrada ou sem detalhes.');
  }

  @override
  Future<void> appendLocalSaleRecord(SaleHistoryRecord record) =>
      _local.append(record);

  static List<SaleHistoryRecord> _mergeHistory(
    List<SaleHistoryRecord> api,
    List<SaleHistoryRecord> local,
  ) {
    final map = <String, SaleHistoryRecord>{};
    for (final a in api) {
      map[a.saleId] = a;
    }
    for (final l in local) {
      final id = l.saleId;
      final cur = map[id];
      if (cur == null) {
        map[id] = l;
        continue;
      }
      if (!cur.hasLines && l.hasLines) {
        map[id] = SaleHistoryRecord(
          saleId: cur.saleId,
          branchId: cur.branchId,
          occurredAt: cur.occurredAt ?? l.occurredAt,
          isInternalUse: cur.isInternalUse || l.isInternalUse,
          totalAmount: cur.totalAmount ?? l.totalAmount,
          lines: l.lines,
          internalUsePurpose: cur.internalUsePurpose ?? l.internalUsePurpose,
          outputProductName: cur.outputProductName ?? l.outputProductName,
          outputQuantity: cur.outputQuantity ?? l.outputQuantity,
        );
      }
    }
    final list = map.values.toList();
    list.sort((a, c) {
      final ta = a.occurredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tb = c.occurredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return tb.compareTo(ta);
    });
    return list;
  }
}
