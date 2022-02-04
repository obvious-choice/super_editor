import 'dart:collection';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide SelectableText;
import 'package:flutter/services.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_editor.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/document_selection.dart';
import 'package:super_editor/src/core/edit_context.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';
import 'package:super_editor/src/infrastructure/attributed_spans.dart';
import 'package:super_editor/src/infrastructure/attributed_text.dart';
import 'package:super_editor/src/infrastructure/composable_text.dart';
import 'package:super_editor/src/infrastructure/keyboard.dart';
import 'package:super_editor/src/infrastructure/raw_key_event_extensions.dart';
import 'package:super_editor/src/infrastructure/super_selectable_text.dart';

import 'document_input_keyboard.dart';

class TextNode with ChangeNotifier implements DocumentNode {
  TextNode({
    required this.id,
    required AttributedText text,
    Map<String, dynamic>? metadata,
  })  : _text = text,
        _metadata = metadata ?? {} {
    _text.addListener(notifyListeners);
  }

  @override
  void dispose() {
    _text.removeListener(notifyListeners);
    super.dispose();
  }

  @override
  final String id;

  AttributedText _text;
  AttributedText get text => _text;
  set text(AttributedText newText) {
    if (newText != _text) {
      _text.removeListener(notifyListeners);
      _text = newText;
      _text.addListener(notifyListeners);

      notifyListeners();
    }
  }

  final Map<String, dynamic> _metadata;
  Map<String, dynamic> get metadata => _metadata;

  @override
  TextNodePosition get beginningPosition => const TextNodePosition(offset: 0);

  @override
  TextNodePosition get endPosition => TextNodePosition(offset: text.text.length);

  @override
  NodePosition selectUpstreamPosition(NodePosition position1, NodePosition position2) {
    if (position1 is! TextNodePosition) {
      throw Exception('Expected a TextNodePosition for position1 but received a ${position1.runtimeType}');
    }
    if (position2 is! TextNodePosition) {
      throw Exception('Expected a TextNodePosition for position2 but received a ${position2.runtimeType}');
    }

    return position1.offset < position2.offset ? position1 : position2;
  }

  @override
  NodePosition selectDownstreamPosition(NodePosition position1, NodePosition position2) {
    if (position1 is! TextNodePosition) {
      throw Exception('Expected a TextNodePosition for position1 but received a ${position1.runtimeType}');
    }
    if (position2 is! TextNodePosition) {
      throw Exception('Expected a TextNodePosition for position2 but received a ${position2.runtimeType}');
    }

    return position1.offset > position2.offset ? position1 : position2;
  }

  @override
  TextNodeSelection computeSelection({
    required NodePosition base,
    required NodePosition extent,
  }) {
    assert(base is TextNodePosition);
    assert(extent is TextNodePosition);

    return TextNodeSelection(
      baseOffset: (base as TextNodePosition).offset,
      extentOffset: (extent as TextNodePosition).offset,
    );
  }

  @override
  String copyContent(dynamic selection) {
    assert(selection is TextSelection);

    return (selection as TextSelection).textInside(text.text);
  }

  @override
  bool hasEquivalentContent(DocumentNode other) {
    return other is TextNode && text == other.text && const DeepCollectionEquality().equals(metadata, other.metadata);
  }

  @override
  String toString() => '[TextNode] - text: $text, metadata: $metadata';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextNode &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          _text == other._text &&
          const DeepCollectionEquality.unordered().equals(_metadata, other._metadata);

  @override
  int get hashCode => id.hashCode ^ _text.hashCode ^ _metadata.hashCode;
}

extension DocumentSelectionWithText on Document {
  /// Returns `true` if all the text within the given [selection] contains at least
  /// some characters with each of the given [attributions].
  ///
  /// All non-text content is ignored.
  bool doesSelectedTextContainAttributions(DocumentSelection selection, Set<Attribution> attributions) {
    final nodes = getNodesInside(selection.base, selection.extent);
    if (nodes.isEmpty) {
      return false;
    }

    // Calculate a DocumentRange so we know which DocumentPosition
    // belongs to the first node, and which belongs to the last node.
    final nodeRange = getRangeBetween(selection.base, selection.extent);

    for (final textNode in nodes) {
      if (textNode is! TextNode) {
        continue;
      }

      int startOffset = -1;
      int endOffset = -1;

      if (textNode == nodes.first && textNode == nodes.last) {
        // Handle selection within a single node
        final baseOffset = (selection.base.nodePosition as TextPosition).offset;
        final extentOffset = (selection.extent.nodePosition as TextPosition).offset;
        startOffset = baseOffset < extentOffset ? baseOffset : extentOffset;
        endOffset = baseOffset < extentOffset ? extentOffset : baseOffset;

        // -1 because TextPosition's offset indexes the character after the
        // selection, not the final character in the selection.
        endOffset -= 1;
      } else if (textNode == nodes.first) {
        // Handle partial node selection in first node.
        startOffset = (nodeRange.start.nodePosition as TextPosition).offset;
        endOffset = max(textNode.text.text.length - 1, 0);
      } else if (textNode == nodes.last) {
        // Handle partial node selection in last node.
        startOffset = 0;

        // -1 because TextPosition's offset indexes the character after the
        // selection, not the final character in the selection.
        endOffset = (nodeRange.end.nodePosition as TextPosition).offset - 1;
      } else {
        // Handle full node selection.
        startOffset = 0;
        endOffset = max(textNode.text.text.length - 1, 0);
      }

      final selectionRange = TextRange(start: startOffset, end: endOffset);

      if (textNode.text.hasAttributionsWithin(
        attributions: attributions,
        range: selectionRange,
      )) {
        return true;
      }
    }

    return false;
  }
}

