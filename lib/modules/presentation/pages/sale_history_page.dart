import 'package:componentes_lr/componentes_lr.dart' show isDesktopFormFactor;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sale_module/modules/domain/entities/internal_use_purpose.dart';
import 'package:sale_module/modules/domain/entities/sale_history.dart';
import 'package:sale_module/modules/presentation/controllers/sale_home_controller.dart';
import 'package:stock_module/presentation_export.dart';

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
    final desktop = isDesktopFormFactor;
    return IwModulePage(
      onBack: () => Get.back(),
      breadcrumb: desktop
          ? const IwBreadcrumbData(
              icon: Icons.point_of_sale_outlined,
              label: 'Vendas',
              sub: 'Histórico',
            )
          : null,
      body: FutureBuilder<List<SaleHistoryRecord>>(
        future: controller.loadSaleHistory(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorState(
              message:
                  'Não foi possível carregar o histórico.\n${snap.error}',
            );
          }
          final list = snap.data ?? [];
          if (list.isEmpty) return const _EmptyState();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!desktop) ...[
                const _MobileTitle(),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: IwColors.surface,
                    borderRadius: BorderRadius.circular(IwRadius.lg),
                    border: Border.all(color: IwColors.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(
                        height: 1, color: IwColors.outlineVariant),
                    itemBuilder: (c, i) {
                      final r = list[i];
                      return _HistoryRow(
                        record: r,
                        onTap: () => onSaleSelected(r),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MobileTitle extends StatelessWidget {
  const _MobileTitle();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Histórico de vendas',
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
          'Toque para ver os itens.',
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

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.record, required this.onTap});
  final SaleHistoryRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = record.isInternalUse ? IwColors.tertiary : IwColors.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(IwRadius.md),
              ),
              alignment: Alignment.center,
              child: Icon(
                record.isInternalUse
                    ? Icons.inventory_2_outlined
                    : Icons.shopping_bag_outlined,
                color: accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _saleTitle(record),
                    style: const TextStyle(
                      fontFamily: 'RobotoMono',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: IwColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _saleOperationLabel(record),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _saleMetaLine(record),
                    style: const TextStyle(
                      fontSize: 12,
                      color: IwColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: IwColors.onSurfaceVariant, size: 22),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined,
                size: 56, color: IwColors.outline),
            const SizedBox(height: 14),
            const Text(
              'Nenhuma venda encontrada.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: IwColors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Vendas registradas neste aparelho ficam salvas aqui.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: IwColors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

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
          ],
        ),
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
  return v
      .toStringAsFixed(3)
      .replaceAll(RegExp(r'0+$'), '')
      .replaceAll(RegExp(r'\.$'), '');
}

String _formatMoney(double v) =>
    'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
