import 'dart:io';

import 'package:componentes_lr/componentes_lr.dart' show isDesktopFormFactor;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:sale_module/modules/domain/entities/internal_use_purpose.dart';
import 'package:sale_module/modules/domain/entities/sale_cart_line.dart';
import 'package:sale_module/modules/domain/entities/sale_history.dart';
import 'package:sale_module/modules/presentation/controllers/sale_home_controller.dart';
import 'package:sale_module/modules/presentation/pages/sale_history_page.dart';
import 'package:sale_module/modules/presentation/widgets/sale_internal_use_confirm_sheet.dart';
import 'package:stock_module/presentation_export.dart';

class SaleHomePage extends StatefulWidget {
  const SaleHomePage({super.key, this.branchId});

  /// Filial fixa para esta tela. Se omitido, usa [Get.arguments] (`String` ou `{'branchId': ...}`).
  final String? branchId;

  @override
  State<SaleHomePage> createState() => _SaleHomePageState();
}

class _SaleHomePageState extends State<SaleHomePage> {
  late final SaleHomeController controller = Get.put(
    SaleHomeController(initialBranchId: widget.branchId),
    tag: 'sale_home',
  );

  @override
  void dispose() {
    Get.delete<SaleHomeController>(tag: 'sale_home');
    super.dispose();
  }

  // ---------- helpers ----------

