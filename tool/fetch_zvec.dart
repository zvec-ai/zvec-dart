// Fetch the pinned C SDK before a Flutter build or binding regeneration.
// Uses only the Dart SDK and tools shipped with the supported build hosts.
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  try {
    final package = File.fromUri(Platform.script).parent.parent;
    final manifest = jsonDecode(
      File('${package.path}/tool/zvec_sdk.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final headers = args.length == 1 && args.single == '--headers';
    if (!headers &&
        (args.length != 4 || args[0] != '--target' || args[2] != '--output')) {
      throw ArgumentError('Usage: dart tool/fetch_zvec.dart '
          '--target <platform-arch> --output <sdk-directory> | --headers');
    }
    final target = headers ? 'osx-arm64' : args[1];
    final asset = manifest['assets'][target] as Map<String, dynamic>?;
    if (asset == null) throw ArgumentError('Unknown Zvec SDK target: $target');
    final filename = asset['file'] as String;
    final digest = asset['sha256'] as String;
    final output = Directory(
      headers ? '${package.path}/build/zvec-sdk/$target' : args[3],
    ).absolute;
    final url = '${manifest['baseUrl']}/v${manifest['version']}/$filename';
    installSdk(url, filename, digest, output);
    if (headers) {
      final header =
          File('${package.path}/build/zvec-sdk/headers/zvec/c_api.h');
      header.parent.createSync(recursive: true);
      File('${output.path}/include/zvec/c_api.h').copySync(header.path);
    }
  } catch (error) {
    stderr.writeln('Zvec SDK: $error');
    exitCode = 1;
  }
}

String run(String executable, List<String> arguments) {
  final result = Process.runSync(executable, arguments);
  if (result.exitCode != 0) {
    throw ProcessException(
      executable,
      arguments,
      result.stderr.toString(),
      result.exitCode,
    );
  }
  return result.stdout.toString();
}

String checksum(File file) {
  if (Platform.isWindows) {
    final result = run('certutil', ['-hashfile', file.path, 'SHA256']);
    return RegExp(r'^[0-9a-fA-F]{64}$', multiLine: true)
        .firstMatch(result.replaceAll('\r', '').replaceAll(' ', ''))![0]!
        .toLowerCase();
  }
  final result = Platform.isMacOS
      ? run('shasum', ['-a', '256', file.path])
      : run('sha256sum', [file.path]);
  return result.split(RegExp(r'\s')).first;
}

void withLock(File lock, void Function() action) {
  lock.parent.createSync(recursive: true);
  final handle = lock.openSync(mode: FileMode.append);
  try {
    handle.lockSync(FileLock.blockingExclusive);
    action();
  } finally {
    handle.closeSync();
  }
}

File archiveFor(String url, String filename, String digest) {
  final env = Platform.environment;
  final base = env['ZVEC_SDK_CACHE'] ??
      (Platform.isWindows
          ? "${env['LOCALAPPDATA']}/zvec-dart"
          : "${env['HOME']}/.cache/zvec-dart");
  final archive = File('$base/$digest/$filename').absolute;
  withLock(File('${archive.path}.lock'), () {
    if (archive.existsSync() && checksum(archive) == digest) return;
    final partial = File('${archive.path}.part.$pid');
    try {
      stderr.writeln('Downloading $url');
      run(Platform.isWindows ? 'curl.exe' : 'curl', [
        '--fail',
        '--silent',
        '--show-error',
        '--location',
        '--retry',
        '3',
        '--output',
        partial.path,
        url,
      ]);
      if (checksum(partial) != digest) {
        throw StateError('SHA-256 mismatch for $filename');
      }
      partial.renameSync(archive.path);
    } finally {
      if (partial.existsSync()) partial.deleteSync();
    }
  });
  return archive;
}

void installSdk(String url, String filename, String digest, Directory output) {
  const markerName = '.zvec-sdk-sha256';
  withLock(File('${output.path}.lock'), () {
    final marker = File('${output.path}/$markerName');
    final header = File('${output.path}/include/zvec/c_api.h');
    final library = filename.contains('-windows-')
        ? 'lib/zvec_c_api.dll'
        : filename.contains('-osx-')
            ? 'lib/libzvec_c_api.dylib'
            : filename.contains('-ios.')
                ? 'libzvec_c_api.xcframework/Info.plist'
                : 'lib/libzvec_c_api.so';
    if (marker.existsSync() &&
        marker.readAsStringSync() == digest &&
        header.existsSync() &&
        File('${output.path}/$library').existsSync()) {
      return;
    }
    if (output.existsSync() &&
        !marker.existsSync() &&
        output
            .listSync(recursive: true, followLinks: false)
            .any((entry) => entry is! Directory)) {
      throw StateError('Choose an empty SDK output directory: ${output.path}');
    }
    final archive = archiveFor(url, filename, digest);
    final stage = output.parent.createTempSync('.zvec-sdk-');
    try {
      if (filename.endsWith('.zip') && Platform.isLinux) {
        run('unzip', ['-q', archive.path, '-d', stage.path]);
      } else {
        // Git Bash puts GNU tar ahead of the Windows inbox tar, which also
        // handles ZIP archives produced by PowerShell.
        final tar = Platform.isWindows
            ? '${Platform.environment['SystemRoot']}/System32/tar.exe'
            : Platform.isMacOS
                ? '/usr/bin/tar'
                : 'tar';
        run(tar, ['-xf', archive.path, '-C', stage.path]);
      }
      if (!File('${stage.path}/include/zvec/c_api.h').existsSync() ||
          !File('${stage.path}/$library').existsSync()) {
        throw StateError('Incomplete SDK in $filename');
      }
      File('${stage.path}/$markerName').writeAsStringSync(digest);
      if (output.existsSync()) output.deleteSync(recursive: true);
      stage.renameSync(output.path);
    } finally {
      if (stage.existsSync()) stage.deleteSync(recursive: true);
    }
  });
}
