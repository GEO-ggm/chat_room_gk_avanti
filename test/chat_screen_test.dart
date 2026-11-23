import 'package:chat_room/core/api/chat_api.dart';
import 'package:chat_room/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _delay = Duration(seconds: 1);

final _pending = find.byType(CircularProgressIndicator);
final _failedIcon = find.byIcon(Icons.error_outline);
final _sentChecks = find.byIcon(Icons.done);
final _retryAction = find.text('Повторить отправку');
final _deleteAction = find.text('Удалить');

Future<void> _pumpApp(WidgetTester tester) => tester.pumpWidget(ProviderScope(
      overrides: [chatApiProvider.overrideWithValue(FakeChatApi(delay: _delay))],
      child: const ChatApp(),
    ));

/// Отправляет сообщение и ждёт, пока первая попытка завершится ошибкой.
Future<void> _sendAndFail(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.tap(find.widgetWithIcon(IconButton, Icons.send));
  await tester.pump();

  expect(find.text(text), findsOneWidget);
  expect(_pending, findsOneWidget);
  expect(_failedIcon, findsNothing);

  await tester.pump(_delay);
  expect(_pending, findsNothing);
  expect(_failedIcon, findsOneWidget);
}

void main() {
  testWidgets('пустой ввод — кнопка отправки неактивна', (tester) async {
    await _pumpApp(tester);
    expect(find.text('Привет! Это room1.'), findsOneWidget);

    final sendButton = find.widgetWithIcon(IconButton, Icons.send);
    expect(tester.widget<IconButton>(sendButton).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(tester.widget<IconButton>(sendButton).onPressed, isNull);
  });

  testWidgets('failed → тап по иконке → «Повторить отправку» → sent', (tester) async {
    await _pumpApp(tester);
    final sentBefore = tester.widgetList(_sentChecks).length;
    await _sendAndFail(tester, 'Новое');

    await tester.tap(_failedIcon);
    await tester.pumpAndSettle();
    expect(_retryAction, findsOneWidget);
    expect(_deleteAction, findsOneWidget);

    await tester.tap(_retryAction);
    await tester.pump(); // закрытие шторки + переход в pending
    expect(_pending, findsOneWidget);
    expect(_failedIcon, findsNothing);

    await tester.pump(_delay);
    await tester.pumpAndSettle();
    expect(_pending, findsNothing);
    expect(_failedIcon, findsNothing);
    expect(_retryAction, findsNothing);
    // Та же запись стала sent, дубля нет.
    expect(_sentChecks, findsNWidgets(sentBefore + 1));
    expect(find.text('Новое'), findsOneWidget);
  });

  testWidgets('failed → тап по сообщению → «Удалить» убирает запись', (tester) async {
    await _pumpApp(tester);
    await _sendAndFail(tester, 'Удаляемое');

    await tester.tap(find.text('Удаляемое'));
    await tester.pumpAndSettle();
    await tester.tap(_deleteAction);
    await tester.pumpAndSettle();

    expect(find.text('Удаляемое'), findsNothing);
    expect(_failedIcon, findsNothing);
  });

  testWidgets('тап по отправленному сообщению шторку не открывает', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Спасибо!'));
    await tester.pumpAndSettle();
    expect(_retryAction, findsNothing);
  });
}
