import 'dart:io';

import 'package:componentes_lr/componentes_lr.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:sale_module/modules/domain/entities/internal_use_purpose.dart';
import 'package:sale_module/modules/domain/entities/sale_cart_line.dart';
import 'package:sale_module/modules/domain/entities/sale_history.dart';
import 'package:sale_module/modules/presentation/controllers/sale_home_controller.dart';
import 'package:sale_module/modules/presentation/pages/sale_history_page.dart';
import 'package:sale_module/modules/presentation/widgets/sale_internal_use_confirm_sheet.dart';

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

  Future<void> _openAddDialog(SaleProductRow product) async {
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController(text: _initialUnitPriceText(product));
    final internal = controller.isInternalUse.value;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              _SaleProductImageThumb(imageUrl: product.imageUrl),
              const SizedBox(width: 12),
              Expanded(child: Text(product.productName)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Disponível: ${_formatQty(product.available)}',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Quantidade',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Adicionar'),
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
      if (priceCtrl.text.trim().isEmpty || unit == null) {
        unit = 0;
      }
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

  String _formatQty(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  String _formatMoney(double v) =>
      'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  /// Subtotal da linha (quantidade × preço unitário), ou null se não houver preço.
  String? _lineSubtotalStr(SaleCartLine line) {
    final p = line.unitPrice;
    if (p == null) return null;
    return _formatMoney(line.quantity * p);
  }

  ({double? total, bool hasLinesWithoutPrice}) _cartTotals(List<SaleCartLine> lines) {
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
                      style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(ctx).colorScheme.primary,
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
                        style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(ctx).colorScheme.primary,
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
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
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
                        style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(ctx).colorScheme.primary,
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
    if (controller.cart.isEmpty) {
      afterCartCleared?.call();
    }
  }

  Future<void> _openCartSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: SafeArea(
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
          ),
        );
      },
    );
  }

  Widget _buildProductList(ColorScheme scheme) {
    return Obx(
      () {
        if (controller.isLoading.value && controller.rows.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.errorMessage.value != null &&
            controller.errorMessage.value!.isNotEmpty) {
          return Center(
            child: Text(
              controller.errorMessage.value!,
              textAlign: TextAlign.center,
            ),
          );
        }
        final products = controller.groupedProducts;
        if (products.isEmpty) {
          final noBranch = controller.resolvedBranchId == null ||
              controller.resolvedBranchId!.isEmpty;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                noBranch
                    ? 'Filial não configurada para esta tela.'
                    : 'Sem estoque nesta filial.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          );
        }
        return ListView.separated(
          itemCount: products.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (ctx, i) {
            final p = products[i];
            return ListTile(
              minLeadingWidth: 58,
              leading: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _SaleProductImageThumb(imageUrl: p.imageUrl),
              ),
              title: Text(p.productName),
              subtitle: Text(
                'Disp.: ${_formatQty(p.available)} · ${p.saleLabel ?? '—'}',
              ),
              trailing: FilledButton(
                onPressed: controller.isLoading.value
                    ? null
                    : () => _openAddDialog(p),
                child: const Text('Add'),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final desktop = isDesktopFormFactor;

    return AdaptiveModulePage(
      title: 'Vendas',
      onBack: () => Get.back(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Tipo de operação',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
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
                        icon: Icon(Icons.shopping_bag_outlined, size: 20),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('Uso na loja'),
                        icon: Icon(Icons.inventory_2_outlined, size: 20),
                      ),
                    ],
                    selected: {controller.isInternalUse.value},
                    onSelectionChanged: (Set<bool> next) {
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ),
          TextField(
            decoration: InputDecoration(
              hintText: 'Buscar produto…',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              isDense: true,
            ),
            onChanged: (v) => controller.filterQuery.value = v,
          ),
          const SizedBox(height: 12),
          Obx(
            () => Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed:
                      controller.isLoading.value ? null : () => controller.refreshInventory(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Atualizar estoque'),
                ),
                OutlinedButton.icon(
                  onPressed: controller.isLoading.value ? null : _openSaleHistoryPage,
                  icon: const Icon(Icons.history),
                  label: const Text('Histórico'),
                ),
                if (!desktop)
                  Obx(
                    () {
                      final n = controller.cart.length;
                      return FilledButton.tonalIcon(
                        onPressed: () => _openCartSheet(),
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
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: desktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _buildProductList(scheme)),
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: scheme.outlineVariant,
                      ),
                      SizedBox(
                        width: 420,
                        child: Material(
                          color: scheme.surfaceContainerLow,
                          child: _SaleCartPanel(
                            controller: controller,
                            formatQty: _formatQty,
                            formatMoney: _formatMoney,
                            lineSubtotalStr: _lineSubtotalStr,
                            cartTotals: _cartTotals,
                            desktopLayout: true,
                            onAfterSubmit: null,
                            onSubmitSale: (ctx) => _submitSaleWithInternalConfirm(ctx),
                          ),
                        ),
                      ),
                    ],
                  )
                : _buildProductList(scheme),
          ),
        ],
      ),
    );
  }
}