/// A logical selection within a [TextNode].
///
/// The selection begins at [baseOffset] and ends at [extentOffset].
class TextNodeSelection extends TextSelection implements NodeSelection {
  TextNodeSelection.fromTextSelection(TextSelection textSelection)
      : super(
          baseOffset: textSelection.baseOffset,
          extentOffset: textSelection.extentOffset,
          affinity: textSelection.affinity,
          isDirectional: textSelection.isDirectional,
        );

  const TextNodeSelection.collapsed({
    required int offset,
    TextAffinity affinity = TextAffinity.downstream,
  }) : super(
          baseOffset: offset,
          extentOffset: offset,
          affinity: affinity,
        );

  const TextNodeSelection({
    required int baseOffset,
    required int extentOffset,
    TextAffinity affinity = TextAffinity.downstream,
    bool isDirectional = false,
  }) : super(
          baseOffset: baseOffset,
          extentOffset: extentOffset,
          affinity: affinity,
          isDirectional: isDirectional,
        );

  @override
  TextNodePosition get base => TextNodePosition(offset: baseOffset);

  @override
  TextNodePosition get extent => TextNodePosition(offset: extentOffset);
}

/// A logical position within a [TextNode].
class TextNodePosition extends TextPosition implements NodePosition {
  TextNodePosition.fromTextPosition(TextPosition position)
      : super(offset: position.offset, affinity: position.affinity);

  const TextNodePosition({
    required int offset,
    TextAffinity affinity = TextAffinity.downstream,
  }) : super(offset: offset, affinity: affinity);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other && other is TextNodePosition && runtimeType == other.runtimeType && offset == other.offset;

  @override
  int get hashCode => super.hashCode ^ super.offset.hashCode;
}

/// Document component that displays hint text when its content text
/// is empty.
///
/// Internally uses a [TextComponent] to display the content text.
class TextWithHintComponent extends StatefulWidget {
  const TextWithHintComponent({
    Key? key,
    required this.text,
    this.hintText,
    this.hintStyleBuilder,
    this.textAlign,
    this.textDirection,
    required this.textStyleBuilder,
    this.metadata = const {},
    this.textSelection,
    this.selectionColor = Colors.lightBlueAccent,
    this.showCaret = false,
    this.caretColor = Colors.black,
    this.highlightWhenEmpty = false,
    this.showDebugPaint = false,
  }) : super(key: key);

  final AttributedText text;
  final AttributedText? hintText;
  final AttributionStyleBuilder? hintStyleBuilder;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final AttributionStyleBuilder textStyleBuilder;
  final Map<String, dynamic> metadata;
  final TextSelection? textSelection;
  final Color selectionColor;
  final bool showCaret;
  final Color caretColor;
  final bool highlightWhenEmpty;
  final bool showDebugPaint;

  @override
  _TextWithHintComponentState createState() => _TextWithHintComponentState();
}

class _TextWithHintComponentState extends State<TextWithHintComponent>
    with ProxyDocumentComponent<TextWithHintComponent>, ProxyTextComposable {
  final _childTextComponentKey = GlobalKey<_TextComponentState>();

  @override
  DocumentComponent<StatefulWidget> get childDocumentComponentKey => _childTextComponentKey.currentState!;

  @override
  TextComposable get childTextComposable => _childTextComponentKey.currentState!;

  TextStyle _styleBuilder(Set<Attribution> attributions) {
    final attributionsWithBlock = Set.of(attributions);
    final blockType = widget.metadata['blockType'];
    if (blockType != null && blockType is Attribution) {
      attributionsWithBlock.add(blockType);
    }

    final contentStyle = widget.textStyleBuilder(attributionsWithBlock);
    final hintStyle = contentStyle.merge(widget.hintStyleBuilder?.call(attributionsWithBlock) ?? const TextStyle());
    return hintStyle;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (widget.text.text.isEmpty)
          Text.rich(
            widget.hintText?.computeTextSpan(_styleBuilder) ?? const TextSpan(text: ''),
          ),
        TextComponent(
          key: _childTextComponentKey,
          text: widget.text,
          textAlign: widget.textAlign,
          textDirection: widget.textDirection,
          textStyleBuilder: widget.textStyleBuilder,
          metadata: widget.metadata,
          textSelection: widget.textSelection,
          selectionColor: widget.selectionColor,
          showCaret: widget.showCaret,
          caretColor: widget.caretColor,
          highlightWhenEmpty: widget.highlightWhenEmpty,
          showDebugPaint: widget.showDebugPaint,
        ),
      ],
    );
  }
}

