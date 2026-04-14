import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:sale_module/modules/domain/entities/internal_use_purpose.dart';
import 'package:stock_module/modules/domain/entities/product_stock_detail_entity.dart';
import 'package:sale_module/modules/presentation/controllers/sale_home_controller.dart';

/// Fluxo em sheet: escolha da finalidade e, se produção, produto + quantidade.
Future<bool?> showSaleInternalUseConfirmSheet(
  BuildContext context,
  SaleHomeController controller,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) => _SaleInternalUseConfirmBody(controller: controller),
  );
}

class _SaleInternalUseConfirmBody extends StatefulWidget {
  const _SaleInternalUseConfirmBody({required this.controller});

  final SaleHomeController controller;

  @override
  State<_SaleInternalUseConfirmBody> createState() => _SaleInternalUseConfirmBodyState();
}

class _SaleInternalUseConfirmBodyState extends State<_SaleInternalUseConfirmBody> {
  InternalUsePurpose _mode = InternalUsePurpose.company;
  String? _outputProductId;
  String? _outputProductName;
  /// Vazio = novo lote; senão `batchId` do lote que receberá a quantidade.
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
        Get.snackbar('Uso interno', 'Selecione o produto que receberá entrada no estoque.');
        return;
      }
      final raw = _qtyCtrl.text.replaceAll(',', '.').trim();
      final oq = double.tryParse(raw);
      if (oq == null || oq <= 0) {
        Get.snackbar('Uso interno', 'Informe a quantidade a adicionar no estoque.');
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final c = widget.controller;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Obx(
        () {
          c.rows.length;
          c.filterQuery.value;
          final products = c.groupedProducts;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Uso interno',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'O carrinho será baixado. O que representa este movimento?',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 20),
                  _PurposeCard(
                    selected: _mode == InternalUsePurpose.company,
                    icon: Icons.business_outlined,
                    title: 'Uso da empresa',
                    subtitle: 'Consumo interno, granel ou porções. Não gera entrada em outro produto.',
                    onTap: () => setState(() => _mode = InternalUsePurpose.company),
                  ),
                  const SizedBox(height: 12),
                  _PurposeCard(
                    selected: _mode == InternalUsePurpose.newProduct,
                    icon: Icons.add_box_outlined,
                    title: 'Entrada em produto no estoque',
                    subtitle:
                        'Produção ou montagem: indique o produto acabado e quanto entra no estoque.',
                    onTap: () => setState(() => _mode = InternalUsePurpose.newProduct),
                  ),
                  if (_mode == InternalUsePurpose.newProduct) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Produto que recebe a entrada',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    InputDecorator(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Produto',
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: const Text('Selecione'),
                          value: () {
                            final id = _outputProductId;
                            final ids = products.map((e) => e.productId).toSet();
                            return id != null && ids.contains(id) ? id : null;
                          }(),
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
                                  final p = products.firstWhere((e) => e.productId == id);
                                  setState(() {
                                    _outputProductId = p.productId;
                                    _outputProductName = p.productName;
                                    _targetBatchChoice = '';
                                  });
                                },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_outputProductId != null && _outputProductId!.isNotEmpty)
                      FutureBuilder<List<StockBatchDetailEntity>>(
                        key: ValueKey<String>(_outputProductId!),
                        future: c.loadActiveBatchesForOutputProduct(_outputProductId!),
                        builder: (ctx, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: LinearProgressIndicator(),
                            );
                          }
                          final batches = snap.data ?? [];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Somar quantidade em',
                                helperText:
                                    'Escolha um lote ativo ou crie um novo lote com esta entrada.',
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: () {
                                    if (_targetBatchChoice.isEmpty) return '';
                                    final ids = batches.map((e) => e.batchId).toSet();
                                    return ids.contains(_targetBatchChoice) ? _targetBatchChoice : '';
                                  }(),
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
                              ),
                            ),
                          );
                        },
                      ),
                    TextField(
                      controller: _qtyCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Quantidade a adicionar no estoque',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                      ],
                    ),
                  ],
                  const SizedBox(height: 28),
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
                        child: FilledButton(
                          onPressed: _applyToControllerAndPop,
                          child: const Text('Continuar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _batchChoiceLabel(StockBatchDetailEntity b) {
    final v = b.expirationDate;
    final vd = v == null ? 's/ val.' : '${v.day.toString().padLeft(2, '0')}/${v.month.toString().padLeft(2, '0')}/${v.year}';
    return '$vd · ${b.quantityLabel} · ${b.costLabel}';
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
    final scheme = Theme.of(context).colorScheme;
    final border = Border.all(
      width: selected ? 2 : 1,
      color: selected ? scheme.primary : scheme.outlineVariant,
    );
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: border),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28, color: selected ? scheme.primary : scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: scheme.primary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
