/// Flutter-web host for the comparison site's third column (T-024).
///
/// Renders the whole comparison gallery as a single scrollable column of
/// `Math` widgets — one Flutter engine for the entire page, embedded in the
/// Jaspr site via one `<iframe src="flutter/index.html">`. A single engine is
/// far more reliable and lighter than one iframe (engine) per row.
///
/// Layout mirrors the Jaspr list exactly so the iframe's rows line up with the
/// KaTeX-JS / Dart-SVG rows beside it: each category heading is
/// [kHeadingHeight] tall and each example row is [kRowHeight] tall, in the same
/// order as `examples.dart`.
library;

import 'package:flutter/material.dart';
import 'package:katex_flutter/katex_flutter.dart';

import 'examples.dart';

/// Heading row height (px) — must match `app.dart`'s `kHeadingHeight`.
const double kHeadingHeight = 64;

/// Example row height (px) — must match `comparison_row.dart`'s `kRowHeight`.
const double kRowHeight = 120;

void main() => runApp(const FlutterHostApp());

class FlutterHostApp extends StatelessWidget {
  const FlutterHostApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'katex_flutter gallery',
      theme: ThemeData(scaffoldBackgroundColor: Colors.white),
      home: const GalleryPage(),
    );
  }
}

class GalleryPage extends StatelessWidget {
  const GalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = <Widget>[];
    for (final ExampleGroup group in kGroups) {
      children.add(_HeadingRow(group.title));
      for (final Example ex in group.examples) {
        children.add(_ExampleRow(ex));
      }
    }
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: children,
      ),
    );
  }
}

class _HeadingRow extends StatelessWidget {
  const _HeadingRow(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kHeadingHeight,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF222222), width: 2),
        ),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A1A1A),
        ),
      ),
    );
  }
}

class _ExampleRow extends StatelessWidget {
  const _ExampleRow(this.example);

  final Example example;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: kRowHeight),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFEEEEEE)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          // Mirror the TeX-source label so rows are identifiable in isolation.
          Text(
            example.tex,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: Color(0xFF57606A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(4),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Math(
                  example.tex,
                  displayMode: example.displayMode,
                  fontSize: 22,
                  onError: (BuildContext context, Object error) => Text(
                    'error: $error',
                    style: const TextStyle(
                      color: Color(0xFFCC0000),
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