/// Displays text in a document.
///
/// This is the standard component for text display.
class TextComponent extends StatefulWidget {
  const TextComponent({
    Key? key,
    required this.text,
    this.textAlign,
    this.textDirection,
    required this.textStyleBuilder,
    this.metadata = const {},
    this.textSelection,
    this.selectionColor = Colors.lightBlueAccent,
    this.showCaret = false,
    this.caretColor = Colors.black,
    this.highlightWhenEmpty = false,
    this.showDebugPaint = false,
  }) : super(key: key);

  final AttributedText text;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final AttributionStyleBuilder textStyleBuilder;
  final Map<String, dynamic> metadata;
  final TextSelection? textSelection;
  final Color selectionColor;
  final bool showCaret;
  final Color caretColor;
  final bool highlightWhenEmpty;
  final bool showDebugPaint;

  @override
  _TextComponentState createState() => _TextComponentState();
}

class _TextComponentState extends State<TextComponent> with DocumentComponent implements TextComposable {
  final _selectableTextKey = GlobalKey<SuperSelectableTextState>();

  @override
  TextNodePosition? getPositionAtOffset(Offset localOffset) {
    final textLayout = _selectableTextKey.currentState;
    final textPosition = textLayout?.getPositionAtOffset(localOffset);
    if (textPosition == null) {
      return null;
    }
    return TextNodePosition.fromTextPosition(textPosition);
  }

  @override
  Offset getOffsetForPosition(dynamic nodePosition) {
    if (nodePosition is! TextPosition) {
      throw Exception('Expected nodePosition of type TextPosition but received: $nodePosition');
    }
    return _selectableTextKey.currentState!.getOffsetAtPosition(nodePosition);
  }

  @override
  Rect getRectForPosition(dynamic nodePosition) {
    if (nodePosition is! TextPosition) {
      throw Exception('Expected nodePosition of type TextPosition but received: $nodePosition');
    }

    final offset = getOffsetForPosition(nodePosition);
    final lineHeight = _selectableTextKey.currentState!.getHeightForCaret(nodePosition) ??
        _selectableTextKey.currentState!.getLineHeightAtPosition(nodePosition);
    return Rect.fromLTWH(offset.dx, offset.dy, 0, lineHeight);
  }

  @override
  Rect getRectForSelection(dynamic baseNodePosition, dynamic extentNodePosition) {
    if (baseNodePosition is! TextPosition) {
      throw Exception('Expected nodePosition of type TextPosition but received: $baseNodePosition');
    }
    if (extentNodePosition is! TextPosition) {
      throw Exception('Expected nodePosition of type TextPosition but received: $extentNodePosition');
    }

    final selection = TextSelection(
      baseOffset: baseNodePosition.offset,
      extentOffset: extentNodePosition.offset,
    );
    final boxes = _selectableTextKey.currentState!.getBoxesForSelection(selection);

    Rect boundingBox = boxes.isNotEmpty ? boxes.first.toRect() : Rect.zero;
    for (int i = 1; i < boxes.length; ++i) {
      boundingBox = boundingBox.expandToInclude(boxes[i].toRect());
    }

    return boundingBox;
  }

  @override
  TextNodePosition getBeginningPosition() {
    return const TextNodePosition(offset: 0);
  }

  @override
  TextNodePosition getBeginningPositionNearX(double x) {
    return TextNodePosition.fromTextPosition(
      _selectableTextKey.currentState!.getPositionInFirstLineAtX(x),
    );
  }

