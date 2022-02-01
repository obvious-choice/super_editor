import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group("SuperTextField", () {
    group("test typing", () {
      testWidgets("in empty field", (tester) async {
        await _pumpDesktopScaffold(tester);

        await tester.tap(find.byType(SuperTextField));
        await tester.pumpAndSettle();

        await tester.enterSuperTextPlain(
          find.byType(SuperTextField),
          // TODO: we can only send lowercase text until Flutter bug #96021 is resolved
          "hello world",
        );

        expect(find.text("hello world", findRichText: true), findsOneWidget);
      });

      testWidgets("shift characters", (tester) async {
        await _pumpDesktopScaffold(tester);

        await tester.tap(find.byType(SuperTextField));
        await tester.pumpAndSettle();

        await tester.enterSuperTextPlain(
          find.byType(SuperTextField),
          "@",
        );

        expect(find.text("@", findRichText: true), findsOneWidget);
        expect(find.text("2", findRichText: true), findsNothing);
      });

      testWidgets("doesn't support Android", (tester) async {
        await _pumpAndroidScaffold(tester);

        await tester.tap(find.byType(SuperAndroidTextfield));
        await tester.pumpAndSettle();

        await expectLater(() async {
          await tester.enterSuperTextPlain(
            find.byType(SuperAndroidTextfield),
            "a",
          );
        }, throwsException);
      });

      testWidgets("doesn't support iOS", (tester) async {
        await _pumpIOSScaffold(tester);

        await tester.tap(find.byType(SuperIOSTextField));
        await tester.pumpAndSettle();

        await expectLater(() async {
          await tester.enterSuperTextPlain(
            find.byType(SuperIOSTextField),
            "a",
          );
        }, throwsException);
      });

      testWidgets("in middle of existing text", (tester) async {
        await _pumpDesktopScaffold(
          tester,
          AttributedTextEditingController(
            text: AttributedText(text: "hello world"),
          ),
        );

        final textFieldFinder = find.byType(SuperTextField);

        await tester.tapAtSuperTextPosition(textFieldFinder, 6);
        await tester.pumpAndSettle();

        await tester.enterSuperTextPlain(
          textFieldFinder,
          "new ",
        );

        expect(find.text("hello new world", findRichText: true), findsOneWidget);
      });
    });
  });
}

Future<void> _pumpDesktopScaffold(WidgetTester tester, [AttributedTextEditingController? controller]) async {
  await _pumpScaffold(
    tester,
    SuperTextField(
      textController: controller,
    ),
  );
}

Future<void> _pumpAndroidScaffold(WidgetTester tester, [ImeAttributedTextEditingController? controller]) async {
  await _pumpScaffold(
    tester,
    SuperAndroidTextfield(
      textController: controller,
      caretColor: Colors.blue,
      handlesColor: Colors.blue,
      selectionColor: Colors.lightBlueAccent,
      lineHeight: 24,
    ),
  );
}

Future<void> _pumpIOSScaffold(WidgetTester tester, [ImeAttributedTextEditingController? controller]) async {
  await _pumpScaffold(
    tester,
    SuperIOSTextField(
      textController: controller,
      caretColor: Colors.blue,
      handlesColor: Colors.blue,
      selectionColor: Colors.lightBlueAccent,
      lineHeight: 24,
    ),
  );
}

Future<void> _pumpScaffold(WidgetTester tester, Widget textField) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: textField,
          ),
        ),
      ),
    ),
  );
}
