import 'package:componentes_lr/componentes_lr.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:sale_module/modules/domain/entities/internal_use_purpose.dart';
import 'package:sale_module/modules/domain/entities/register_sale_params.dart';
import 'package:sale_module/modules/domain/entities/sale_cart_line.dart';
import 'package:sale_module/modules/domain/entities/sale_history.dart';
import 'package:sale_module/modules/domain/usecases/register_sale_usecase.dart';
import 'package:sale_module/modules/domain/usecases/sale_history_usecases.dart';
import 'package:stock_module/modules/data/datasource/remote/stock_inventory_remote_datasource.dart';
import 'package:stock_module/modules/domain/entities/product_stock_detail_entity.dart';
import 'package:stock_module/modules/domain/entities/stock_entry_params.dart';
import 'package:stock_module/modules/domain/entities/stock_product_summary_entity.dart';
import 'package:stock_module/modules/domain/repositories/stock_inventory_repository.dart';
import 'package:stock_module/modules/domain/usecases/stock_inventory_usecases.dart';

/// Produto agregado por filial (soma dos lotes ativos).
class SaleProductRow {
  SaleProductRow({
    required this.productId,
    required this.productName,
    required this.available,
    this.saleLabel,
    this.imageUrl,
    this.referenceUnitPrice,
  });

  final String productId;
  final String productName;
  final double available;
  final String? saleLabel;

  /// Primeira imagem encontrada entre os lotes (mesma origem que o estoque).
  final String? imageUrl;

  /// Preço de venda numérico obtido do rótulo da lista (ex.: `R$ 12,34`), para subtotal/total quando o usuário não digita preço.
  final double? referenceUnitPrice;
}

