import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/widgets/dd_card.dart';
import '../../core/widgets/dd_button.dart';
import '../../core/widgets/dd_loading.dart';
import '../../core/widgets/dd_text_field.dart';
import '../../data/local/models/app_models.dart';
import '../../data/repositories/app_repositories.dart';
import '../../data/remote/auth_service.dart';
import '../home/home_dashboard_screen.dart';

class RefillsScreen extends ConsumerWidget {
  const RefillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allMedsAsync = ref.watch(allActiveMedsProvider);
    final lowStockAsync = ref.watch(lowStockProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Refills'),
        automaticallyImplyLeading: false,
      ),
      body: allMedsAsync.when(
        loading: () => const DdLoading(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (meds) {
          if (meds.isEmpty) {
            return const DdEmptyState(
              icon: Icons.medication_liquid_outlined,
              title: 'No medications',
              subtitle: 'Add medications to track refills.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppDimensions.screenMargin),
            children: [
              // Low stock alert
              lowStockAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (lowMeds) {
                  if (lowMeds.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppDimensions.stackLg),
                    child: DdCard(
                      borderColor: AppColors.skippedForeground.withOpacity(0.4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: AppColors.skippedForeground),
                              const SizedBox(width: 8),
                              Text('Low Stock Alert', style: AppTextStyles.bodyBold(color: AppColors.skippedForeground)),
                            ],
                          ),
                          const SizedBox(height: AppDimensions.stackSm),
                          Text(
                            '${lowMeds.length} medication${lowMeds.length > 1 ? 's are' : ' is'} running low',
                            style: AppTextStyles.bodyLg(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              Text('All Medications', style: AppTextStyles.headlineMd()),
              const SizedBox(height: AppDimensions.stackMd),

              for (final med in meds) ...[
                _RefillCard(med: med),
                const SizedBox(height: AppDimensions.stackMd),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RefillCard extends StatelessWidget {
  const _RefillCard({required this.med});
  final Medication med;

  @override
  Widget build(BuildContext context) {
    final qty = med.quantityOnHand;
    final threshold = med.refillThresholdQty;
    final isLow = med.isLowStock;

    return DdCard(
      borderColor: isLow ? AppColors.skippedForeground.withOpacity(0.4) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(med.name, style: AppTextStyles.bodyBold()),
                    Text(med.displayStrength, style: AppTextStyles.caption()),
                  ],
                ),
              ),
              if (isLow)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.skippedBackground,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'LOW',
                    style: AppTextStyles.statusBadge(color: AppColors.skippedForeground),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.stackMd),
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                '${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 1)} ${med.quantityUnit} remaining',
                style: AppTextStyles.bodyLg(color: isLow ? AppColors.skippedForeground : AppColors.textSecondary),
              ),
            ],
          ),
          if (threshold != null) ...[
            const SizedBox(height: AppDimensions.stackSm),
            Row(
              children: [
                const Icon(Icons.notifications_outlined, size: 16, color: AppColors.textTertiary),
                const SizedBox(width: 6),
                Text(
                  'Refill reminder at ${threshold.toStringAsFixed(0)} ${med.quantityUnit}',
                  style: AppTextStyles.caption(),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppDimensions.stackLg),
          DdButton(
            label: 'Record Refill',
            onPressed: () => context.push('/refills/confirm/${med.id}'),
            icon: const Icon(Icons.add_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// ── Refill Confirm ─────────────────────────────────────────────────────────────

class RefillConfirmScreen extends ConsumerStatefulWidget {
  const RefillConfirmScreen({super.key, required this.medicationId});
  final String medicationId;

  @override
  ConsumerState<RefillConfirmScreen> createState() => _RefillConfirmScreenState();
}

class _RefillConfirmScreenState extends ConsumerState<RefillConfirmScreen> {
  final _qtyCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm(Medication med) async {
    final qty = double.tryParse(_qtyCtrl.text);
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid quantity')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userId = AuthService.currentUser?.id ?? med.userId;
      await ref.read(refillRepositoryProvider).recordRefill(
        medicationId: med.id,
        userId: userId,
        quantityAdded: qty,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      ref.invalidate(allActiveMedsProvider);
      ref.invalidate(lowStockProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Refill recorded: +${qty.toStringAsFixed(0)} ${med.quantityUnit}')),
      );
      context.pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final medAsync = ref.watch(medicationByIdProvider(widget.medicationId));

    return Scaffold(
      appBar: AppBar(title: const Text('Record Refill')),
      backgroundColor: AppColors.scaffoldBackground,
      body: medAsync.when(
        loading: () => const DdLoadingScreen(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (med) {
          if (med == null) return const Center(child: Text('Not found'));
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.screenMargin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(med.name, style: AppTextStyles.headlineLg()),
                Text(med.displayStrength, style: AppTextStyles.bodyLg(color: AppColors.textSecondary)),
                const SizedBox(height: AppDimensions.stackLg),
                DdCard(
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        'Current stock: ${med.quantityOnHand.toStringAsFixed(0)} ${med.quantityUnit}',
                        style: AppTextStyles.bodyBold(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.stackXl),
                DdTextField(
                  label: 'Quantity added (${med.quantityUnit})',
                  hint: 'e.g. 30',
                  controller: _qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                ),
                const SizedBox(height: AppDimensions.stackLg),
                DdTextField(
                  label: 'Note (optional)',
                  hint: 'e.g. New prescription',
                  controller: _noteCtrl,
                  maxLines: 2,
                ),
                const SizedBox(height: AppDimensions.stackXl),
                DdButton(
                  label: 'Confirm Refill',
                  onPressed: () => _confirm(med),
                  isLoading: _isLoading,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
