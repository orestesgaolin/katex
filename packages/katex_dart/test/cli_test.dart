@TestOn('vm')
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Resolves the package root (the directory containing `pubspec.yaml`) so the
/// CLI is launched with the correct working directory regardless of where the
/// test runner is invoked from.
String _packageRoot() {
  var dir = Directory.current.absolute.path;
  while (true) {
    if (File(p.join(dir, 'pubspec.yaml')).existsSync() &&
        Directory(p.join(dir, 'bin')).existsSync() &&
        File(p.join(dir, 'bin', 'katex_dart.dart')).existsSync()) {
      return dir;
    }
    final parent = p.dirname(dir);
    if (parent == dir) {
      fail('Could not locate the katex package root from ${Directory.current}');
    }
    dir = parent;
  }
}

void main() {
  final root = _packageRoot();

  ProcessResult run(List<String> args) => Process.runSync(
    'dart',
    ['run', 'katex_dart', ...args],
    workingDirectory: root,
  );

  test('renders a fraction to valid SVG on stdout (exit 0)', () {
    final result = run([r'\frac{a}{b}']);
    expect(result.exitCode, 0, reason: result.stderr.toString());
    final out = result.stdout as String;
    expect(out, contains('<svg'));
    expect(out, contains('</svg>'));
  });

  test('--display mode renders valid SVG and differs from inline', () {
    final inline = run([r'\frac{a}{b}']);
    final display = run(['--display', r'\frac{a}{b}']);

    expect(display.exitCode, 0, reason: display.stderr.toString());
    final displayOut = display.stdout as String;
    expect(displayOut, contains('<svg'));
    expect(displayOut, contains('</svg>'));

    // Display math typesets differently from inline, so the SVG should differ.
    expect(displayOut, isNot(equals(inline.stdout)));
  });

  test('-d short flag also works', () {
    final result = run(['-d', 'x^2']);
    expect(result.exitCode, 0, reason: result.stderr.toString());
    expect(result.stdout as String, contains('<svg'));
  });

  test('invalid input exits non-zero with a message', () {
    final result = run([r'\frac{a}']);
    expect(result.exitCode, isNot(0));
    final err = result.stderr as String;
    expect(err, isNotEmpty);
    expect(err.toLowerCase(), contains('katex'));
  });

  test('--output writes the SVG to a file', () {
    final tmp = Directory.systemTemp.createTempSync('katex_cli_test');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final outFile = p.join(tmp.path, 'out.svg');

    final result = run(['--output', outFile, r'\frac{a}{b}']);
    expect(result.exitCode, 0, reason: result.stderr.toString());

    final file = File(outFile);
    expect(file.existsSync(), isTrue);
    final contents = file.readAsStringSync();
    expect(contents, contains('<svg'));
    expect(contents, contains('</svg>'));

    // When writing to a file, stdout should not contain the SVG body.
    expect(result.stdout as String, isNot(contains('<svg')));
  });

  test('--font-size scales the output', () {
    final normal = run([r'\frac{a}{b}']);
    final big = run(['--font-size', '2.0', r'\frac{a}{b}']);

    expect(big.exitCode, 0, reason: big.stderr.toString());
    expect(big.stdout as String, contains('<svg'));
    expect(big.stdout, isNot(equals(normal.stdout)));
  });

  test('invalid --font-size exits non-zero with a message', () {
    final result = run(['--font-size', 'huge', r'\frac{a}{b}']);
    expect(result.exitCode, isNot(0));
    expect((result.stderr as String).toLowerCase(), contains('font-size'));
  });

  test('--help prints usage and exits 0', () {
    final result = run(['--help']);
    expect(result.exitCode, 0);
    final out = result.stdout as String;
    expect(out.toLowerCase(), contains('usage'));
  });

  test('missing argument exits non-zero with usage', () {
    final result = run(<String>[]);
    expect(result.exitCode, isNot(0));
    expect((result.stderr as String).toLowerCase(), contains('usage'));
  });
}