/// Interpreta rótulos monetários do estoque (`asMoney` → `R$ 12,34`).
double? parseSalePriceLabel(String? label) {
  if (label == null) return null;
  final t = label.trim();
  if (t.isEmpty) return null;
  final m = RegExp(r'(\d+)\s*,\s*(\d{2})\s*$').firstMatch(t);
  if (m != null) {
    final whole = double.tryParse(m.group(1)!);
    final frac = int.tryParse(m.group(2)!);
    if (whole != null && frac != null) return whole + frac / 100.0;
  }
  final cleaned = t.replaceAll(RegExp(r'[^\d,.-]'), '').replaceAll('.', '').replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

class SaleHomeController extends GetxController {
  SaleHomeController({this.initialBranchId});

  /// Quando não for nulo, tem precedência sobre [Get.arguments].
  final String? initialBranchId;

  final rows = <StockProductSummaryEntity>[].obs;
  final cart = <SaleCartLine>[].obs;
  final filterQuery = ''.obs;
  final isLoading = false.obs;
  final isSubmitting = false.obs;
  final errorMessage = RxnString();
  final isInternalUse = false.obs;

  /// Só quando [isInternalUse] é true.
  final internalUsePurpose = InternalUsePurpose.company.obs;

  final outputProductId = RxnString();
  final outputProductName = RxnString();

  /// Lote de destino da produção (`null` = novo lote; senão `batchId` em [StockEntryParams.targetBatchId]).
  final outputTargetBatchId = RxnString();

  /// Quantidade a adicionar no estoque do produto de saída (modo [InternalUsePurpose.newProduct]).
  late final TextEditingController outputStockQtyCtrl;

  String? _branchId;

  /// Filial usada nas consultas e no `POST /api/inventory/sales` (definida fora desta tela).
  String? get resolvedBranchId => _branchId;

  LoadStockInventoryUseCase get _loadInventory =>
      instanceManager.get<LoadStockInventoryUseCase>();
  /// Mesmo caminho da entrada manual (`StockHomeController` → `registerEntry` → `POST /api/inventory/entries`).
  IStockInventoryRepository get _stockInventoryRepo =>
      instanceManager.get<IStockInventoryRepository>();
  RegisterSaleUseCase get _registerSale => instanceManager.get<RegisterSaleUseCase>();
  LoadSaleHistoryUseCase get _loadSaleHistory =>
      instanceManager.get<LoadSaleHistoryUseCase>();
  GetSaleDetailUseCase get _getSaleDetail => instanceManager.get<GetSaleDetailUseCase>();
  AppendLocalSaleRecordUseCase get _appendLocalSale =>
      instanceManager.get<AppendLocalSaleRecordUseCase>();

  List<SaleProductRow> get groupedProducts {
    filterQuery.value;
    final q = filterQuery.value.trim().toLowerCase();
    var list = rows
        .map(
          (r) => SaleProductRow(
            productId: r.productId,
            productName: r.productName,
            available: r.totalQuantity.toDouble(),
            saleLabel: r.saleLabel,
            imageUrl: r.imageUrl,
            referenceUnitPrice: parseSalePriceLabel(r.saleLabel),
          ),
        )
        .toList();
    list.sort((a, b) => a.productName.compareTo(b.productName));
    if (q.isNotEmpty) {
      list = list
          .where(
            (p) =>
                p.productName.toLowerCase().contains(q) ||
                p.productId.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  double availableFor(String productId) {
    for (final r in rows) {
      if (r.productId == productId) {
        return r.totalQuantity.toDouble();
      }
    }
    return 0;
  }

  static String? _branchIdFromArguments() {
    final a = Get.arguments;
    if (a is String && a.trim().isNotEmpty) return a.trim();
    if (a is Map) {
      final id = a['branchId'] ?? a['BranchId'];
      if (id is String && id.trim().isNotEmpty) return id.trim();
    }
    return null;
  }

  @override
  void onInit() {
    super.onInit();
    outputStockQtyCtrl = TextEditingController(text: '1');
    final fromWidget = initialBranchId?.trim();
    _branchId = (fromWidget != null && fromWidget.isNotEmpty)
        ? fromWidget
        : _branchIdFromArguments();
    if (_branchId == null || _branchId!.isEmpty) {
      errorMessage.value =
          'Filial não configurada. Abra esta tela com branchId (argumento da rota ou parâmetro SaleHomePage).';
      return;
    }
    refreshInventory();
  }

  @override
  void onClose() {
    outputStockQtyCtrl.dispose();
    super.onClose();
  }

  void setInternalUse(bool value) {
    isInternalUse.value = value;
    if (!value) {
      _resetInternalUseExtras();
    }
  }

  void setInternalUsePurpose(InternalUsePurpose purpose) {
    internalUsePurpose.value = purpose;
    if (purpose == InternalUsePurpose.company) {
      outputProductId.value = null;
      outputProductName.value = null;
      outputTargetBatchId.value = null;
      outputStockQtyCtrl.text = '1';
    }
  }

  void setOutputProduct({required String productId, required String productName}) {
    outputProductId.value = productId;
    outputProductName.value = productName;
    outputTargetBatchId.value = null;
  }

  /// Usado após o sheet de confirmação de uso interno (produção): define produto, qtd e lote de destino.
  void applyInternalProductionSelection({
    required String productId,
    required String productName,
    required String qtyText,
    String? targetBatchId,
  }) {
    internalUsePurpose.value = InternalUsePurpose.newProduct;
    outputProductId.value = productId;
    outputProductName.value = productName;
    outputTargetBatchId.value = targetBatchId;
    outputStockQtyCtrl.text = qtyText.trim();
  }

  /// Lotes ativos do produto acabado (produção), para escolher onde somar a quantidade.
  Future<List<StockBatchDetailEntity>> loadActiveBatchesForOutputProduct(String productId) async {
    final br = _branchId;
    if (br == null || br.isEmpty) return [];
    try {
      final d = await _stockInventoryRepo.getProductStockDetail(productId, branchId: br);
      final active = d.batches.where((b) => b.active).toList();
      active.sort((a, b) {
        final ae = a.expirationDate;
        final be = b.expirationDate;
        if (ae == null && be == null) return 0;
        if (ae == null) return 1;
        if (be == null) return -1;
        return ae.compareTo(be);
      });
      return active;
    } catch (_) {
      return [];
    }
  }

  void _resetInternalUseExtras() {
    internalUsePurpose.value = InternalUsePurpose.company;
    outputProductId.value = null;
    outputProductName.value = null;
    outputTargetBatchId.value = null;
    outputStockQtyCtrl.text = '1';
  }

  String cartPanelTitle() {
    if (!isInternalUse.value) return 'Carrinho';
    return 'Carrinho · uso interno';
  }

  Future<void> refreshInventory() async {
    final b = _branchId;
    if (b == null || b.isEmpty) return;
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final list = await _loadInventory(branchId: b);
      rows.assignAll(list);
    } on StockInventoryApiException catch (e) {
      errorMessage.value = e.message;
      rows.clear();
    } catch (e) {
      errorMessage.value = e.toString();
      rows.clear();
    } finally {
      isLoading.value = false;
    }
  }

  /// Adiciona quantidade ao carrinho; [unitPrice] pode ser null (API aceita).
  void addOrIncreaseLine({
    required String productId,
    required String productName,
    required double quantity,
    double? unitPrice,
    String? imageUrl,
  }) {
    if (quantity <= 0) return;
    final avail = availableFor(productId);
    final idx = cart.indexWhere((c) => c.productId == productId);
    final current = idx >= 0 ? cart[idx].quantity : 0.0;
    final newTotal = current + quantity;
    if (newTotal > avail + 1e-9) {
      throw StateError(
        'Quantidade indisponível. Disponível: ${_formatAvail(avail)}.',
      );
    }
    if (idx >= 0) {
      cart[idx].quantity = newTotal;
      if (unitPrice != null) {
        cart[idx].unitPrice = unitPrice;
      }
      cart.refresh();
    } else {
      cart.add(
        SaleCartLine(
          productId: productId,
          productName: productName,
          quantity: quantity,
          unitPrice: unitPrice,
          imageUrl: imageUrl,
        ),
      );
    }
  }

  String _formatAvail(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  void removeLine(String productId) {
    cart.removeWhere((c) => c.productId == productId);
    cart.refresh();
  }

  void clearCart() {
    cart.clear();
  }

  Future<void> submitSale() async {
    final b = _branchId;
    if (b == null || b.isEmpty || cart.isEmpty) return;
    if (isInternalUse.value && internalUsePurpose.value == InternalUsePurpose.newProduct) {
      final oid = outputProductId.value?.trim();
      if (oid == null || oid.isEmpty) {
        Get.snackbar('Uso interno', 'Selecione o produto que receberá entrada no estoque.');
        return;
      }
      final raw = outputStockQtyCtrl.text.replaceAll(',', '.').trim();
      final oq = double.tryParse(raw);
      if (oq == null || oq <= 0) {
        Get.snackbar('Uso interno', 'Informe a quantidade a adicionar no estoque do produto selecionado.');
        return;
      }
    }
    isSubmitting.value = true;
    try {
      final linesSnapshot = List<SaleCartLine>.from(cart);
      final internal = isInternalUse.value;
      final purpose = internal ? internalUsePurpose.value : null;
      double? outQty;
      if (internal && purpose == InternalUsePurpose.newProduct) {
        final raw = outputStockQtyCtrl.text.replaceAll(',', '.').trim();
        outQty = double.tryParse(raw);
      }
      final result = await _registerSale(
        RegisterSaleParams(
          branchId: b,
          lines: cart
              .map(
                (e) => RegisterSaleLine(
                  productId: e.productId,
                  quantity: e.quantity,
                  unitPrice: e.unitPrice,
                ),
              )
              .toList(),
          isInternalUse: internal,
          internalUsePurpose: purpose,
          // Não enviar saída no POST /api/inventory/sales: o acréscimo no acabado é só via
          // POST /api/inventory/entries (igual à tela de entrada de estoque).
          outputProductId: null,
          outputQuantity: null,
        ),
      );
      final outPid = outputProductId.value?.trim();
      var productionEntryOk = false;
      if (internal &&
          purpose == InternalUsePurpose.newProduct &&
          outPid != null &&
          outPid.isNotEmpty &&
          outQty != null &&
          outQty > 0) {
        final unitCost = _unitCostForProductionEntry(linesSnapshot, outQty);
        try {
          final tb = outputTargetBatchId.value?.trim();
          await _stockInventoryRepo.registerEntry(
            StockEntryParams(
              productId: outPid,
              branchId: b,
              quantity: outQty,
              costPrice: unitCost,
              targetBatchId: (tb != null && tb.isNotEmpty) ? tb : null,
            ),
          );
          productionEntryOk = true;
        } on StockInventoryApiException catch (e) {
          Get.snackbar(
            'Entrada no estoque',
            'Movimento registrado, mas a entrada do produto acabado falhou: ${e.message}',
          );
        } catch (e) {
          Get.snackbar(
            'Entrada no estoque',
            'Movimento registrado, mas a entrada do produto acabado falhou: $e',
          );
        }
      }
      final saleKey = (result.saleId?.trim().isNotEmpty == true)
          ? result.saleId!.trim()
          : (result.stockMovementId?.trim().isNotEmpty == true)
              ? result.stockMovementId!.trim()
              : 'local-${DateTime.now().millisecondsSinceEpoch}';
      final histLines = linesSnapshot
          .map(
            (e) => SaleHistoryLine(
              productId: e.productId,
              productName: e.productName,
              quantity: e.quantity,
              unitPrice: e.unitPrice,
            ),
          )
          .toList();
      final total = _cartTotalAmount(linesSnapshot);
      await _appendLocalSale(
        SaleHistoryRecord(
          saleId: saleKey,
          branchId: b,
          occurredAt: DateTime.now(),
          isInternalUse: internal,
          totalAmount: total,
          lines: histLines,
          internalUsePurpose: internal ? purpose?.name : null,
          outputProductName:
              internal && purpose == InternalUsePurpose.newProduct ? outputProductName.value : null,
          outputQuantity:
              internal && purpose == InternalUsePurpose.newProduct ? outQty : null,
        ),
      );
      cart.clear();
      if (internal) {
        _resetInternalUseExtras();
      }
      if (internal) {
        await _refreshInventoryTwice();
      } else {
        await refreshInventory();
      }
      final id = result.saleId ?? result.stockMovementId ?? '—';
      Get.snackbar(
        internal ? 'Movimento interno registrado' : 'Venda registrada',
        internal
            ? (productionEntryOk
                ? 'Referência: $id · estoque atualizado.'
                : 'Referência: $id')
            : 'Venda: $id',
      );
    } on StockInventoryApiException catch (e) {
      Get.snackbar('Erro', e.message);
    } catch (e) {
      Get.snackbar('Erro', e.toString());
    } finally {
      isSubmitting.value = false;
    }
  }

  double? _cartTotalAmount(List<SaleCartLine> lines) {
    double sum = 0;
    var any = false;
    for (final l in lines) {
      final p = l.unitPrice;
      if (p != null) {
        any = true;
        sum += l.quantity * p;
      }
    }
    return any ? sum : null;
  }

  /// Custo unitário da entrada de produção (`POST /api/inventory/entries` costPrice).
  /// Muitas APIs rejeitam zero; usamos rateio do valor do carrinho ou mínimo R$ 0,01.
  double _unitCostForProductionEntry(List<SaleCartLine> consumedLines, double outputQty) {
    if (outputQty <= 0) return 0.01;
    double monetarySum = 0;
    for (final l in consumedLines) {
      final p = l.unitPrice;
      if (p != null && p > 0) {
        monetarySum += l.quantity * p;
      }
    }
    if (monetarySum <= 0) return 0.01;
    final u = monetarySum / outputQty;
    return u < 0.01 ? 0.01 : u;
  }

  Future<void> _refreshInventoryTwice() async {
    await refreshInventory();
    await Future<void>.delayed(const Duration(milliseconds: 450));
    await refreshInventory();
  }

  Future<List<SaleHistoryRecord>> loadSaleHistory() async {
    final b = _branchId;
    if (b == null || b.isEmpty) return [];
    return _loadSaleHistory(b);
  }

  Future<SaleHistoryRecord> loadSaleDetail(String saleId) async {
    final b = _branchId;
    if (b == null || b.isEmpty) {
      throw StateError('Filial não configurada.');
    }
    return _getSaleDetail(saleId: saleId, branchId: b);
  }
}