/// Carrinho: no desktop, colunas produto / qtd / unitário / subtotal; no mobile, lista compacta (sheet).
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
  final ({double? total, bool hasLinesWithoutPrice}) Function(List<SaleCartLine>) cartTotals;
  final bool desktopLayout;
  final VoidCallback? onAfterSubmit;

  /// Confirma uso interno (sheet) quando aplicável e chama [SaleHomeController.submitSale].
  final Future<void> Function(BuildContext context) onSubmitSale;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () {
        final rx = controller.cart;
        rx.length;
        for (final line in rx) {
          line.quantity;
          line.unitPrice;
        }
        controller.isInternalUse.value;
        final lines = List<SaleCartLine>.from(rx);

        final title = controller.cartPanelTitle();

        if (desktopLayout) {
          return _DesktopCartBody(
            formatQty: formatQty,
            formatMoney: formatMoney,
            lineSubtotalStr: lineSubtotalStr,
            cartTotals: cartTotals,
            controller: controller,
            onAfterSubmit: onAfterSubmit,
            onSubmitSale: onSubmitSale,
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (lines.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nenhum item.'),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: lines.length,
                  itemBuilder: (c, i) {
                    final line = lines[i];
                    final price = line.unitPrice;
                    final priceStr = price == null ? '—' : formatMoney(price);
                    final subStr = lineSubtotalStr(line);
                    return ListTile(
                      minLeadingWidth: 58,
                      isThreeLine: true,
                      leading: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _SaleProductImageThumb(imageUrl: line.imageUrl),
                      ),
                      title: Text(line.productName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Qtd: ${formatQty(line.quantity)} · Unit.: $priceStr',
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subStr != null ? 'Subtotal: $subStr' : 'Subtotal: —',
                            style: Theme.of(c).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(c).colorScheme.primary,
                                ),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => controller.removeLine(line.productId),
                      ),
                    );
                  },
                ),
              ),
            if (lines.isNotEmpty)
              _CartTotalsBlock(
                lines: lines,
                formatMoney: formatMoney,
                cartTotals: cartTotals,
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Obx(
                () => FilledButton.icon(
                  onPressed: controller.isSubmitting.value || lines.isEmpty
                      ? null
                      : () async {
                          await onSubmitSale(context);
                          if (!context.mounted) return;
                          if (controller.cart.isEmpty) {
                            onAfterSubmit?.call();
                          }
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
      },
    );
  }
}

class _DesktopCartBody extends StatelessWidget {
  const _DesktopCartBody({
    required this.formatQty,
    required this.formatMoney,
    required this.lineSubtotalStr,
    required this.cartTotals,
    required this.controller,
    this.onAfterSubmit,
    required this.onSubmitSale,
  });

