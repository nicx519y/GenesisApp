part of 'widget_test.dart';

void photoInboxTests() {
  for (final source in ['chat', 'camera']) {
    for (final success in [false, true]) {
      testWidgets(
        'photo Inbox $source $success has correct semantics and typed target',
        (tester) async {
          final transport = _RecordingMessageCategoryTransport(
            notificationIsRead: false,
            notification: {
              'notification_id': 'photo-notice',
              'notice_block': 'world_apply',
              'notice_type': success ? 'photo_succeeded' : 'photo_failed',
              'biz_id': 'world-photo',
              'obj_id': 'task-not-message',
              'content': 'Photo result notice',
              'is_read': false,
              'created_at': '2026-11-04T01:00:00Z',
              'photo_target': {
                'source': source,
                if (source == 'chat') 'card_id': 9902,
                if (source == 'camera' && success)
                  'asset_id': '9007199254740993',
                'location_id': 'location-photo',
                'conversation_round_id': '9007199254740993',
                'chat_global_message_id': '9007199254740995',
              },
            },
          );
          final services = await _testServices(
            transport: transport,
            useMock: false,
          );
          RouteSettings? destination;
          await tester.pumpWidget(
            MaterialApp(
              onGenerateRoute: (settings) {
                destination = settings;
                return MaterialPageRoute<void>(
                  builder: (_) =>
                      const Scaffold(body: Text('photo destination')),
                );
              },
              home: AppServicesScope(
                services: services,
                child: const MessageCategoryListPage(
                  title: 'Notifications',
                  block: 'world_apply',
                  emptyText: 'Empty',
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final row = find
              .ancestor(
                of: find.text('Photo result notice'),
                matching: find.byType(InkWell),
              )
              .first;
          expect(tester.widget<InkWell>(row).onTap == null, !success);
          final semantics = tester.ensureSemantics();
          expect(
            tester
                .getSemantics(row)
                .getSemanticsData()
                .hasAction(ui.SemanticsAction.tap),
            success,
          );
          await tester.tap(find.text('Photo result notice'));
          await tester.pumpAndSettle();
          if (success) {
            expect(destination!.name, RouteNames.world);
            final args = destination!.arguments! as Map;
            expect(args['wid'], 'world-photo');
            if (source == 'camera') {
              final target = args['initial_camera_target'] as PhoneCameraTarget;
              expect(target.worldId, 'world-photo');
              expect(target.taskId, 'task-not-message');
              expect(target.assetId, 9007199254740993);
              expect(args['initial_photo_target'], isNull);
            } else {
              final target = args['initial_photo_target'] as ChatPhotoTarget;
              expect(target.locationId, 'location-photo');
              expect(target.cardId, 9902);
              expect(target.roundId, 9007199254740993);
              expect(target.globalMessageId, 9007199254740995);
            }
          } else {
            expect(destination, isNull);
            expect(find.text('Approve'), findsNothing);
            expect(find.text('Reject'), findsNothing);
          }
          expect(transport.readBlocks, contains('world_apply'));
          semantics.dispose();
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
