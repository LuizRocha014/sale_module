/// Item do carrinho na tela de vendas (antes de montar [RegisterSaleLine]).
class SaleCartLine {
  SaleCartLine({
    required this.productId,
    required this.productName,
    required this.quantity,
    this.unitPrice,
    this.imageUrl,
  });

  final String productId;
  final String productName;
  double quantity;
  double? unitPrice;

  /// URL ou caminho local (igual ao estoque).
  final String? imageUrl;
}
