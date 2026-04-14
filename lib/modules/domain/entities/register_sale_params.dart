import 'package:sale_module/modules/domain/entities/internal_use_purpose.dart';

/// Linha enviada em [RegisterSaleParams] para `POST /api/inventory/sales`.
class RegisterSaleLine {
  RegisterSaleLine({
    required this.productId,
    required this.quantity,
    this.unitPrice,
  });

  final String productId;
  final double quantity;
  final double? unitPrice;
}

/// Parâmetros de registro de venda (baixa de estoque no servidor).
class RegisterSaleParams {
  RegisterSaleParams({
    required this.branchId,
    required this.lines,
    this.isInternalUse = false,
    this.internalUsePurpose,
    this.outputProductId,
    this.outputQuantity,
  });

  final String branchId;
  final List<RegisterSaleLine> lines;

  /// Uso interno da loja (granel, porções, produção).
  final bool isInternalUse;

  /// Só quando [isInternalUse] é true (ignorado caso contrário).
  final InternalUsePurpose? internalUsePurpose;

  /// Produto que recebe a entrada no estoque quando [internalUsePurpose] é [InternalUsePurpose.newProduct].
  final String? outputProductId;

  /// Quantidade a adicionar no estoque do [outputProductId].
  final double? outputQuantity;
}

class RegisterSaleResult {
  RegisterSaleResult({this.saleId, this.stockMovementId});

  final String? saleId;
  final String? stockMovementId;
}