  @override
  TextNodePosition? movePositionLeft(NodePosition textPosition, [Set<MovementModifier>? movementModifiers]) {
    if (textPosition is! TextNodePosition) {
      // We don't know how to interpret a non-text position.
      return null;
    }

    if (textPosition.offset > widget.text.text.length) {
      // This text position does not represent a position within our text.
      return null;
    }

    if (textPosition.offset == 0) {
      // Can't move any further left.
      return null;
    }

    if (movementModifiers != null && movementModifiers.contains(MovementModifier.line)) {
      return getPositionAtStartOfLine(
        TextNodePosition(offset: textPosition.offset),
      );
    } else if (movementModifiers != null && movementModifiers.contains(MovementModifier.word)) {
      final text = getContiguousTextAt(textPosition);

      int newOffset = textPosition.offset;
      newOffset -= 1; // we always want to jump at least 1 character.
      while (newOffset > 0 && text[newOffset - 1] != ' ') {
        newOffset -= 1;
      }
      return TextNodePosition(offset: newOffset);
    }

    return TextNodePosition(offset: textPosition.offset - 1);
  }

  @override
  TextNodePosition? movePositionRight(NodePosition textPosition, [Set<MovementModifier>? movementModifiers]) {
    if (textPosition is! TextNodePosition) {
      // We don't know how to interpret a non-text position.
      return null;
    }

    if (textPosition.offset >= widget.text.text.length) {
      // Can't move further right.
      return null;
    }

    if (movementModifiers != null && movementModifiers.contains(MovementModifier.line)) {
      final endOfLine = getPositionAtEndOfLine(
        TextNodePosition(offset: textPosition.offset),
      );

      final TextPosition endPosition = getEndPosition();
      final text = getContiguousTextAt(endOfLine);

      // Note: we compare offset values because we don't care if the affinitys are equal
      final isAutoWrapLine = endOfLine.offset != endPosition.offset && (text[endOfLine.offset] != '\n');

      // Note: For lines that auto-wrap, moving the cursor to `offset` causes the
      //       cursor to jump to the next line because the cursor is placed after
      //       the final selected character. We don't want this, so in this case
      //       we `-1`.
      //
      //       However, if the line that is selected ends with an explicit `\n`,
      //       or if the line is the terminal line for the paragraph then we don't
      //       want to `-1` because that would leave a dangling character after the
      //       selection.
      // TODO: this is the concept of text affinity. Implement support for affinity.
      // TODO: with affinity, ensure it works as expected for right-aligned text
      // TODO: this logic fails for justified text - find a solution for that (#55)
      return isAutoWrapLine
          ? TextNodePosition(offset: endOfLine.offset - 1)
          : TextNodePosition.fromTextPosition(endOfLine);
    }
    if (movementModifiers != null && movementModifiers.contains(MovementModifier.word)) {
      final text = getContiguousTextAt(textPosition);

      int newOffset = textPosition.offset;
      newOffset += 1; // we always want to jump at least 1 character.
      while (newOffset < text.length && text[newOffset] != ' ') {
        newOffset += 1;
      }
      return TextNodePosition(offset: newOffset);
    }

    return TextNodePosition(offset: textPosition.offset + 1);
  }

  @override
  TextNodePosition? movePositionUp(NodePosition textNodePosition) {
    if (textNodePosition is! TextNodePosition) {
      // We don't know how to interpret a non-text position.
      return null;
    }

    if (textNodePosition.offset < 0 || textNodePosition.offset > widget.text.text.length) {
      // This text position does not represent a position within our text.
      return null;
    }

    final positionOneLineUp = getPositionOneLineUp(textNodePosition);
    if (positionOneLineUp == null) {
      return null;
    }
    return TextNodePosition.fromTextPosition(positionOneLineUp);
  }

  @override
  TextNodePosition? movePositionDown(NodePosition textNodePosition) {
    if (textNodePosition is! TextNodePosition) {
      // We don't know how to interpret a non-text position.
      return null;
    }

    if (textNodePosition.offset < 0 || textNodePosition.offset > widget.text.text.length) {
      // This text position does not represent a position within our text.
      return null;
    }

    final positionOneLineDown = getPositionOneLineDown(textNodePosition);
    if (positionOneLineDown == null) {
      return null;
    }
    return TextNodePosition.fromTextPosition(positionOneLineDown);
  }

  @override
  TextNodePosition getEndPosition() {
    return TextNodePosition(offset: widget.text.text.length);
  }

  @override
  TextNodePosition getEndPositionNearX(double x) {
    return TextNodePosition.fromTextPosition(_selectableTextKey.currentState!.getPositionInLastLineAtX(x));
  }

  @override
  TextNodeSelection getSelectionInRange(Offset localBaseOffset, Offset localExtentOffset) {
    return TextNodeSelection.fromTextSelection(
        _selectableTextKey.currentState!.getSelectionInRect(localBaseOffset, localExtentOffset));
  }

  @override
  TextNodeSelection getCollapsedSelectionAt(NodePosition textNodePosition) {
    if (textNodePosition is! TextNodePosition) {
      throw Exception('The given node position ($textNodePosition) is not compatible with TextComponent');
    }

    return TextNodeSelection.collapsed(offset: textNodePosition.offset);
  }

