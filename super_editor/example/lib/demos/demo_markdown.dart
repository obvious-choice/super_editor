import 'dart:async';

import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import 'example_editor/example_editor.dart';

class MarkDownDemo extends StatefulWidget {
  const MarkDownDemo({Key? key}) : super(key: key);

  @override
  _MarkDownDemoState createState() => _MarkDownDemoState();
}

class _MarkDownDemoState extends State<MarkDownDemo> {
  final _docKey = GlobalKey();
  late Document _doc;
  late DocumentEditor _docEditor;
  late Document _convertedDoc;
  late DocumentEditor _convertedDocEditor;

  String _markdown = '';

  Timer? _updateTimer;
  final _markdownUpdateWaitTime = const Duration(milliseconds: 250);

  @override
  void initState() {
    super.initState();
    _doc = _createInitialDocument()..addListener(_onDocumentChange);
    _docEditor = DocumentEditor(document: _doc as MutableDocument);
    _convertedDoc = _createInitialDocument();
    _convertedDocEditor = DocumentEditor(document: _convertedDoc as MutableDocument);
    _updateMarkdown();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _onDocumentChange() {
    _updateTimer?.cancel();
    _updateTimer = Timer(_markdownUpdateWaitTime, _updateMarkdownAndRebuild);
  }

  void _updateMarkdownAndRebuild() {
    setState(() {
      _updateMarkdown();
    });
  }

  void _updateMarkdown() {
    _markdown = serializeDocumentToMarkdown(_doc);
    _convertedDoc = deserializeMarkdownToDocument(_markdown);
    _convertedDocEditor = DocumentEditor(document: _convertedDoc as MutableDocument);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ExampleEditor(
              docEditor: _docEditor,
              doc: _doc,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: double.infinity,
            color: const Color(0xFF222222),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Text(
                  _markdown,
                  style: const TextStyle(
                    color: Color(0xFFEEEEEE),
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SuperEditor(
              // key: _docKey,
              editor: _convertedDocEditor,
              maxWidth: 600,
              padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
            ),
          ),
        ),
      ],
    );
  }
}

Document _createInitialDocument() {
  return MutableDocument(
    nodes: [
      ImageNode(
        id: DocumentEditor.createNodeId(),
        imageUrl: 'https://i.imgur.com/fSZwM7G.jpg',
      ),
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text: '0123456789',
          spans: AttributedSpans(attributions: [
            SpanMarker(attribution: SuperscriptAttribution(), offset: 0, markerType: SpanMarkerType.start),
            SpanMarker(attribution: SuperscriptAttribution(), offset: 0, markerType: SpanMarkerType.end),
            SpanMarker(attribution: SuperscriptAttribution(), offset: 1, markerType: SpanMarkerType.start),
            SpanMarker(attribution: SuperscriptAttribution(), offset: 1, markerType: SpanMarkerType.end)
          ]),
        ),
      ),
    ],
  );
}
