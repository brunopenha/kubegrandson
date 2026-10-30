import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/kubernetes_provider.dart';
import '../../providers/theme/app_colors.dart';

class MainToolbar extends ConsumerStatefulWidget {
  const MainToolbar({super.key});

  @override
  ConsumerState<MainToolbar> createState() => _MainToolbarState();
}

class _MainToolbarState extends ConsumerState<MainToolbar> {
  final TextEditingController _logSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _logSearchController.text = ref.read(podLogSearchQueryProvider);
    final initialQuery = _logSearchController.text;
    ref.read(podLogSearchHistoryProvider.future).then((terms) {
      if (!mounted ||
          terms.isEmpty ||
          initialQuery.isNotEmpty ||
          ref.read(podLogSearchQueryProvider).isNotEmpty) {
        return;
      }
      ref.read(podLogSearchQueryProvider.notifier).state = terms.first;
    });
  }

  @override
  void dispose() {
    _logSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(podLogSearchQueryProvider, (_, value) {
      if (_logSearchController.text != value) {
        _logSearchController.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
      }
    });
    final history = ref.watch(podLogSearchHistoryProvider).valueOrNull ?? [];
    final filterState = ref.watch(podFilterProvider);
    final logSearchQuery = ref.watch(podLogSearchQueryProvider);
    final isSearchingLogs = ref.watch(isSearchingPodLogsProvider);

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
          Expanded(
            child: TextField(
              controller: _logSearchController,
              decoration: InputDecoration(
                hintText: 'Search logs across pods...',
                prefixIcon: const Icon(Icons.manage_search),
                suffixIcon: logSearchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _logSearchController.clear();
                          clearPodLogSearch(ref);
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              onChanged: (value) {
                ref.read(podLogSearchQueryProvider.notifier).state = value;
                ref.read(podLogSearchMatchesProvider.notifier).state = null;
                if (value.trim().isEmpty) clearPodLogSearch(ref);
              },
              onSubmitted: (_) => searchLogsAcrossPods(ref),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Search history',
            icon: const Icon(Icons.history),
            enabled: history.isNotEmpty,
            onSelected: (term) {
              ref.read(podLogSearchQueryProvider.notifier).state = term;
              ref.read(podLogSearchMatchesProvider.notifier).state = null;
            },
            itemBuilder: (_) => history
                .map((term) => PopupMenuItem(
                      value: term,
                      child: Text(term),
                    ))
                .toList(),
          ),
          IconButton(
            icon: isSearchingLogs
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            onPressed: isSearchingLogs ? null : () => searchLogsAcrossPods(ref),
            tooltip: 'Search the latest 1000 log lines in every pod',
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: AppColors.textPrimary,
            ),
            onPressed: () {
              refreshCurrentPods(ref);
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