  @override
  TextNodeSelection getSelectionBetween({
    required NodePosition basePosition,
    required NodePosition extentPosition,
  }) {
    if (basePosition is! TextNodePosition) {
      throw Exception('Expected a basePosition of type TextNodePosition but received: $basePosition');
    }
    if (extentPosition is! TextNodePosition) {
      throw Exception('Expected an extentPosition of type TextNodePosition but received: $extentPosition');
    }

    return TextNodeSelection(
      baseOffset: basePosition.offset,
      extentOffset: extentPosition.offset,
    );
  }

  @override
  TextNodeSelection getSelectionOfEverything() {
    return TextNodeSelection(
      baseOffset: 0,
      extentOffset: widget.text.text.length,
    );
  }

  @override
  MouseCursor? getDesiredCursorAtOffset(Offset localOffset) {
    return _selectableTextKey.currentState!.isTextAtOffset(localOffset) ? SystemMouseCursors.text : null;
  }

  @override
  TextNodeSelection getWordSelectionAt(TextNodePosition textPosition) {
    return TextNodeSelection.fromTextSelection(
      _selectableTextKey.currentState!.getWordSelectionAt(textPosition),
    );
  }

  @override
  String getContiguousTextAt(TextNodePosition textPosition) {
    // This component only displays a single contiguous span of text.
    // Therefore, all of our text is contiguous regardless of position.
    // TODO: This assumption isn't true in the case that multiline text
    //       is displayed within 1 node, such as when the user presses
    //       shift+enter. Change implementation to find actual contiguous
    //       text. (#54)
    return widget.text.text;
  }

  @override
  TextNodePosition? getPositionOneLineUp(NodePosition textPosition) {
    if (textPosition is! TextNodePosition) {
      throw Exception('Expected position of type NodePosition but received ${textPosition.runtimeType}');
    }

    final positionOneLineUp = _selectableTextKey.currentState!.getPositionOneLineUp(textPosition);
    if (positionOneLineUp == null) {
      return null;
    }
    return TextNodePosition.fromTextPosition(positionOneLineUp);
  }

  @override
  TextNodePosition? getPositionOneLineDown(NodePosition textPosition) {
    if (textPosition is! TextNodePosition) {
      throw Exception('Expected position of type NodePosition but received ${textPosition.runtimeType}');
    }

    final positionOneLineDown = _selectableTextKey.currentState!.getPositionOneLineDown(textPosition);
    if (positionOneLineDown == null) {
      return null;
    }
    return TextNodePosition.fromTextPosition(positionOneLineDown);
  }

  @override
  TextNodePosition getPositionAtEndOfLine(TextNodePosition textPosition) {
    return TextNodePosition.fromTextPosition(
      _selectableTextKey.currentState!.getPositionAtEndOfLine(textPosition),
    );
  }

  @override
  TextNodePosition getPositionAtStartOfLine(TextNodePosition textNodePosition) {
    return TextNodePosition.fromTextPosition(
      _selectableTextKey.currentState!.getPositionAtStartOfLine(textNodePosition),
    );
  }

  @override
  Widget build(BuildContext context) {
    editorLayoutLog.finer('Building a TextComponent with key: ${widget.key}');

    return SuperSelectableText(
      key: _selectableTextKey,
      textSpan: widget.text.computeTextSpan(_textStyleWithBlockType),
      textAlign: widget.textAlign ?? TextAlign.left,
      textDirection: widget.textDirection ?? TextDirection.ltr,
      textSelection: widget.textSelection ?? const TextSelection.collapsed(offset: -1),
      textSelectionDecoration: TextSelectionDecoration(selectionColor: widget.selectionColor),
      showCaret: widget.showCaret,
      textCaretFactory: TextCaretFactory(color: widget.caretColor),
      highlightWhenEmpty: widget.highlightWhenEmpty,
    );
  }

  /// Creates a `TextStyle` based on the given [attributions], plus any
  /// "block type" that's specified in [widget.metadata].
  TextStyle _textStyleWithBlockType(Set<Attribution> attributions) {
    final attributionsWithBlockType = Set<Attribution>.from(attributions);
    Attribution? blockType = widget.metadata['blockType'];
    if (blockType != null) {
      attributionsWithBlockType.add(blockType);
    }

    return widget.textStyleBuilder(attributionsWithBlockType);
  }
}

// TODO: the add/remove/toggle commands are almost identical except for what they
//       do to ranges of text. Pull out the common range calculation behavior.
/// Applies the given `attributions` to the given `documentSelection`.
class AddTextAttributionsCommand implements EditorCommand {
  AddTextAttributionsCommand({
    required this.documentSelection,
    required this.attributions,
  });

  final DocumentSelection documentSelection;
  final Set<Attribution> attributions;

