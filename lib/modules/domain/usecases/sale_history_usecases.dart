import 'package:sale_module/modules/domain/entities/sale_history.dart';
import 'package:sale_module/modules/domain/repositories/sale_repository.dart';

class LoadSaleHistoryUseCase {
  LoadSaleHistoryUseCase(this._repository);

  final ISaleRepository _repository;

  Future<List<SaleHistoryRecord>> call(String branchId) =>
      _repository.listSaleHistory(branchId);
}

class GetSaleDetailUseCase {
  GetSaleDetailUseCase(this._repository);

  final ISaleRepository _repository;

  Future<SaleHistoryRecord> call({
    required String saleId,
    required String branchId,
  }) =>
      _repository.getSaleDetail(saleId: saleId, branchId: branchId);
}

class AppendLocalSaleRecordUseCase {
  AppendLocalSaleRecordUseCase(this._repository);

  final ISaleRepository _repository;

  Future<void> call(SaleHistoryRecord record) =>
      _repository.appendLocalSaleRecord(record);
}