  double? _parseOptionalDouble(String s) {
    final t = s.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  String _initialUnitPriceText(SaleProductRow product) {
    final r = product.referenceUnitPrice;
    if (r == null) return '';
    return r.toStringAsFixed(2).replaceAll('.', ',');
  }

  String _formatQty(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v
        .toStringAsFixed(3)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  String _formatMoney(double v) =>
      'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  String? _lineSubtotalStr(SaleCartLine line) {
    final p = line.unitPrice;
    if (p == null) return null;
    return _formatMoney(line.quantity * p);
  }

  ({double? total, bool hasLinesWithoutPrice}) _cartTotals(
      List<SaleCartLine> lines) {
    double sum = 0;
    var anyPrice = false;
    var missingPrice = false;
    for (final l in lines) {
      final p = l.unitPrice;
      if (p != null) {
        anyPrice = true;
        sum += l.quantity * p;
      } else {
        missingPrice = true;
      }
    }
    if (!anyPrice) {
      return (total: null, hasLinesWithoutPrice: missingPrice);
    }
    return (total: sum, hasLinesWithoutPrice: missingPrice);
  }

  // ---------- actions ----------

  Future<void> _openAddDialog(SaleProductRow product) async {
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl =
        TextEditingController(text: _initialUnitPriceText(product));
    final internal = controller.isInternalUse.value;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          icon: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: IwColors.primaryContainer,
              borderRadius: BorderRadius.circular(IwRadius.md),
            ),
            alignment: Alignment.center,
            child: _SaleProductImageThumb(
                imageUrl: product.imageUrl, size: 40, radius: 10),
          ),
          title: Text(product.productName),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Disponível: ${_formatQty(product.available)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: IwColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: qtyCtrl,
                  decoration: const InputDecoration(labelText: 'Quantidade'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  decoration: InputDecoration(
                    labelText: 'Preço unitário',
                    hintText: internal
                        ? 'Vazio envia 0 (uso interno)'
                        : (product.referenceUnitPrice != null
                            ? 'Padrão: preço de venda da lista'
                            : 'Informe o valor'),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.add_shopping_cart_outlined, size: 18),
              label: const Text('Adicionar'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;

    final q = _parseOptionalDouble(qtyCtrl.text.replaceAll(',', '.')) ??
        _parseOptionalDouble(qtyCtrl.text);
    if (q == null || q <= 0) {
      Get.snackbar('Quantidade inválida', 'Informe um número maior que zero.');
      return;
    }
    var unit = _parseOptionalDouble(priceCtrl.text.replaceAll(',', '.')) ??
        _parseOptionalDouble(priceCtrl.text);
    if (internal) {
      if (priceCtrl.text.trim().isEmpty || unit == null) unit = 0;
    } else {
      unit ??= product.referenceUnitPrice;
    }

    try {
      controller.addOrIncreaseLine(
        productId: product.productId,
        productName: product.productName,
        quantity: q,
        unitPrice: unit,
        imageUrl: product.imageUrl,
      );
    } catch (e) {
      Get.snackbar('Não foi possível adicionar', e.toString());
    }
  }

  String _saleTitle(SaleHistoryRecord r) {
    final id = r.saleId;
    if (id.length <= 14) return '#$id';
    return '#${id.substring(0, 12)}…';
  }

  String _saleOperationLabel(SaleHistoryRecord r) {
    if (!r.isInternalUse) return 'Venda ao cliente';
    if (r.internalUsePurpose == InternalUsePurpose.newProduct.name) {
      return 'Uso interno · novo produto no estoque';
    }
    return 'Uso interno · uso da empresa';
  }

  Widget _productionDetailBanner(SaleHistoryRecord r) {
    if (r.internalUsePurpose != InternalUsePurpose.newProduct.name) {
      return const SizedBox.shrink();
    }
    final name = r.outputProductName;
    final q = r.outputQuantity;
    if (name == null || q == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        'Entrada no estoque: ${_formatQty(q)} × $name',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
    );
  }

  Future<void> _openSaleDetailDialog(SaleHistoryRecord initial) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        if (initial.hasLines) {
          return AlertDialog(
            title: Text(_saleTitle(initial)),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _saleOperationLabel(initial),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: IwColors.primary,
                      ),
                    ),
                  ),
                  _productionDetailBanner(initial),
                  _SaleDetailLines(
                    lines: initial.lines!,
                    totalAmount: initial.totalAmount,
                    formatQty: _formatQty,
                    formatMoney: _formatMoney,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fechar'),
              ),
            ],
          );
        }
        return FutureBuilder<SaleHistoryRecord>(
          future: controller.loadSaleDetail(initial.saleId),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return AlertDialog(
                title: Text(_saleTitle(initial)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _saleOperationLabel(initial),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: IwColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                ),
              );
            }
            if (snap.hasError) {
              return AlertDialog(
                title: const Text('Detalhe da venda'),
                content: Text('${snap.error}'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Fechar')),
                ],
              );
            }
            final d = snap.data!;
            final lines = d.lines ?? [];
            return AlertDialog(
              title: Text(_saleTitle(d)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _saleOperationLabel(d),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: IwColors.primary,
                        ),
                      ),
                    ),
                    _productionDetailBanner(d),
                    if (lines.isEmpty)
                      const Text('Nenhum item retornado.')
                    else
                      _SaleDetailLines(
                        lines: lines,
                        totalAmount: d.totalAmount,
                        formatQty: _formatQty,
                        formatMoney: _formatMoney,
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fechar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openSaleHistoryPage() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (ctx) => SaleHistoryPage(
          controller: controller,
          onSaleSelected: _openSaleDetailDialog,
        ),
      ),
    );
  }

  Future<void> _submitSaleWithInternalConfirm(
    BuildContext context, {
    VoidCallback? afterCartCleared,
  }) async {
    if (controller.isInternalUse.value) {
      final ok = await showSaleInternalUseConfirmSheet(context, controller);
      if (ok != true) return;
    }
    await controller.submitSale();
    if (!context.mounted) return;
    if (controller.cart.isEmpty) afterCartCleared?.call();
  }

  Future<void> _openCartSheet() async {
    await showIwBottomSheet<void>(
      context,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: _SaleCartPanel(
            controller: controller,
            formatQty: _formatQty,
            formatMoney: _formatMoney,
            lineSubtotalStr: _lineSubtotalStr,
            cartTotals: _cartTotals,
            desktopLayout: false,
            onAfterSubmit: () {
              if (ctx.mounted) Navigator.pop(ctx);
            },
            onSubmitSale: (c) => _submitSaleWithInternalConfirm(
              c,
              afterCartCleared: () {
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ),
        );
      },
    );
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktopFormFactor;
    return IwModulePage(
      onBack: () => Get.back(),
      breadcrumb: desktop
          ? const IwBreadcrumbData(
              icon: Icons.point_of_sale_outlined,
              label: 'Vendas',
              sub: 'Caixa',
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!desktop)
            const _MobilePageTitle()
          else
            const SizedBox.shrink(),
          if (!desktop) const SizedBox(height: 12),
          _OperationSwitch(controller: controller),
          const SizedBox(height: 14),
          _Toolbar(
            controller: controller,
            desktop: desktop,
            onHistory: _openSaleHistoryPage,
            onCart: _openCartSheet,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: desktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                          child: _ProductList(
                              controller: controller,
                              onAdd: _openAddDialog)),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 420,
                        child: _CartContainer(
                          child: _SaleCartPanel(
                            controller: controller,
                            formatQty: _formatQty,
                            formatMoney: _formatMoney,
                            lineSubtotalStr: _lineSubtotalStr,
                            cartTotals: _cartTotals,
                            desktopLayout: true,
                            onAfterSubmit: null,
                            onSubmitSale: (ctx) =>
                                _submitSaleWithInternalConfirm(ctx),
                          ),
                        ),
                      ),
                    ],
                  )
                : _ProductList(
                    controller: controller,
                    onAdd: _openAddDialog,
                  ),
          ),
        ],
      ),
    );
  }
}