  @override
  void execute(Document document, DocumentEditorTransaction transaction) {
    editorDocLog.info('Executing AddTextAttributionsCommand');
    final nodes = document.getNodesInside(documentSelection.base, documentSelection.extent);
    if (nodes.isEmpty) {
      editorDocLog.shout(' - Bad DocumentSelection. Could not get range of nodes. Selection: $documentSelection');
      return;
    }

    // Calculate a DocumentRange so we know which DocumentPosition
    // belongs to the first node, and which belongs to the last node.
    final nodeRange = document.getRangeBetween(documentSelection.base, documentSelection.extent);
    editorDocLog.info(' - node range: $nodeRange');

    // ignore: prefer_collection_literals
    final nodesAndSelections = LinkedHashMap<TextNode, TextRange>();

    for (final textNode in nodes) {
      if (textNode is! TextNode) {
        continue;
      }

      int startOffset = -1;
      int endOffset = -1;

      if (textNode == nodes.first && textNode == nodes.last) {
        // Handle selection within a single node
        editorDocLog.info(' - the selection is within a single node: ${textNode.id}');
        final baseOffset = (documentSelection.base.nodePosition as TextPosition).offset;
        final extentOffset = (documentSelection.extent.nodePosition as TextPosition).offset;
        startOffset = baseOffset < extentOffset ? baseOffset : extentOffset;
        endOffset = baseOffset < extentOffset ? extentOffset : baseOffset;

        // -1 because TextPosition's offset indexes the character after the
        // selection, not the final character in the selection.
        endOffset -= 1;
      } else if (textNode == nodes.first) {
        // Handle partial node selection in first node.
        editorDocLog.info(' - selecting part of the first node: ${textNode.id}');
        startOffset = (nodeRange.start.nodePosition as TextPosition).offset;
        endOffset = max(textNode.text.text.length - 1, 0);
      } else if (textNode == nodes.last) {
        // Handle partial node selection in last node.
        editorDocLog.info(' - adding part of the last node: ${textNode.id}');
        startOffset = 0;

        // -1 because TextPosition's offset indexes the character after the
        // selection, not the final character in the selection.
        endOffset = (nodeRange.end.nodePosition as TextPosition).offset - 1;
      } else {
        // Handle full node selection.
        editorDocLog.info(' - adding full node: ${textNode.id}');
        startOffset = 0;
        endOffset = max(textNode.text.text.length - 1, 0);
      }

      final selectionRange = TextRange(start: startOffset, end: endOffset);

      nodesAndSelections.putIfAbsent(textNode, () => selectionRange);
    }

    // Add attributions.
    for (final entry in nodesAndSelections.entries) {
      for (Attribution attribution in attributions) {
        final node = entry.key;
        final range = entry.value;
        editorDocLog.info(' - adding attribution: $attribution. Range: $range');
        node.text.addAttribution(
          attribution,
          range,
        );
      }
    }

    editorDocLog.info(' - done adding attributions');
  }
}

/// Removes the given `attributions` from the given `documentSelection`.
class RemoveTextAttributionsCommand implements EditorCommand {
  RemoveTextAttributionsCommand({
    required this.documentSelection,
    required this.attributions,
  });

  final DocumentSelection documentSelection;
  final Set<Attribution> attributions;

  @override
  void execute(Document document, DocumentEditorTransaction transaction) {
    editorDocLog.info('Executing RemoveTextAttributionsCommand');
    final nodes = document.getNodesInside(documentSelection.base, documentSelection.extent);
    if (nodes.isEmpty) {
      editorDocLog.shout(' - Bad DocumentSelection. Could not get range of nodes. Selection: $documentSelection');
      return;
    }

    // Calculate a DocumentRange so we know which DocumentPosition
    // belongs to the first node, and which belongs to the last node.
    final nodeRange = document.getRangeBetween(documentSelection.base, documentSelection.extent);
    editorDocLog.info(' - node range: $nodeRange');

    // ignore: prefer_collection_literals
    final nodesAndSelections = LinkedHashMap<TextNode, TextRange>();

    for (final textNode in nodes) {
      if (textNode is! TextNode) {
        continue;
      }

      int startOffset = -1;
      int endOffset = -1;

      if (textNode == nodes.first && textNode == nodes.last) {
        // Handle selection within a single node
        editorDocLog.info(' - the selection is within a single node: ${textNode.id}');
        final baseOffset = (documentSelection.base.nodePosition as TextPosition).offset;
        final extentOffset = (documentSelection.extent.nodePosition as TextPosition).offset;
        startOffset = baseOffset < extentOffset ? baseOffset : extentOffset;
        endOffset = baseOffset < extentOffset ? extentOffset : baseOffset;

        // -1 because TextPosition's offset indexes the character after the
        // selection, not the final character in the selection.
        endOffset -= 1;
      } else if (textNode == nodes.first) {
        // Handle partial node selection in first node.
        editorDocLog.info(' - selecting part of the first node: ${textNode.id}');
        startOffset = (nodeRange.start.nodePosition as TextPosition).offset;
        endOffset = max(textNode.text.text.length - 1, 0);
      } else if (textNode == nodes.last) {
        // Handle partial node selection in last node.
        editorDocLog.info(' - adding part of the last node: ${textNode.id}');
        startOffset = 0;

        // -1 because TextPosition's offset indexes the character after the
        // selection, not the final character in the selection.
        endOffset = (nodeRange.end.nodePosition as TextPosition).offset - 1;
      } else {
        // Handle full node selection.
        editorDocLog.info(' - adding full node: ${textNode.id}');
        startOffset = 0;
        endOffset = max(textNode.text.text.length - 1, 0);
      }

      final selectionRange = TextRange(start: startOffset, end: endOffset);

      nodesAndSelections.putIfAbsent(textNode, () => selectionRange);
    }

    // Add attributions.
    for (final entry in nodesAndSelections.entries) {
      for (Attribution attribution in attributions) {
        final node = entry.key;
        final range = entry.value;
        editorDocLog.info(' - removing attribution: $attribution. Range: $range');
        node.text.removeAttribution(
          attribution,
          range,
        );
      }
    }

    editorDocLog.info(' - done adding attributions');
  }
}

