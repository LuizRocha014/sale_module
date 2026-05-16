import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:sale_module/modules/domain/entities/internal_use_purpose.dart';
import 'package:sale_module/modules/presentation/controllers/sale_home_controller.dart';
import 'package:stock_module/modules/domain/entities/product_stock_detail_entity.dart';
import 'package:stock_module/presentation_export.dart';

/// Fluxo em sheet: escolha da finalidade e, se produção, produto + quantidade.
Future<bool?> showSaleInternalUseConfirmSheet(
  BuildContext context,
  SaleHomeController controller,
) {
  return showIwBottomSheet<bool>(
    context,
    builder: (ctx) => _SaleInternalUseConfirmBody(controller: controller),
  );
}

class _SaleInternalUseConfirmBody extends StatefulWidget {
  const _SaleInternalUseConfirmBody({required this.controller});

  final SaleHomeController controller;

  @override
  State<_SaleInternalUseConfirmBody> createState() =>
      _SaleInternalUseConfirmBodyState();
}

class _SaleInternalUseConfirmBodyState
    extends State<_SaleInternalUseConfirmBody> {
  InternalUsePurpose _mode = InternalUsePurpose.company;
  String? _outputProductId;
  String? _outputProductName;
  String _targetBatchChoice = '';
  late final TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: widget.controller.outputStockQtyCtrl.text);
    final id = widget.controller.outputProductId.value;
    final name = widget.controller.outputProductName.value;
    if (id != null && id.isNotEmpty) {
      _outputProductId = id;
      _outputProductName = name;
    }
    final tb = widget.controller.outputTargetBatchId.value?.trim();
    _targetBatchChoice = (tb != null && tb.isNotEmpty) ? tb : '';
    _mode = widget.controller.internalUsePurpose.value;
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _applyToControllerAndPop() {
    final c = widget.controller;
    if (_mode == InternalUsePurpose.company) {
      c.setInternalUsePurpose(InternalUsePurpose.company);
    } else {
      final oid = _outputProductId?.trim();
      if (oid == null || oid.isEmpty) {
        Get.snackbar('Uso interno',
            'Selecione o produto que receberá entrada no estoque.');
        return;
      }
      final raw = _qtyCtrl.text.replaceAll(',', '.').trim();
      final oq = double.tryParse(raw);
      if (oq == null || oq <= 0) {
        Get.snackbar(
            'Uso interno', 'Informe a quantidade a adicionar no estoque.');
        return;
      }
      c.applyInternalProductionSelection(
        productId: oid,
        productName: _outputProductName ?? oid,
        qtyText: _qtyCtrl.text,
        targetBatchId: _targetBatchChoice.isEmpty ? null : _targetBatchChoice,
      );
    }
    Navigator.of(context).pop(true);
  }

  String _batchChoiceLabel(StockBatchDetailEntity b) {
    final v = b.expirationDate;
    final vd = v == null
        ? 's/ val.'
        : '${v.day.toString().padLeft(2, '0')}/${v.month.toString().padLeft(2, '0')}/${v.year}';
    return '$vd · ${b.quantityLabel} · ${b.costLabel}';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 4, bottom: 16 + bottomInset),
      child: Obx(
        () {
          c.rows.length;
          c.filterQuery.value;
          final products = c.groupedProducts;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                IwSheetHeader(
                  title: 'Uso interno',
                  subtitle:
                      'O carrinho será baixado. O que representa este movimento?',
                  onClose: () => Navigator.of(context).pop(false),
                ),
                const SizedBox(height: 18),
                _PurposeCard(
                  selected: _mode == InternalUsePurpose.company,
                  icon: Icons.business_outlined,
                  title: 'Uso da empresa',
                  subtitle:
                      'Consumo interno, granel ou porções. Não gera entrada em outro produto.',
                  onTap: () => setState(() => _mode = InternalUsePurpose.company),
                ),
                const SizedBox(height: 10),
                _PurposeCard(
                  selected: _mode == InternalUsePurpose.newProduct,
                  icon: Icons.add_box_outlined,
                  title: 'Entrada em produto no estoque',
                  subtitle:
                      'Produção ou montagem: indique o produto acabado e quanto entra no estoque.',
                  onTap: () =>
                      setState(() => _mode = InternalUsePurpose.newProduct),
                ),
                if (_mode == InternalUsePurpose.newProduct) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Produto que recebe a entrada',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: IwColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: () {
                      final id = _outputProductId;
                      final ids = products.map((e) => e.productId).toSet();
                      return id != null && ids.contains(id) ? id : null;
                    }(),
                    decoration: const InputDecoration(
                      labelText: 'Produto',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    hint: const Text('Selecione'),
                    items: [
                      for (final p in products)
                        DropdownMenuItem<String>(
                          value: p.productId,
                          child: Text(
                            p.productName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: products.isEmpty
                        ? null
                        : (id) {
                            if (id == null) return;
                            final p =
                                products.firstWhere((e) => e.productId == id);
                            setState(() {
                              _outputProductId = p.productId;
                              _outputProductName = p.productName;
                              _targetBatchChoice = '';
                            });
                          },
                  ),
                  const SizedBox(height: 14),
                  if (_outputProductId != null && _outputProductId!.isNotEmpty)
                    FutureBuilder<List<StockBatchDetailEntity>>(
                      key: ValueKey<String>(_outputProductId!),
                      future: c.loadActiveBatchesForOutputProduct(
                          _outputProductId!),
                      builder: (ctx, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: LinearProgressIndicator(),
                          );
                        }
                        final batches = snap.data ?? [];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: DropdownButtonFormField<String>(
                            initialValue: () {
                              if (_targetBatchChoice.isEmpty) return '';
                              final ids = batches.map((e) => e.batchId).toSet();
                              return ids.contains(_targetBatchChoice)
                                  ? _targetBatchChoice
                                  : '';
                            }(),
                            decoration: const InputDecoration(
                              labelText: 'Somar quantidade em',
                              helperText:
                                  'Escolha um lote ativo ou crie um novo lote com esta entrada.',
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: '',
                                child: Text('Novo lote (entrada separada)'),
                              ),
                              for (final b in batches)
                                DropdownMenuItem<String>(
                                  value: b.batchId,
                                  child: Text(
                                    _batchChoiceLabel(b),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (v) {
                              setState(() => _targetBatchChoice = v ?? '');
                            },
                          ),
                        );
                      },
                    ),
                  TextField(
                    controller: _qtyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Quantidade a adicionar no estoque',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _applyToControllerAndPop,
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        label: const Text('Continuar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PurposeCard extends StatelessWidget {
  const _PurposeCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? IwColors.primaryContainer : IwColors.surfaceContainerLow;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(IwRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(IwRadius.md),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(IwRadius.md),
            border: Border.all(
              width: selected ? 2 : 1,
              color: selected ? IwColors.primary : IwColors.outlineVariant,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 28,
                color: selected ? IwColors.primary : IwColors.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: IwColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: IwColors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle,
                    color: IwColors.primary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
