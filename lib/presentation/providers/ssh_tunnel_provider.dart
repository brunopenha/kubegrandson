import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/services/ssh_tunnel_service.dart';

final sshTunnelProvider = ChangeNotifierProvider<SshTunnelService>((ref) {
  return SshTunnelService();
});
