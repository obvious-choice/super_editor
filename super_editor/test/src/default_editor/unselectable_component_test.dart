import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/src/default_editor/selection_upstream_downstream.dart';
import 'package:super_editor/super_editor.dart';

import 'test_documents.dart';

/// This test suite illustrates the difference between interacting with
/// selectable non-text nodes and un-selectable non-text nodes.
///
/// Consider horizontal rules.
///
/// An editor might make HRs selectable so that the user can tap them, select
/// them with the keyboard, and delete them when selected.
///
/// Other editors (like Medium) might make HRs un-selectable. When the user
/// taps on an HR, it doesn't become selected. When the user presses arrow
/// keys that would ordinarily select an HR, the selection behaves as if
/// the HR isn't there.
void main() {
  group("Selectable component", () {
    testWidgets("accepts selection when caret moves down from upstream node", (tester) async {
      final composer = DocumentComposer(
        initialSelection: const DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 11)),
        ),
      );
      await tester.pumpWidget(_buildEditorWithSelectableHrs(paragraphThenHrThenParagraphDoc(), composer));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(composer.selection!.isCollapsed, true);
      expect(composer.selection!.extent.nodeId, "2");
    });

    testWidgets("accepts selection when selection expands down from upstream node", (tester) async {
      final composer = DocumentComposer(
        initialSelection: const DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 11)),
        ),
      );
      await tester.pumpWidget(_buildEditorWithSelectableHrs(paragraphThenHrThenParagraphDoc(), composer));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pump();

      expect(composer.selection!.isCollapsed, false);
      expect(composer.selection!.base.nodeId, "1");
      expect(composer.selection!.extent.nodeId, "2");
    });

    testWidgets("accepts selection when caret moves up from downstream node", (tester) async {
      final composer = DocumentComposer(
        initialSelection: const DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: "3", nodePosition: TextNodePosition(offset: 0)),
        ),
      );
      await tester.pumpWidget(_buildEditorWithSelectableHrs(paragraphThenHrThenParagraphDoc(), composer));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      expect(composer.selection!.isCollapsed, true);
      expect(composer.selection!.extent.nodeId, "2");
    });

    testWidgets("accepts selection when selection expands up from downstream node", (tester) async {
      final composer = DocumentComposer(
        initialSelection: const DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: "3", nodePosition: TextNodePosition(offset: 0)),
        ),
      );
      await tester.pumpWidget(_buildEditorWithSelectableHrs(paragraphThenHrThenParagraphDoc(), composer));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pump();

      expect(composer.selection!.isCollapsed, false);
      expect(composer.selection!.base.nodeId, "3");
      expect(composer.selection!.extent.nodeId, "2");
    });

    testWidgets("accepts selection when user taps on it", (tester) async {
      final composer = DocumentComposer();
      await tester.pumpWidget(_buildEditorWithSelectableHrs(paragraphThenHrThenParagraphDoc(), composer));

      await tester.tap(find.byType(HorizontalRuleComponent));
      await tester.pumpAndSettle();

      expect(composer.selection!.isCollapsed, true);
      expect(composer.selection!.extent.nodeId, "2");
    });

    testWidgets("moves selection to next node when delete pressed from upstream", (tester) async {
      final composer = DocumentComposer(
        initialSelection: const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: 37),
          ),
        ),
      );
      await tester.pumpWidget(_buildEditorWithSelectableHrs(paragraphThenHrThenParagraphDoc(), composer));

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();

      expect(
        composer.selection,
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "2",
            nodePosition: UpstreamDownstreamNodePosition.upstream(),
          ),
        ),
      );
    });

    testWidgets("moves selection to previous node when backspace pressed from downstream", (tester) async {
      final composer = DocumentComposer(
        initialSelection: const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "3",
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
      await tester.pumpWidget(_buildEditorWithSelectableHrs(paragraphThenHrThenParagraphDoc(), composer));

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(
        composer.selection,
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "2",
            nodePosition: UpstreamDownstreamNodePosition.downstream(),
          ),
        ),
      );
    });
  });

  group("Unselectable component", () {
    testWidgets("skips node when down arrow moves caret down from upstream node", (tester) async {
      final composer = DocumentComposer(
        initialSelection: const DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 37)),
        ),
      );
      await tester.pumpWidget(_buildEditorWithUnselectableHrs(paragraphThenHrThenParagraphDoc(), composer));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(composer.selection!.isCollapsed, true);
      expect(composer.selection!.extent.nodeId, "3");
      expect(
        composer.selection!.extent.nodePosition,
        const TextNodePosition(offset: 37, affinity: TextAffinity.upstream),
      );
    });

    testWidgets("skips node when right arrow moves caret down from upstream node", (tester) async {
      final composer = DocumentComposer(
        initialSelection: const DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 37)),
        ),
      );
      await tester.pumpWidget(_buildEditorWithUnselectableHrs(paragraphThenHrThenParagraphDoc(), composer));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(
        composer.selection,
        const DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: "3", nodePosition: TextNodePosition(offset: 0)),
        ),
      );
    });

    testWidgets("rejects selection when down arrow moves caret down from upstream node", (tester) async {
      final composer = DocumentComposer(
        initialSelection: const DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 11)),
        ),
      );
      await tester.pumpWidget(_buildEditorWithUnselectableHrs(paragraphThenHrDoc(), composer));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(
        composer.selection,
        const DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 11)),
        ),
      );
    });

    testWidgets("rejects selection when right arrow moves caret down from upstream node", (tester) async {
      final composer = DocumentComposer(
        initialSelection: const DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 11)),
        ),
      );
      await tester.pumpWidget(_buildEditorWithUnselectableHrs(paragraphThenHrDoc(), composer));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(
        composer.selection,
        const DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 11)),
        ),
      );
    });

    testWidgets("skips node when up arrow moves caret up from downstream node", (tester) async {
      final composer = DocumentComposer(
        initialSelection: const DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: "3", nodePosition: TextNodePosition(offset: 37)),
        ),
      );
      await tester.pumpWidget(_buildEditorWithUnselectableHrs(paragraphThenHrThenParagraphDoc(), composer));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      expect(
        composer.selection,
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: 37, affinity: TextAffinity.upstream),
          ),
        ),
      );
    });

    testWidgets("skips node when left arrow moves caret up from downstream node", (tester) async {
      final composer = DocumentComposer(
        initialSelection: const DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: "3", nodePosition: TextNodePosition(offset: 0)),
        ),
      );
      await tester.pumpWidget(_buildEditorWithUnselectableHrs(paragraphThenHrThenParagraphDoc(), composer));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      expect(
        composer.selection,
        const DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: "1", nodePosition: TextNodePosition(offset: 37)),
        ),
      );
    });

    testWidgets("rejects selection when up arrow moves caret up from downstream node", (tester) async {
      final composer = DocumentComposer(
        initialSelection: const DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: "2", nodePosition: TextNodePosition(offset: 11)),
        ),
      );
      await tester.pumpWidget(_buildEditorWithUnselectableHrs(hrThenParagraphDoc(), composer));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      expect(
        composer.selection,
        const DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: "2", nodePosition: TextNodePosition(offset: 0)),
        ),
      );
    });

    testWidgets("rejects selection when left arrow moves caret up from downstream node", (tester) async {
      final composer = DocumentComposer(
        initialSelection: const DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: "2", nodePosition: TextNodePosition(offset: 0)),
        ),
      );
      await tester.pumpWidget(_buildEditorWithUnselectableHrs(hrThenParagraphDoc(), composer));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      expect(
        composer.selection,
        const DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: "2", nodePosition: TextNodePosition(offset: 0)),
        ),
      );
    });

    testWidgets("deletes downstream node when delete pressed from upstream", (tester) async {
      final document = paragraphThenHrThenParagraphDoc();
      final composer = DocumentComposer(
        initialSelection: const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: 37),
          ),
        ),
      );
      await tester.pumpWidget(_buildEditorWithUnselectableHrs(document, composer));

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();

      expect(
        composer.selection,
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "1",
            nodePosition: TextNodePosition(offset: 37),
          ),
        ),
      );
      expect(document.nodes.length, 2);
      expect(document.nodes.first, isA<ParagraphNode>());
      expect(document.nodes.last, isA<ParagraphNode>());
    });

    testWidgets("deletes upstream node when backspace pressed from downstream", (tester) async {
      final document = paragraphThenHrThenParagraphDoc();
      final composer = DocumentComposer(
        initialSelection: const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "3",
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
      await tester.pumpWidget(_buildEditorWithUnselectableHrs(document, composer));

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(
        composer.selection,
        const DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: "3",
            nodePosition: TextNodePosition(offset: 0),
          ),
        ),
      );
      expect(document.nodes.length, 2);
      expect(document.nodes.first, isA<ParagraphNode>());
      expect(document.nodes.last, isA<ParagraphNode>());
    });

    testWidgets("rejects selection when user taps on it", (tester) async {
      final composer = DocumentComposer();
      await tester.pumpWidget(_buildEditorWithUnselectableHrs(paragraphThenHrThenParagraphDoc(), composer));

      await tester.tap(find.byType(_UnselectableHorizontalRuleComponent));
      await tester.pumpAndSettle();

      expect(composer.selection, isNull);
    });
  });
}

