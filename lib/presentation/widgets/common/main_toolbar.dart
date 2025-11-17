import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/kubernetes_provider.dart';
import '../../providers/theme/app_colors.dart';

class MainToolbar extends ConsumerWidget {
  const MainToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterState = ref.watch(podFilterProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search pods...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              onChanged: (value) {
                ref.read(podFilterProvider.notifier).setSearchQuery(value);
              },
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: AppColors.textPrimary,
            ),
            onPressed: () {
              ref.invalidate(currentPodsProvider);
            },
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: Icon(
              Icons.filter_alt,
              color: filterState.selectedPhases.isNotEmpty
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
            onPressed: () {
              // TODO: Show filter dialog
            },
            tooltip: 'Filter',
          ),
        ],
      ),
    );
  }
}