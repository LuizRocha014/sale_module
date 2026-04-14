import 'package:flutter/material.dart';
import 'package:sale_module/modules/domain/entities/internal_use_purpose.dart';
import 'package:sale_module/modules/domain/entities/sale_history.dart';
import 'package:sale_module/modules/presentation/controllers/sale_home_controller.dart';

/// Lista de vendas em tela cheia (substitui o antigo bottom sheet do histórico).
class SaleHistoryPage extends StatelessWidget {
  const SaleHistoryPage({
    super.key,
    required this.controller,
    required this.onSaleSelected,
  });

  final SaleHomeController controller;
  final Future<void> Function(SaleHistoryRecord r) onSaleSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de vendas'),
      ),
      body: FutureBuilder<List<SaleHistoryRecord>>(
        future: controller.loadSaleHistory(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Não foi possível carregar o histórico.\n${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nenhuma venda encontrada.',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vendas registradas neste aparelho ficam salvas aqui. Com GET /api/inventory/sales no servidor, a lista também vem da API.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'Vendas realizadas',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Toque para ver os itens.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (c, i) {
                    final r = list[i];
                    return ListTile(
                      leading: Icon(
                        r.isInternalUse
                            ? Icons.inventory_2_outlined
                            : Icons.shopping_bag_outlined,
                      ),
                      title: Text(_saleTitle(r)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _saleOperationLabel(r),
                            style: Theme.of(c).textTheme.labelLarge?.copyWith(
                                  color: Theme.of(c).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _saleMetaLine(r),
                            style: Theme.of(c).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => onSaleSelected(r),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _fmtSaleDate(DateTime? d) {
  if (d == null) return 'Data não informada';
  final l = d.toLocal();
  String two(int n) => n < 10 ? '0$n' : '$n';
  return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
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

String _saleMetaLine(SaleHistoryRecord r) {
  final buf = StringBuffer(_fmtSaleDate(r.occurredAt));
  if (r.internalUsePurpose == InternalUsePurpose.newProduct.name &&
      r.outputProductName != null &&
      r.outputQuantity != null) {
    buf.write(' · +${_formatQty(r.outputQuantity!)} ${r.outputProductName}');
  }
  if (r.totalAmount != null) {
    buf.write(' · ${_formatMoney(r.totalAmount!)}');
  }
  return buf.toString();
}

String _formatQty(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
}

String _formatMoney(double v) =>
    'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
