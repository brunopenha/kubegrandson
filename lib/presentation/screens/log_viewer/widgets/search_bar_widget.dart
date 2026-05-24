import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/log_provider.dart';
import '../../../providers/theme/app_colors.dart';

class LogSearchBar extends ConsumerStatefulWidget {
  final String podKey;

  const LogSearchBar({
    super.key,
    required this.podKey,
  });

  @override
  ConsumerState<LogSearchBar> createState() => _LogSearchBarState();
}

class _LogSearchBarState extends ConsumerState<LogSearchBar> {
  final TextEditingController _controller = TextEditingController();

  void _clearSearch() {
    _controller.clear();
    ref.read(logProvider(widget.podKey).notifier).setSearchQuery('');
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logState = ref.watch(logProvider(widget.podKey));
    final logNotifier = ref.read(logProvider(widget.podKey).notifier);
    final matchCount = logNotifier.searchMatchCount;
    final hitCount = logNotifier.searchHitCount;
    final selectedMatchNumber = logNotifier.selectedSearchMatchNumber;
    final hasSearch = logState.searchQuery.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
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
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Search logs...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                        tooltip: 'Clear search',
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              onChanged: (value) {
                ref
                    .read(logProvider(widget.podKey).notifier)
                    .setSearchQuery(value);
                setState(() {});
              },
            ),
          ),
          const SizedBox(width: 12),
          if (hasSearch) ...[
            _SearchCounter(
              selectedMatchNumber: selectedMatchNumber,
              matchCount: matchCount,
              hitCount: hitCount,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.search_off),
              onPressed: _clearSearch,
              tooltip: 'Clear search',
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            onPressed: matchCount == 0
                ? null
                : () {
                    ref.read(logProvider(widget.podKey).notifier).goToPreviousSearchMatch();
                  },
            tooltip: 'Previous match',
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward),
            onPressed: matchCount == 0
                ? null
                : () {
                    ref.read(logProvider(widget.podKey).notifier).goToNextSearchMatch();
                  },
            tooltip: 'Next match',
          ),
        ],
      ),
    );
  }
}

class _SearchCounter extends StatelessWidget {
  final int selectedMatchNumber;
  final int matchCount;
  final int hitCount;

  const _SearchCounter({
    required this.selectedMatchNumber,
    required this.matchCount,
    required this.hitCount,
  });

  @override
  Widget build(BuildContext context) {
    final color = matchCount == 0 ? AppColors.error : AppColors.textSecondary;
    final selectedText = selectedMatchNumber == 0
        ? matchCount.toString()
        : '$selectedMatchNumber/$matchCount';
    final hitLabel = hitCount == 1 ? 'hit' : 'hits';

    return Tooltip(
      message: '$hitCount $hitLabel in $matchCount lines',
      child: Text(
        matchCount == 0 ? '0 matches' : '$selectedText lines, $hitCount hits',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