class _MobilePageTitle extends StatelessWidget {
  const _MobilePageTitle();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vendas',
          style: TextStyle(
            fontSize: 22,
            height: 28 / 22,
            fontWeight: FontWeight.w600,
            color: IwColors.onSurface,
            letterSpacing: -0.11,
          ),
        ),
        SizedBox(height: 2),
        Text(
          'Caixa · use a busca ou o leitor para incluir itens.',
          style: TextStyle(
            fontSize: 13,
            color: IwColors.onSurfaceVariant,
            height: 18 / 13,
          ),
        ),
      ],
    );
  }
}

class _OperationSwitch extends StatelessWidget {
  const _OperationSwitch({required this.controller});
  final SaleHomeController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: IwColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(IwRadius.lg),
        border: Border.all(color: IwColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tipo de operação',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: IwColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Obx(
            () => SegmentedButton<bool>(
              showSelectedIcon: false,
              emptySelectionAllowed: false,
              segments: const [
                ButtonSegment<bool>(
                  value: false,
                  label: Text('Venda ao cliente'),
                  icon: Icon(Icons.shopping_bag_outlined, size: 18),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text('Uso na loja'),
                  icon: Icon(Icons.inventory_2_outlined, size: 18),
                ),
              ],
              selected: {controller.isInternalUse.value},
              onSelectionChanged: (next) {
                if (next.isEmpty) return;
                controller.setInternalUse(next.first);
              },
            ),
          ),
          const SizedBox(height: 6),
          Obx(
            () => Text(
              controller.isInternalUse.value
                  ? 'Baixa de estoque sem cliente. Ao registrar, você informará se é uso da empresa ou entrada em outro produto.'
                  : 'Venda normal ao público.',
              style: const TextStyle(
                fontSize: 12,
                color: IwColors.onSurfaceVariant,
                height: 16 / 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.desktop,
    required this.onHistory,
    required this.onCart,
  });

  final SaleHomeController controller;
  final bool desktop;
  final VoidCallback onHistory;
  final VoidCallback onCart;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 260, maxWidth: 520),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar produto…',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => controller.filterQuery.value = v,
          ),
        ),
        Obx(
          () => OutlinedButton.icon(
            onPressed:
                controller.isLoading.value ? null : controller.refreshInventory,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Atualizar estoque'),
          ),
        ),
        Obx(
          () => OutlinedButton.icon(
            onPressed: controller.isLoading.value ? null : onHistory,
            icon: const Icon(Icons.history, size: 18),
            label: const Text('Histórico'),
          ),
        ),
        if (!desktop)
          Obx(
            () {
              final n = controller.cart.length;
              return FilledButton.tonalIcon(
                onPressed: onCart,
                icon: Badge(
                  isLabelVisible: n > 0,
                  label: Text('$n'),
                  child: const Icon(Icons.shopping_cart_outlined),
                ),
                label: const Text('Carrinho'),
              );
            },
          ),
      ],
    );
  }
}