  final String Function(double) formatQty;
  final String Function(double) formatMoney;
  final String? Function(SaleCartLine) lineSubtotalStr;
  final ({double? total, bool hasLinesWithoutPrice}) Function(List<SaleCartLine>) cartTotals;
  final SaleHomeController controller;
  final VoidCallback? onAfterSubmit;
  final Future<void> Function(BuildContext context) onSubmitSale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Obx(
      () {
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                title,
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            if (lines.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'Nenhum item no carrinho.',
                    style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Produto',
                        style: t.labelMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 56,
                      child: Text(
                        'Qtd',
                        textAlign: TextAlign.right,
                        style: t.labelMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 88,
                      child: Text(
                        'Unit.',
                        textAlign: TextAlign.right,
                        style: t.labelMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 92,
                      child: Text(
                        'Subtotal',
                        textAlign: TextAlign.right,
                        style: t.labelMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: lines.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: scheme.outlineVariant),
                  itemBuilder: (ctx, i) {
                    final line = lines[i];
                    final priceStr = line.unitPrice == null
                        ? '—'
                        : formatMoney(line.unitPrice!);
                    final subStr = lineSubtotalStr(line);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              line.productName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: t.bodyMedium,
                            ),
                          ),
                          SizedBox(
                            width: 56,
                            child: Text(
                              formatQty(line.quantity),
                              textAlign: TextAlign.right,
                              style: t.bodyMedium,
                            ),
                          ),
                          SizedBox(
                            width: 88,
                            child: Text(
                              priceStr,
                              textAlign: TextAlign.right,
                              style: t.bodyMedium,
                            ),
                          ),
                          SizedBox(
                            width: 92,
                            child: Text(
                              subStr ?? '—',
                              textAlign: TextAlign.right,
                              style: t.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 40,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              constraints:
                                  const BoxConstraints(minWidth: 36, minHeight: 36),
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => controller.removeLine(line.productId),
                              tooltip: 'Remover',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              _CartTotalsBlock(
                lines: lines,
                formatMoney: formatMoney,
                cartTotals: cartTotals,
              ),
            ],
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: controller.isSubmitting.value || lines.isEmpty
                    ? null
                    : () async {
                        await onSubmitSale(context);
                        if (!context.mounted) return;
                        if (controller.cart.isEmpty) {
                          onAfterSubmit?.call();
                        }
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
          ],
        );
      },
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
  final ({double? total, bool hasLinesWithoutPrice}) Function(List<SaleCartLine>) cartTotals;

  @override
  Widget build(BuildContext context) {
    final t = cartTotals(lines);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                t.total != null ? formatMoney(t.total!) : '—',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          if (t.hasLinesWithoutPrice && t.total != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '* Parcial: há itens sem preço unitário.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          if (t.total == null && lines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Informe preço unitário nos itens para ver o total.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  /// Soma qtd × unitário quando todos têm preço; se algum não tiver, ainda soma os que têm.
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
    final scheme = Theme.of(context).colorScheme;
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
            _lineRow(context, scheme, lines[i]),
            if (i < lines.length - 1) const Divider(height: 20),
          ],
          if (lines.isNotEmpty) ...[
            const Divider(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  displayTotal != null ? formatMoney(displayTotal) : '—',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ),
                ),
              ],
            ),
            if (showPartialNote)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '* Parcial: há itens sem preço unitário.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
            if (displayTotal == null && lines.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Total não disponível (informe preço nos itens ou aguarde o servidor).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _lineRow(BuildContext context, ColorScheme scheme, SaleHistoryLine line) {
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
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (hasName)
                Text(
                  'Cód.: ${line.productId}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
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
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              line.unitPrice != null ? 'Unit. ${formatMoney(line.unitPrice!)}' : 'Unit. —',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            if (line.unitPrice != null)
              Text(
                'Subtotal ${formatMoney(line.quantity * line.unitPrice!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Miniatura alinhada ao estoque (mesmo padrão de `stock_home_page`).
class _SaleProductImageThumb extends StatelessWidget {
  const _SaleProductImageThumb({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final value = imageUrl?.trim();
    final scheme = Theme.of(context).colorScheme;
    if (value == null || value.isEmpty) {
      return _placeholder(scheme);
    }
    final isHttp = value.startsWith('http://') || value.startsWith('https://');
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: isHttp
          ? Image.network(
              value,
              height: 42,
              width: 42,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(scheme),
            )
          : Image.file(
              File(value),
              height: 42,
              width: 42,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(scheme),
            ),
    );
    return SizedBox(width: 42, height: 42, child: image);
  }

  Widget _placeholder(ColorScheme scheme) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: scheme.surfaceContainerHighest,
      ),
      child: Icon(Icons.image_outlined, size: 20, color: scheme.onSurfaceVariant),
    );
  }
}
