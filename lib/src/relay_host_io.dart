import 'dart:io';

/// Starts the local mail and SMS relay when this desktop build can see it.
Future<void> ensureRelay() async {
  if (await _portOpen()) {
    return;
  }
  final Directory? root = _projectRoot();
  if (root == null) {
    return;
  }
  try {
    await Process.start(
      'cmd.exe',
      <String>['/c', 'dart', 'run', 'tool/mail_server.dart'],
      workingDirectory: root.path,
      mode: ProcessStartMode.detached,
    );
  } catch (_) {
    return;
  }
  for (int attempt = 0; attempt < 20; attempt++) {
    if (await _portOpen()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
}

Future<bool> _portOpen() async {
  try {
    final Socket socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      8787,
      timeout: const Duration(milliseconds: 400),
    );
    await socket.close();
    return true;
  } catch (_) {
    return false;
  }
}

Directory? _projectRoot() {
  final List<Directory> seeds = <Directory>[
    Directory.current,
    File(Platform.resolvedExecutable).parent,
  ];
  for (final Directory seed in seeds) {
    Directory dir = seed;
    for (int i = 0; i < 8; i++) {
      final String tool = '${dir.path}${Platform.pathSeparator}tool';
      final bool ready =
          File('$tool${Platform.pathSeparator}mail_server.dart').existsSync() &&
          File('$tool${Platform.pathSeparator}local.env').existsSync();
      if (ready) {
        return dir;
      }
      final Directory parent = dir.parent;
      if (parent.path == dir.path) {
        break;
      }
      dir = parent;
    }
  }
  return null;
}
