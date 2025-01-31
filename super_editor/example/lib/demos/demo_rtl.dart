import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

/// Example of a rich text editor.
///
/// This editor will expand in functionality as the rich text
/// package expands.
class RTLDemo extends StatefulWidget {
  @override
  _RTLDemoState createState() => _RTLDemoState();
}

class _RTLDemoState extends State<RTLDemo> {
  late MutableDocument _doc;
  late DocumentEditor _docEditor;

  @override
  void initState() {
    super.initState();
    _doc = _createInitialDocument();
    _docEditor = DocumentEditor(document: _doc);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SuperEditor(
      editor: _docEditor,
      maxWidth: 600,
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
    );
  }
}

MutableDocument _createInitialDocument() {
  return MutableDocument(
    nodes: [
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text: 'Example Document',
        ),
        metadata: {
          'blockType': header1Attribution,
        },
      ),
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text:
              'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus sed sagittis urna. Aenean mattis ante justo, quis sollicitudin metus interdum id. Aenean ornare urna ac enim consequat mollis. In aliquet convallis efficitur. Phasellus convallis purus in fringilla scelerisque. Ut ac orci a turpis egestas lobortis. Morbi aliquam dapibus sem, vitae sodales arcu ultrices eu. Duis vulputate mauris quam, eleifend pulvinar quam blandit eget.',
        ),
      ),
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text: 'مثال',
        ),
        metadata: {
          'blockType': header1Attribution,
        },
      ),
      HorizontalRuleNode(id: DocumentEditor.createNodeId()),
      ParagraphNode(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
            text:
                'لكن لا بد أن أوضح لك أن كل هذه الأفكار المغلوطة حول استنكار  النشوة وتمجيد الألم نشأت بالفعل، وسأعرض لك التفاصيل لتكتشف حقيقة وأساس تلك السعادة البشرية، فلا أحد يرفض أو يكره أو يتجنب الشعور بالسعادة، ولكن بفضل هؤلاء الأشخاص الذين لا يدركون بأن السعادة لا بد أن نستشعرها بصورة أكثر عقلانية ومنطقية فيعرضهم هذا لمواجهة الظروف الأليمة، وأكرر بأنه لا يوجد من يرغب في الحب ونيل المنال ويتلذذ بالآلام، الألم هو الألم ولكن نتيجة لظروف ما قد تكمن السعاده فيما نتحمله من كد وأسي.'),
      ),
      ListItemNode.unordered(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text: 'فقرة رقم ١ في القائمة.',
        ),
      ),
      ListItemNode.unordered(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text: 'فقرة رقم ٢ في القائمة.',
        ),
      ),
      ListItemNode.unordered(
        id: DocumentEditor.createNodeId(),
        text: AttributedText(
          text: 'فقرة رقم ٣ في القائمة.',
        ),
      ),
    ],
  );
}
