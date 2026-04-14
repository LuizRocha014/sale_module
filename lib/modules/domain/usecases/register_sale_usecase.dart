import 'package:sale_module/modules/domain/entities/register_sale_params.dart';
import 'package:sale_module/modules/domain/repositories/sale_repository.dart';

class RegisterSaleUseCase {
  RegisterSaleUseCase(this._repository);

  final ISaleRepository _repository;

  Future<RegisterSaleResult> call(RegisterSaleParams params) => _repository.registerSale(params);
}