class _ProductList extends StatelessWidget {
  const _ProductList({required this.controller, required this.onAdd});
  final SaleHomeController controller;
  final void Function(SaleProductRow) onAdd;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value && controller.rows.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.errorMessage.value != null &&
          controller.errorMessage.value!.isNotEmpty) {
        return _ErrorState(
          message: controller.errorMessage.value!,
          onRetry: controller.refreshInventory,
        );
      }
      final products = controller.groupedProducts;
      if (products.isEmpty) {
        final noBranch = controller.resolvedBranchId == null ||
            controller.resolvedBranchId!.isEmpty;
        return _EmptyState(
          message: noBranch
              ? 'Filial não configurada para esta tela.'
              : 'Sem estoque nesta filial.',
        );
      }
      return Container(
        decoration: BoxDecoration(
          color: IwColors.surface,
          borderRadius: BorderRadius.circular(IwRadius.lg),
          border: Border.all(color: IwColors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: products.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: IwColors.outlineVariant),
          itemBuilder: (ctx, i) {
            final p = products[i];
            return _ProductRow(product: p, onAdd: () => onAdd(p));
          },
        ),
      );
    });
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product, required this.onAdd});
  final SaleProductRow product;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onAdd,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _SaleProductImageThumb(imageUrl: product.imageUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.productName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: IwColors.onSurface,
                      letterSpacing: -0.07,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Disp. ${_qtyText(product.available)} · ${product.saleLabel ?? '—'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: IwColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _qtyText(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v
        .toStringAsFixed(3)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }
}

class _CartContainer extends StatelessWidget {
  const _CartContainer({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: IwColors.surface,
        borderRadius: BorderRadius.circular(IwRadius.lg),
        border: Border.all(color: IwColors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _SaleCartPanel extends StatelessWidget {
  const _SaleCartPanel({
    required this.controller,
    required this.formatQty,
    required this.formatMoney,
    required this.lineSubtotalStr,
    required this.cartTotals,
    required this.desktopLayout,
    this.onAfterSubmit,
    required this.onSubmitSale,
  });

  final SaleHomeController controller;
  final String Function(double) formatQty;
  final String Function(double) formatMoney;
  final String? Function(SaleCartLine) lineSubtotalStr;
  final ({double? total, bool hasLinesWithoutPrice}) Function(
      List<SaleCartLine>) cartTotals;
  final bool desktopLayout;
  final VoidCallback? onAfterSubmit;
  final Future<void> Function(BuildContext context) onSubmitSale;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      controller.isSubmitting.value;
      final rx = controller.cart;
      rx.length;
      for (final line in rx) {
        line.quantity;
        line.unitPrice;
      }
      controller.isInternalUse.value;
      final lines = List<SaleCartLine>.from(rx);
      final title = controller.cartPanelTitle();

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: IwColors.onSurface,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: IwColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${lines.length}',
                    style: const TextStyle(
                      fontFamily: 'RobotoMono',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: IwColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: IwColors.outlineVariant),
          if (lines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shopping_cart_outlined,
                      size: 36, color: IwColors.outline),
                  const SizedBox(height: 8),
                  Text(
                    'Nenhum item no carrinho.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: IwColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          else if (desktopLayout)
            Flexible(
              child: ListView.separated(
                shrinkWrap: !desktopLayout,
                padding: EdgeInsets.zero,
                itemCount: lines.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: IwColors.outlineVariant),
                itemBuilder: (ctx, i) {
                  final line = lines[i];
                  return _CartLineDesktop(
                    line: line,
                    subtotal: lineSubtotalStr(line),
                    onRemove: () => controller.removeLine(line.productId),
                    formatQty: formatQty,
                    formatMoney: formatMoney,
                  );
                },
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.45,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: lines.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: IwColors.outlineVariant),
                itemBuilder: (ctx, i) {
                  final line = lines[i];
                  return _CartLineMobile(
                    line: line,
                    subtotal: lineSubtotalStr(line),
                    onRemove: () => controller.removeLine(line.productId),
                    formatQty: formatQty,
                    formatMoney: formatMoney,
                  );
                },
              ),
            ),
          if (lines.isNotEmpty) ...[
            const Divider(height: 1, color: IwColors.outlineVariant),
            _CartTotalsBlock(
              lines: lines,
              formatMoney: formatMoney,
              cartTotals: cartTotals,
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: controller.isSubmitting.value || lines.isEmpty
                    ? null
                    : () async {
                        await onSubmitSale(context);
                        if (!context.mounted) return;
                        if (controller.cart.isEmpty) onAfterSubmit?.call();
                      },
                icon: controller.isSubmitting.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        controller.isInternalUse.value
                            ? Icons.inventory_2_outlined
                            : Icons.point_of_sale_outlined,
                      ),
                label: Text(
                  controller.isSubmitting.value
                      ? 'Registrando…'
                      : (controller.isInternalUse.value
                          ? 'Registrar uso na loja'
                          : 'Registrar venda'),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _CartLineDesktop extends StatelessWidget {
  const _CartLineDesktop({
    required this.line,
    required this.subtotal,
    required this.onRemove,
    required this.formatQty,
    required this.formatMoney,
  });

  final SaleCartLine line;
  final String? subtotal;
  final VoidCallback onRemove;
  final String Function(double) formatQty;
  final String Function(double) formatMoney;

  @override
  Widget build(BuildContext context) {
    final priceStr =
        line.unitPrice == null ? '—' : formatMoney(line.unitPrice!);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: IwColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Qtd ${formatQty(line.quantity)} · Unit. $priceStr',
                  style: const TextStyle(
                    fontSize: 11,
                    color: IwColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                subtotal ?? '—',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: IwColors.primary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'SUBTOTAL',
                style: TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: 9.5,
                  color: IwColors.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Remover',
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            icon: const Icon(Icons.delete_outline),
            color: IwColors.onSurfaceVariant,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _CartLineMobile extends StatelessWidget {
  const _CartLineMobile({
    required this.line,
    required this.subtotal,
    required this.onRemove,
    required this.formatQty,
    required this.formatMoney,
  });

  final SaleCartLine line;
  final String? subtotal;
  final VoidCallback onRemove;
  final String Function(double) formatQty;
  final String Function(double) formatMoney;

  @override
  Widget build(BuildContext context) {
    final priceStr =
        line.unitPrice == null ? '—' : formatMoney(line.unitPrice!);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          _SaleProductImageThumb(imageUrl: line.imageUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  line.productName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: IwColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Qtd ${formatQty(line.quantity)} · Unit. $priceStr',
                  style: const TextStyle(
                    fontSize: 12,
                    color: IwColors.onSurfaceVariant,
                  ),
                ),
                if (subtotal != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Subtotal $subtotal',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: IwColors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remover',
            icon: const Icon(Icons.delete_outline),
            color: IwColors.onSurfaceVariant,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _CartTotalsBlock extends StatelessWidget {
  const _CartTotalsBlock({
    required this.lines,
    required this.formatMoney,
    required this.cartTotals,
  });

  final List<SaleCartLine> lines;
  final String Function(double) formatMoney;
  final ({double? total, bool hasLinesWithoutPrice}) Function(
      List<SaleCartLine>) cartTotals;

  @override
  Widget build(BuildContext context) {
    final t = cartTotals(lines);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: IwColors.onSurface,
                ),
              ),
              Text(
                t.total != null ? formatMoney(t.total!) : '—',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: IwColors.primary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (t.hasLinesWithoutPrice && t.total != null)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '* Parcial: há itens sem preço unitário.',
                style: TextStyle(
                  fontSize: 12,
                  color: IwColors.onSurfaceVariant,
                ),
              ),
            ),
          if (t.total == null && lines.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Informe preço unitário nos itens para ver o total.',
                style: TextStyle(
                  fontSize: 12,
                  color: IwColors.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SaleDetailLines extends StatelessWidget {
  const _SaleDetailLines({
    required this.lines,
    required this.formatQty,
    required this.formatMoney,
    this.totalAmount,
  });

  final List<SaleHistoryLine> lines;
  final double? totalAmount;
  final String Function(double) formatQty;
  final String Function(double) formatMoney;

  static ({double? total, bool hasLinesWithoutPrice}) _totalsFromLines(
    List<SaleHistoryLine> lines,
  ) {
    double sum = 0;
    var anyPrice = false;
    var missingPrice = false;
    for (final l in lines) {
      final p = l.unitPrice;
      if (p != null) {
        anyPrice = true;
        sum += l.quantity * p;
      } else {
        missingPrice = true;
      }
    }
    if (!anyPrice) {
      return (total: null, hasLinesWithoutPrice: missingPrice);
    }
    return (total: sum, hasLinesWithoutPrice: missingPrice);
  }

  @override
  Widget build(BuildContext context) {
    final t = _totalsFromLines(lines);
    final displayTotal = totalAmount ?? t.total;
    final showPartialNote =
        t.hasLinesWithoutPrice && displayTotal != null && totalAmount == null;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            _lineRow(context, lines[i]),
            if (i < lines.length - 1) const Divider(height: 20),
          ],
          if (lines.isNotEmpty) ...[
            const Divider(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  displayTotal != null ? formatMoney(displayTotal) : '—',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: IwColors.primary,
                  ),
                ),
              ],
            ),
            if (showPartialNote)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '* Parcial: há itens sem preço unitário.',
                  style: TextStyle(
                    fontSize: 12,
                    color: IwColors.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _lineRow(BuildContext context, SaleHistoryLine line) {
    final name = line.productName?.trim();
    final hasName = name != null && name.isNotEmpty;
    final title = hasName ? name : line.productId;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (hasName)
                Text(
                  'Cód.: ${line.productId}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: IwColors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Qtd ${formatQty(line.quantity)}',
              style: const TextStyle(fontSize: 13),
            ),
            Text(
              line.unitPrice != null
                  ? 'Unit. ${formatMoney(line.unitPrice!)}'
                  : 'Unit. —',
              style: const TextStyle(
                fontSize: 12,
                color: IwColors.onSurfaceVariant,
              ),
            ),
            if (line.unitPrice != null)
              Text(
                'Subtotal ${formatMoney(line.quantity * line.unitPrice!)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: IwColors.primary,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SaleProductImageThumb extends StatelessWidget {
  const _SaleProductImageThumb(
      {this.imageUrl, this.size = 44, this.radius = 10});

  final String? imageUrl;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final value = imageUrl?.trim();
    if (value == null || value.isEmpty) return _placeholder();
    final isHttp = value.startsWith('http://') || value.startsWith('https://');
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: isHttp
          ? Image.network(
              value,
              height: size,
              width: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(),
            )
          : Image.file(
              File(value),
              height: size,
              width: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(),
            ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            IwColors.surfaceContainer,
            IwColors.surfaceContainerHigh,
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: const Icon(
        Icons.image_outlined,
        size: 20,
        color: IwColors.onSurfaceVariant,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.point_of_sale_outlined,
                size: 56, color: IwColors.outline),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: IwColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: IwColors.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: IwColors.onSurface),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