/// Applies the given `attributions` to the given `documentSelection`,
/// if none of the content in the selection contains any of the
/// given `attributions`. Otherwise, all the given `attributions`
/// are removed from the content within the `documentSelection`.
class ToggleTextAttributionsCommand implements EditorCommand {
  ToggleTextAttributionsCommand({
    required this.documentSelection,
    required this.attributions,
  });

  final DocumentSelection documentSelection;
  final Set<Attribution> attributions;

  @override
  void execute(Document document, DocumentEditorTransaction transaction) {
    editorDocLog.info('Executing ToggleTextAttributionsCommand');
    final nodes = document.getNodesInside(documentSelection.base, documentSelection.extent);
    if (nodes.isEmpty) {
      editorDocLog.shout(' - Bad DocumentSelection. Could not get range of nodes. Selection: $documentSelection');
      return;
    }

    // Calculate a DocumentRange so we know which DocumentPosition
    // belongs to the first node, and which belongs to the last node.
    final nodeRange = document.getRangeBetween(documentSelection.base, documentSelection.extent);
    editorDocLog.info(' - node range: $nodeRange');

    // ignore: prefer_collection_literals
    final nodesAndSelections = LinkedHashMap<TextNode, TextRange>();
    bool alreadyHasAttributions = false;

    for (final textNode in nodes) {
      if (textNode is! TextNode) {
        continue;
      }

      int startOffset = -1;
      int endOffset = -1;

      if (textNode == nodes.first && textNode == nodes.last) {
        // Handle selection within a single node
        editorDocLog.info(' - the selection is within a single node: ${textNode.id}');
        final baseOffset = (documentSelection.base.nodePosition as TextPosition).offset;
        final extentOffset = (documentSelection.extent.nodePosition as TextPosition).offset;
        startOffset = baseOffset < extentOffset ? baseOffset : extentOffset;
        endOffset = baseOffset < extentOffset ? extentOffset : baseOffset;

        // -1 because TextPosition's offset indexes the character after the
        // selection, not the final character in the selection.
        endOffset -= 1;
      } else if (textNode == nodes.first) {
        // Handle partial node selection in first node.
        editorDocLog.info(' - selecting part of the first node: ${textNode.id}');
        startOffset = (nodeRange.start.nodePosition as TextPosition).offset;
        endOffset = max(textNode.text.text.length - 1, 0);
      } else if (textNode == nodes.last) {
        // Handle partial node selection in last node.
        editorDocLog.info(' - toggling part of the last node: ${textNode.id}');
        startOffset = 0;

        // -1 because TextPosition's offset indexes the character after the
        // selection, not the final character in the selection.
        endOffset = (nodeRange.end.nodePosition as TextPosition).offset - 1;
      } else {
        // Handle full node selection.
        editorDocLog.info(' - toggling full node: ${textNode.id}');
        startOffset = 0;
        endOffset = max(textNode.text.text.length - 1, 0);
      }

      final selectionRange = TextRange(start: startOffset, end: endOffset);

      alreadyHasAttributions = alreadyHasAttributions ||
          textNode.text.hasAttributionsWithin(
            attributions: attributions,
            range: selectionRange,
          );

      nodesAndSelections.putIfAbsent(textNode, () => selectionRange);
    }

    // Toggle attributions.
    for (final entry in nodesAndSelections.entries) {
      for (Attribution attribution in attributions) {
        final node = entry.key;
        final range = entry.value;
        editorDocLog.info(' - toggling attribution: $attribution. Range: $range');
        node.text.toggleAttribution(
          attribution,
          range,
        );
      }
    }

    editorDocLog.info(' - done toggling attributions');
  }
}

