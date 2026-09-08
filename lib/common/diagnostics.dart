import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class Diagnostics {
  static const maxBytes = 256 * 1024;

  final Future<Directory> Function() _directoryProvider;
  Future<void> _writeQueue = Future.value();

  Diagnostics({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? _defaultDirectory;

  static Future<Directory> _defaultDirectory() async {
    final dataDirectory = await getApplicationSupportDirectory();
    return Directory(join(dataDirectory.path, 'diagnostics'));
  }

  Future<File> get _file async {
    final directory = await _directoryProvider();
    await directory.create(recursive: true);
    return File(join(directory.path, 'diagnostic.log'));
  }

  Future<void> record(Object error, [StackTrace? stackTrace]) {
    _writeQueue = _writeQueue.catchError((_) {}).then((_) async {
      final file = await _file;
      final content = StringBuffer()
        ..writeln(
          '[${DateTime.now().toUtc().toIso8601String()}] ${sanitize(error.toString())}',
        );
      if (stackTrace != null) {
        content.writeln(sanitize(stackTrace.toString()));
      }
      await file.writeAsString(
        content.toString(),
        mode: FileMode.append,
        flush: true,
      );
      final bytes = await file.length();
      if (bytes > maxBytes) {
        final text = await file.readAsString();
        await file.writeAsString(
          text.substring(text.length - maxBytes),
          flush: true,
        );
      }
    });
    return _writeQueue;
  }

  Future<String> read() async {
    final file = await _file;
    if (!await file.exists()) {
      return '';
    }
    return sanitize(await file.readAsString());
  }

  Future<void> clear() {
    _writeQueue = _writeQueue.catchError((_) {}).then((_) async {
      final file = await _file;
      if (await file.exists()) {
        await file.delete();
      }
    });
    return _writeQueue;
  }

  Future<String> exportText() async {
    final buffer = StringBuffer(await read());
    final directory = await _directoryProvider();
    final nativeFile = File(join(directory.path, 'native-crash.log'));
    if (await nativeFile.exists()) {
      buffer
        ..writeln('\n--- native crash log ---')
        ..write(sanitize(await nativeFile.readAsString()));
    }
    return buffer.toString();
  }

  static String sanitize(String value) {
    String redactValue(Match match) => '${match.group(1)}[REDACTED]';

    return value
        .replaceAllMapped(
          RegExp(
            r'(authorization[ \t]*[:=][ \t]*)(?:bearer[ \t]+)?[^ \t,;]+',
            caseSensitive: false,
          ),
          redactValue,
        )
        .replaceAllMapped(
          RegExp(
            r'((?:token|password|secret|api[_-]?key)[ \t]*[:=][ \t]*)([^ \t,;]+)',
            caseSensitive: false,
          ),
          redactValue,
        )
        .replaceAllMapped(
          RegExp(r'(bearer[ \t]+)[^ \t,;]+', caseSensitive: false),
          redactValue,
        )
        .replaceAllMapped(RegExp(r'https?://[^\r\n \t]+'), (match) {
          final uri = Uri.tryParse(match.group(0)!);
          if (uri == null || !uri.hasQuery) {
            return match.group(0)!;
          }
          return '${uri.replace(query: '')}?[REDACTED]';
        });
  }
}

final diagnostics = Diagnostics();
