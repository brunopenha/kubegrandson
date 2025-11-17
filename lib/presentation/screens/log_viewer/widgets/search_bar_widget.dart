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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  onPressed: () {
                    _controller.clear();
                    ref
                        .read(logProvider(widget.podKey).notifier)
                        .setSearchQuery('');
                  },
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
              },
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            onPressed: () {
              // TODO: Previous match
            },
            tooltip: 'Previous match',
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward),
            onPressed: () {
              // TODO: Next match
            },
            tooltip: 'Next match',
          ),
        ],
      ),
    );
  }
}