Widget _buildEditorWithSelectableHrs(MutableDocument document, DocumentComposer composer) {
  final editor = DocumentEditor(document: document);

  return MaterialApp(
    home: Scaffold(
      body: SuperEditor(
        editor: editor,
        composer: composer,
        autofocus: true,
        gestureMode: DocumentGestureMode.mouse,
      ),
    ),
  );
}

Widget _buildEditorWithUnselectableHrs(MutableDocument document, DocumentComposer composer) {
  final editor = DocumentEditor(document: document);

  return MaterialApp(
    home: Scaffold(
      body: SuperEditor(
        editor: editor,
        composer: composer,
        autofocus: true,
        componentBuilders: [
          _unselectableHrBuilder,
          ...defaultComponentBuilders,
        ],
        gestureMode: DocumentGestureMode.mouse,
      ),
    ),
  );
}

Widget? _unselectableHrBuilder(ComponentContext context) {
  if (context.documentNode is! HorizontalRuleNode) {
    return null;
  }

  return _UnselectableHorizontalRuleComponent(componentKey: context.componentKey);
}

class _UnselectableHorizontalRuleComponent extends StatelessWidget {
  const _UnselectableHorizontalRuleComponent({
    Key? key,
    required this.componentKey,
  }) : super(key: key);

  final GlobalKey componentKey;

  @override
  Widget build(BuildContext context) {
    return BoxComponent(
      key: componentKey,
      isVisuallySelectable: false,
      child: const Divider(
        color: Color(0xFF000000),
        thickness: 1.0,
      ),
    );
  }
}
