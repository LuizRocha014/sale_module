/// Finalidade do movimento quando [isInternalUse] é verdadeiro.
enum InternalUsePurpose {
  /// Baixa para consumo / uso da empresa (sem entrada em outro produto).
  company,

  /// Gera entrada no estoque de um produto (ex.: produção, montagem).
  newProduct,
}