class InsertTextCommand implements EditorCommand {
  InsertTextCommand({
    required this.documentPosition,
    required this.textToInsert,
    required this.attributions,
  }) : assert(documentPosition.nodePosition is TextPosition);

  final DocumentPosition documentPosition;
  final String textToInsert;
  final Set<Attribution> attributions;

  @override
  void execute(Document document, DocumentEditorTransaction transaction) {
    final textNode = document.getNodeById(documentPosition.nodeId);
    if (textNode is! TextNode) {
      editorDocLog.shout('ERROR: can\'t insert text in a node that isn\'t a TextNode: $textNode');
      return;
    }

    final textOffset = (documentPosition.nodePosition as TextPosition).offset;
    textNode.text = textNode.text.insertString(
      textToInsert: textToInsert,
      startOffset: textOffset,
      applyAttributions: attributions,
    );
  }
}

ExecutionInstruction anyCharacterToInsertInTextContent({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  // Do nothing if CMD or CTRL are pressed because this signifies an attempted
  // shortcut.
  if (keyEvent.isControlPressed || keyEvent.isMetaPressed) {
    return ExecutionInstruction.continueExecution;
  }
  if (editContext.composer.selection == null) {
    return ExecutionInstruction.continueExecution;
  }
  if (!editContext.composer.selection!.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }
  if (!_isTextEntryNode(
    document: editContext.editor.document,
    selection: editContext.composer.selection!,
  )) {
    return ExecutionInstruction.continueExecution;
  }
  if (keyEvent.character == null || keyEvent.character == '') {
    return ExecutionInstruction.continueExecution;
  }
  if (LogicalKeyboardKey.isControlCharacter(keyEvent.character!) || keyEvent.isArrowKeyPressed) {
    return ExecutionInstruction.continueExecution;
  }

  String character = keyEvent.character!;

  // On web, keys like shift and alt are sending their full name
  // as a character, e.g., "Shift" and "Alt". This check prevents
  // those keys from inserting their name into content.
  //
  // This filter is a blacklist, and therefore it will fail to
  // catch any key that isn't explicitly listed. The eventual solution
  // to this is for the web to honor the standard key event contract,
  // but that's out of our control.
  if (kIsWeb && webBugBlacklistCharacters.contains(character)) {
    return ExecutionInstruction.continueExecution;
  }

  // The web reports a tab as "Tab". Intercept it and translate it to a space.
  if (character == 'Tab') {
    character = ' ';
  }

  final didInsertCharacter = editContext.commonOps.insertCharacter(character);

  return didInsertCharacter ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

ExecutionInstruction deleteCharacterWhenBackspaceIsPressed({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.backspace) {
    return ExecutionInstruction.continueExecution;
  }
  if (editContext.composer.selection == null) {
    return ExecutionInstruction.continueExecution;
  }
  if (!_isTextEntryNode(
    document: editContext.editor.document,
    selection: editContext.composer.selection!,
  )) {
    return ExecutionInstruction.continueExecution;
  }
  if (!editContext.composer.selection!.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }
  if ((editContext.composer.selection!.extent.nodePosition as TextPosition).offset <= 0) {
    return ExecutionInstruction.continueExecution;
  }

  final didDelete = editContext.commonOps.deleteUpstream();

  return didDelete ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

ExecutionInstruction deleteToRemoveDownstreamContent({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.delete) {
    return ExecutionInstruction.continueExecution;
  }

  final didDelete = editContext.commonOps.deleteDownstream();

  return didDelete ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

ExecutionInstruction shiftEnterToInsertNewlineInBlock({
  required EditContext editContext,
  required RawKeyEvent keyEvent,
}) {
  if (keyEvent.logicalKey != LogicalKeyboardKey.enter && keyEvent.logicalKey != LogicalKeyboardKey.numpadEnter) {
    return ExecutionInstruction.continueExecution;
  }
  if (!keyEvent.isShiftPressed) {
    return ExecutionInstruction.continueExecution;
  }

  final didInsertNewline = editContext.commonOps.insertPlainText('\n');

  return didInsertNewline ? ExecutionInstruction.haltExecution : ExecutionInstruction.continueExecution;
}

bool _isTextEntryNode({
  required Document document,
  required DocumentSelection selection,
}) {
  final extentPosition = selection.extent;
  final extentNode = document.getNodeById(extentPosition.nodeId);
  return extentNode is TextNode;
}
