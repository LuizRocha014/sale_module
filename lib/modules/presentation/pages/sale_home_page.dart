import 'package:componentes_lr/componentes_lr.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:in_out_layout/in_out_layout.dart';
import 'package:sale_module/modules/presentation/controllers/sale_home_controller.dart';

class SaleHomePage extends StatefulWidget {
  const SaleHomePage({super.key});

  @override
  State<SaleHomePage> createState() => _SaleHomePageState();
}

class _SaleHomePageState extends State<SaleHomePage> {
  late final SaleHomeController controller =
      Get.put(SaleHomeController(), tag: 'sale_home');

  @override
  void dispose() {
    Get.delete<SaleHomeController>(tag: 'sale_home');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AdaptiveModulePage(
      title: 'Vendas',
      onBack: () => Get.back(),
      body: Center(
        child: TextWidget(
          'sale_module',
          textColor: scheme.onSurface,
          fontSize: isDesktopFormFactor ? 18 : 16,
        ),
      ),
    );
  }
}
