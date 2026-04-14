import 'package:sale_module/modules/domain/entities/register_sale_params.dart';
import 'package:sale_module/modules/domain/entities/sale_history.dart';

abstract class ISaleRepository {
  Future<RegisterSaleResult> registerSale(RegisterSaleParams params);

  /// Mescla vendas do servidor (`GET /api/inventory/sales`) com cache local.
  Future<List<SaleHistoryRecord>> listSaleHistory(String branchId);

  Future<SaleHistoryRecord> getSaleDetail({
    required String saleId,
    required String branchId,
  });

  /// Grava venda concluída neste aparelho (itens para consulta offline).
  Future<void> appendLocalSaleRecord(SaleHistoryRecord record);
}
