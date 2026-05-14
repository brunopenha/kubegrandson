import 'package:flutter/material.dart';

import '../../providers/theme/app_colors.dart';

class ClusterOffline extends StatelessWidget {

  final VoidCallback onRetry;

  const ClusterOffline({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
          padding: const EdgeInsetsGeometry.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              const Icon(
                Icons.cloud_off_rounded,
                size: 96,
                color: AppColors.warning,
              ),
              const SizedBox( height: 24,),

              const Text(
                'Cluster Unreachable',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),

              ),

              const Text(
                "Minikube or the configured cluster seems to be not in running state",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),

              ElevatedButton.icon(
                  onPressed: onRetry,
                  label: const Text('Retry Connection'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    )
                  ),
              ),
            ],
          ),
      ),

    );
  }
}
