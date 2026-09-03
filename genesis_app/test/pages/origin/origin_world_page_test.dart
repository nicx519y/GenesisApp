import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genesis_flutter_android/components/chat/shared/chat_ui.dart';
import 'package:genesis_flutter_android/components/ai_content_disclaimer.dart';
import 'package:genesis_flutter_android/network/models/origin.dart';
import 'package:genesis_flutter_android/pages/chat/location_chat_page.dart';
import 'package:genesis_flutter_android/pages/origin/origin_world_layout.dart';
import 'package:genesis_flutter_android/pages/origin/origin_world_page.dart';
import 'package:genesis_flutter_android/platform/keyboard/genesis_keyboard_animation.dart';
import 'package:genesis_flutter_android/ui/tokens/genesis_radii.dart';

void main() {
  final originWorldPageSource = File(
    'lib/pages/origin/origin_world_page.dart',
  ).readAsStringSync();
  final originWorldDetailSheetSource = File(
    'lib/pages/origin/origin_world_detail_sheet.dart',
  ).readAsStringSync();
  final originWorldSheetInteractionSource = File(
    'lib/pages/origin/origin_world_sheet_interaction.dart',
  ).readAsStringSync();
  final originWorldMapShellSource = File(
    'lib/pages/origin/origin_world_map_shell.dart',
  ).readAsStringSync();
  final originWorldLocationChatSource = File(
    'lib/pages/origin/origin_world_location_chat.dart',
  ).readAsStringSync();
  final originSectionsSource = [
    'lib/pages/origin/origin_world_sections.dart',
    'lib/pages/origin/origin_world_role_setup.dart',
    'lib/pages/origin/origin_world_launched_worlds.dart',
    'lib/pages/origin/origin_world_characters.dart',
  ].map((path) => File(path).readAsStringSync()).join('\n');

  test('origin detail sheet uses main ui horizontal padding', () {
    expect(originDetailSheetHorizontalPaddingForTesting, 12);
  });

  test('origin page and detail sheet share the base background', () {
    expect(originWorldDetailSheetBackgroundColor, const Color(0xFF151517));
    expect(
      originWorldDetailSheetRaisedBackgroundColor,
      const Color(0xFF1F1D24),
    );
    expect(
      originWorldMapShellSource,
      contains('backgroundColor: originWorldDetailSheetBackgroundColor'),
    );
  });

  test('origin detail sheet uses the requested dark color tiers', () {
    expect(originWorldDetailSheetPrimaryTextColor, const Color(0xF2FFFFFF));
    expect(originWorldDetailSheetSecondaryTextColor, const Color(0xB8FFFFFF));
    expect(originWorldDetailSheetTertiaryTextColor, const Color(0x73FFFFFF));
    expect(originWorldDetailSheetSoftWhiteColor, const Color(0xFFF4F3F6));
    expect(originWorldDetailSheetAccentSoftColor, const Color(0xFFFF8A9A));
    expect(originWorldDetailSheetSubtleSurfaceColor, const Color(0x14FFFFFF));
    expect(originWorldDetailSheetSelectRoleArrowColor, const Color(0x8CFFFFFF));
  });

  test('origin role card paints its outline above the card content', () {
    expect(
      originSectionsSource,
      contains("'origin-setup-role-card-frame-\$stableId'"),
    );
    expect(
      originSectionsSource,
      contains('foregroundDecoration: BoxDecoration'),
    );
  });

  test('origin opening dialogue and composer reuse Location Chat styling', () {
    expect(
      originSectionsSource,
      contains('kLocationChatStyle.copyWith(bubbleBackdropBlurSigma: 0)'),
    );
    expect(
      originWorldLocationChatSource,
      contains('_originDetailSheetChatComposerStyle => kLocationChatStyle;'),
    );
    expect(
      originWorldDetailSheetSource,
      isNot(contains('inputDockBackgroundColor:')),
    );
    expect(
      originWorldLocationChatSource,
      isNot(contains('_originLocationChatRoleInputGap')),
    );
    expect(originWorldDetailSheetSource, contains('showShortcuts: false'));
    expect(originWorldDetailSheetSource, contains('enableMentionSheet: false'));
    expect(originWorldDetailSheetSource, contains('roleBorderRadius: 8'));
    expect(originWorldDetailSheetSource, contains('SliverLayoutBuilder('));
    expect(
      originWorldDetailSheetSource,
      contains('!roleEditing && !composerLifted && _openingComposerDocked'),
    );
    expect(
      originWorldDetailSheetSource,
      contains(
        'resizeToAvoidBottomInset: !roleEditing && !_openingKeyboardMode',
      ),
    );
    expect(
      originWorldDetailSheetSource,
      isNot(contains('origin-opening-keyboard-message-overlay')),
    );
    expect(
      originWorldDetailSheetSource,
      isNot(contains('_openingKeyboardScrollController')),
    );
    expect(
      originWorldDetailSheetSource,
      contains('_OriginSliverPaintTranslation('),
    );
    expect(
      originWorldDetailSheetSource,
      isNot(contains('_expandedOpeningComposerTop')),
    );
    expect(
      originWorldDetailSheetSource,
      isNot(contains('_scheduleOpeningComposerPositionUpdate')),
    );
  });

  test('origin sheet keeps hot interaction rebuilds locally scoped', () {
    expect(
      originWorldDetailSheetSource,
      isNot(
        contains(
          'animation: Listenable.merge([\n'
          '                            _sheetController,\n'
          '                            _pageController,\n'
          '                            _roleEditing,',
        ),
      ),
    );
    expect(
      originWorldDetailSheetSource,
      contains('animation: _sheetInteraction.keyboardFrameListenable'),
    );
    expect(
      originWorldSheetInteractionSource,
      contains('_notifyKeyboardFrameChanged();'),
    );
    expect(
      originWorldDetailSheetSource,
      contains(
        'actualKeyboardInset:\n'
        '                                _sheetInteraction.keyboardInset',
      ),
    );
    expect(
      originWorldDetailSheetSource,
      isNot(
        contains(
          'bottomSafeAreaInset: MediaQuery.viewInsetsOf(context).bottom',
        ),
      ),
    );
    expect(originSectionsSource, contains('SliverChildBuilderDelegate('));
    expect(originSectionsSource, contains('addAutomaticKeepAlives: false'));
    expect(originSectionsSource, contains('addRepaintBoundaries: true'));
    expect(originSectionsSource, contains('child: RepaintBoundary('));
    expect(originSectionsSource, isNot(contains('imageUrls.indexOf(')));
  });

  test('origin sheet interaction is packaged outside the sheet UI', () {
    expect(
      originWorldPageSource,
      contains("part 'origin_world_sheet_interaction.dart';"),
    );
    expect(
      originWorldSheetInteractionSource,
      contains('class _OriginWorldSheetInteractionController'),
    );
    expect(
      originWorldSheetInteractionSource,
      contains('void handleComposerFocusChanged(bool hasFocus)'),
    );
    expect(
      originWorldSheetInteractionSource,
      contains('bool handlePageScrollEnd(ScrollEndNotification notification)'),
    );
    expect(
      originWorldSheetInteractionSource,
      contains('void reportOpeningComposerDocked(bool docked)'),
    );
    expect(
      originWorldSheetInteractionSource,
      contains('bool isCollapsedRoleActionVisible'),
    );
    expect(
      originWorldDetailSheetSource,
      isNot(contains('void _updateOpeningKeyboardInset(double rawInset)')),
    );
    expect(originWorldDetailSheetSource, contains('DraggableScrollableSheet('));
    expect(
      originWorldDetailSheetSource,
      contains('void _handleCollapsedRoleDragUpdate'),
    );
    expect(
      originWorldDetailSheetSource,
      contains('Future<void> _animateToRequestedExtent'),
    );
  });

  test('origin opening keyboard geometry follows system inset progress', () {
    const startTop = 620.0;
    const sheetHeight = 760.0;
    const composerHeight = 100.0;
    const keyboardInset = 300.0;

    expect(
      originOpeningKeyboardProgressForTesting(
        currentInset: 0,
        startInset: 0,
        endInset: keyboardInset,
      ),
      0,
    );
    expect(
      originOpeningKeyboardProgressForTesting(
        currentInset: 150,
        startInset: 0,
        endInset: keyboardInset,
      ),
      0.5,
    );
    expect(
      originOpeningKeyboardProgressForTesting(
        currentInset: 150,
        startInset: keyboardInset,
        endInset: 0,
      ),
      0.5,
    );
    expect(
      originOpeningKeyboardComposerTopForTesting(
        startTop: startTop,
        sheetHeight: sheetHeight,
        composerHeight: composerHeight,
        keyboardInset: keyboardInset,
        progress: 0,
      ),
      startTop,
    );
    final finalTop = originOpeningKeyboardComposerTopForTesting(
      startTop: startTop,
      sheetHeight: sheetHeight,
      composerHeight: composerHeight,
      keyboardInset: keyboardInset,
      progress: 1,
    );
    expect(finalTop + composerHeight, sheetHeight - keyboardInset);
  });

  test('origin opening composer never falls behind the actual keyboard', () {
    expect(
      originOpeningKeyboardVisibleComposerTopForTesting(
        animatedTop: 620,
        sheetHeight: 780,
        composerHeight: 100,
        actualKeyboardInset: 300,
      ),
      380,
      reason:
          'A stale animation frame is clamped so the composer bottom remains '
          'at the actual keyboard top.',
    );
    expect(
      originOpeningKeyboardVisibleComposerTopForTesting(
        animatedTop: 300,
        sheetHeight: 780,
        composerHeight: 100,
        actualKeyboardInset: 300,
      ),
      300,
      reason: 'A composer already above the keyboard must not be pushed down.',
    );
    expect(
      originOpeningKeyboardVisibleComposerTopForTesting(
        animatedTop: 620,
        sheetHeight: 780,
        composerHeight: 100,
        actualKeyboardInset: 0,
      ),
      620,
      reason: 'The keyboard bound is inactive after the keyboard is closed.',
    );
  });

  test('origin opening keyboard distinguishes short and scrolled content', () {
    expect(
      originOpeningKeyboardContentTargetOffsetForTesting(
        layoutOffset: 80,
        preservedOffset: 80,
        contentTop: 60,
        contentBottom: 300,
        composerTop: 500,
        gap: 24,
      ),
      80,
      reason: 'Short content keeps its original visual offset.',
    );
    expect(
      originOpeningKeyboardContentTargetOffsetForTesting(
        layoutOffset: 250,
        preservedOffset: 250,
        contentTop: -110,
        contentBottom: 130,
        composerTop: 500,
        gap: 24,
      ),
      140,
      reason:
          'Short content that was scrolled above the viewport returns its '
          'natural top edge to the sheet top.',
    );
    expect(
      originOpeningKeyboardContentTargetOffsetForTesting(
        layoutOffset: 80,
        preservedOffset: 80,
        contentTop: 60,
        contentBottom: 620,
        composerTop: 500,
        gap: 24,
      ),
      224,
      reason: 'Only the overflowing height is scrolled above the composer.',
    );
    expect(
      originOpeningKeyboardContentTargetOffsetForTesting(
        layoutOffset: 400,
        preservedOffset: 400,
        contentTop: -340,
        contentBottom: 220,
        composerTop: 500,
        gap: 24,
      ),
      144,
      reason:
          'A tall content block remains tall after scrolling; its on-screen '
          'top must not make it take the short-content path.',
    );
    expect(
      originOpeningKeyboardAdditionalScrollExtentForTesting(
        targetOffset: 140,
        maxScrollExtent: 112,
      ),
      28,
      reason:
          'The keyboard list must add the exact missing extent required to '
          'commit the short-content top alignment.',
    );
    expect(
      originOpeningKeyboardAdditionalScrollExtentForTesting(
        targetOffset: 140,
        maxScrollExtent: 180,
      ),
      0,
    );
    expect(
      originOpeningKeyboardSettledTargetInsetForTesting(
        nativeTargetInset: 304,
        actualInset: 300,
        stableFrameCount: 1,
      ),
      304,
      reason: 'The native target remains authoritative while IME is moving.',
    );
    expect(
      originOpeningKeyboardSettledTargetInsetForTesting(
        nativeTargetInset: 304,
        actualInset: 300,
        stableFrameCount: 2,
      ),
      300,
      reason:
          'The settled Flutter inset becomes the exact final keyboard edge.',
    );
  });

  test('origin opening keyboard rests at the inline composer boundary', () {
    expect(
      originOpeningKeyboardFlowRestingOffsetForTesting(
        layoutOffset: 80,
        contentBottom: 620,
        sheetHeight: 600,
        composerHeight: 100,
        gap: 24,
      ),
      224,
      reason:
          'Tall content leaves the inline composer exactly at the viewport '
          'bottom.',
    );
    expect(
      originOpeningKeyboardFlowRestingOffsetForTesting(
        layoutOffset: 80,
        contentBottom: 300,
        sheetHeight: 600,
        composerHeight: 100,
        gap: 24,
      ),
      0,
      reason:
          'Short content stays in natural flow when the boundary would require '
          'overscrolling above the list start.',
    );
  });

  test('origin keyboard animation target rejects malformed native events', () {
    expect(GenesisKeyboardAnimationTarget.tryParse(null), isNull);
    expect(
      GenesisKeyboardAnimationTarget.tryParse(const {
        'generation': 2,
        'phase': 'opening',
        'startInset': 0,
        'endInset': 301.5,
        'durationMillis': 250,
      }),
      isA<GenesisKeyboardAnimationTarget>()
          .having((event) => event.generation, 'generation', 2)
          .having(
            (event) => event.direction,
            'direction',
            GenesisKeyboardAnimationDirection.opening,
          )
          .having((event) => event.endInset, 'endInset', 301.5)
          .having(
            (event) => event.duration,
            'duration',
            const Duration(milliseconds: 250),
          ),
    );
  });

  test(
    'origin opening composer docks when its own box leaves the viewport',
    () {
      expect(
        originOpeningComposerShouldDockForTesting(
          remainingPaintExtent: 80,
          composerHeight: 80,
          currentlyDocked: false,
        ),
        isFalse,
        reason:
            'A fully visible inline composer must stay in the content flow.',
      );
      expect(
        originOpeningComposerShouldDockForTesting(
          remainingPaintExtent: 79.4,
          composerHeight: 80,
          currentlyDocked: false,
        ),
        isTrue,
        reason: 'Dock only after the inline composer itself starts leaving.',
      );
      expect(
        originOpeningComposerShouldDockForTesting(
          remainingPaintExtent: 80.4,
          composerHeight: 80,
          currentlyDocked: true,
        ),
        isTrue,
        reason: 'Keep the docked state inside the boundary hysteresis.',
      );
      expect(
        originOpeningComposerShouldDockForTesting(
          remainingPaintExtent: 80.6,
          composerHeight: 80,
          currentlyDocked: true,
        ),
        isFalse,
        reason: 'Return to flow after the composer is stably fully visible.',
      );
    },
  );

  test('origin collapsed sheet caps content height before safe area', () {
    expect(
      originWorldCollapsedSheetHeightFor(
        viewportHeight: 667,
        bottomSafeArea: 0,
      ),
      closeTo(233.45, 0.001),
    );
    expect(
      originWorldCollapsedSheetHeightFor(
        viewportHeight: 780,
        bottomSafeArea: 15,
      ),
      285,
    );
    expect(
      originWorldCollapsedSheetHeightFor(
        viewportHeight: 932,
        bottomSafeArea: 34,
      ),
      304,
    );
  });

  test('origin detail sheet header sizing matches design', () {
    expect(
      originDetailSheetHeaderHeightForTesting,
      GenesisRadii.sheetTopRadiusValue + 6,
    );
    expect(originDetailSheetHeaderBodyGapForTesting, 0);
    expect(originDetailSheetPageIndicatorTopOffsetForTesting, 4);
    expect(GenesisRadii.sheetTopRadiusValue, 18);
  });

  test('origin detail sections use main ui spacing', () {
    expect(originDetailSectionGapForTesting, 24);
    expect(originDetailSectionTitleIconGapForTesting, 8);
  });

  test('origin launched world rows use compact character avatars', () {
    expect(originLaunchedWorldAvatarSizeForTesting, 44);
    expect(originLaunchedWorldSectionTopPaddingForTesting, 6);
    expect(originLaunchedWorldTitleListGapForTesting, 16);
    expect(originLaunchedWorldRowGapForTesting, 16);
    expect(originLaunchedWorldPreviewLimitForTesting, 5);
    expect(originSectionsSource, isNot(contains("'Your Launched Worlds'")));
    expect(originSectionsSource, isNot(contains("'Launched Before'")));
    expect(originSectionsSource, contains("'Playing World'"));
    expect(originSectionsSource, isNot(contains("'Launch another World'")));
    expect(originSectionsSource, isNot(contains('color: GenesisColors.brand')));
    expect(originSectionsSource, isNot(contains("'Enter'")));
    expect(originSectionsSource, contains('SizedBox(height: 6)'));
    expect(originSectionsSource, contains('formatMessageCountLabel'));
    expect(originSectionsSource, contains('formatGenesisTimestamp'));
    expect(originSectionsSource, isNot(contains('bLastActiveAt.compareTo')));
    expect(
      originSectionsSource,
      contains('.take(originLaunchedWorldPreviewLimitForTesting)'),
    );
    expect(originSectionsSource, isNot(contains('Divider(')));
    expect(
      originSectionsSource,
      isNot(contains('Icons.chevron_right_rounded')),
    );
    expect(
      originSectionsSource,
      contains('crossAxisAlignment: CrossAxisAlignment.start'),
    );
  });

  test('origin info section titles do not render leading icons', () {
    final titleWidget = originSectionsSource.substring(
      originSectionsSource.indexOf('class _SectionTitle'),
    );
    expect(titleWidget, isNot(contains('SvgPicture.asset')));
    expect(titleWidget, isNot(contains('Image.asset')));
    expect(titleWidget, isNot(contains('Icon(icon')));
    expect(originSectionsSource, contains("title: 'Worldo Brief'"));
    expect(originSectionsSource, contains("title: 'Launch Preview'"));
    expect(originSectionsSource, isNot(contains('Launched World Progress')));
    expect(originSectionsSource, contains("title: 'Characters ("));
  });

  test('origin opening brief and role titles do not render leading icons', () {
    expect(
      originSectionsSource,
      isNot(contains('origin-opening-worldo-brief-icon')),
    );
    expect(
      originSectionsSource,
      isNot(contains('origin-setup-role-title-launch-icon')),
    );
    expect(originSectionsSource, contains("'Worldo Brief'"));
    expect(originSectionsSource, contains("'Select Your Role'"));
  });

  test('origin detail discuss uses a title-row View all action', () {
    expect(
      originSectionsSource,
      contains('authorColor: originWorldDetailSheetSecondaryTextColor'),
    );
    expect(
      originSectionsSource,
      isNot(contains('authorColor: originWorldDetailSheetAccentSoftColor')),
    );
    expect(originSectionsSource, contains("'View all >'"));
    expect(originSectionsSource, contains('fontSize: 10'));
    expect(
      originSectionsSource,
      contains('originWorldDetailSheetTertiaryTextColor'),
    );
    expect(originSectionsSource, contains('enableViewMore: false'));
    expect(
      originSectionsSource,
      isNot(contains('onViewMoreTap: () => _openDiscussPage(context)')),
    );
  });

  test('origin detail does not load or render launched world progress', () {
    expect(originWorldPageSource, isNot(contains('getLatestWorldSummaries')));
    expect(
      originWorldDetailSheetSource,
      isNot(contains('CopyWorldProgressSection')),
    );
  });

  test('origin location opening preview keeps every initial dialogue line', () {
    final messages = originLocationOpeningPreviewMessagesForTesting(
      [
        {
          'tick_no': 1,
          'tick_result': {
            'current_time': 'Day 1, 08:30',
            'location_groups': [
              {
                'location_id': 'loc_1',
                'initial_dialogue': [
                  {
                    'char_id': 'nar',
                    'char_name': 'narrator',
                    'content': 'The diner lights hum as Sam unlocks the door.',
                  },
                  {
                    'char_id': 'char_1',
                    'char_name': 'Sam',
                    'content': 'Coffee is on. Keep the sign lit.',
                  },
                  {'char_id': 'char_2', 'char_name': 'Riley', 'content': ''},
                ],
              },
              {
                'location_id': 'loc_2',
                'initial_dialogue': [
                  {
                    'char_id': 'char_3',
                    'char_name': 'Wrong Location',
                    'content': 'This should not be shown.',
                  },
                ],
              },
            ],
          },
        },
      ],
      const ['loc_1'],
    );

    expect(messages.first.senderType, 'tick');
    expect(messages.first.content, 'Day 1, 08:30');
    expect(messages.skip(1).map((message) => message.content), [
      'The diner lights hum as Sam unlocks the door.',
      'Coffee is on. Keep the sign lit.',
    ]);
    expect(messages[1].senderType, 'narrator');
    expect(messages.last.senderType, 'character');
    expect(messages.skip(1).map((message) => message.currentTime), [
      'Day 1, 08:30',
      'Day 1, 08:30',
    ]);
  });

  test('origin location opening preview prefers tick one location group', () {
    final messages = originLocationOpeningPreviewMessagesForTesting(
      [
        {
          'tick_no': 2,
          'tick_result': {
            'current_time': 'Later time.',
            'location_groups': [
              {
                'location_id': 'loc_1',
                'initial_dialogue': [
                  {
                    'char_id': 'char_1',
                    'char_name': 'Sam',
                    'content': 'Later line.',
                  },
                ],
              },
            ],
          },
        },
        {
          'tick_no': 1,
          'tick_result': {
            'current_time': 'Opening time.',
            'location_groups': [
              {
                'location_id': 'loc_1',
                'initial_dialogue': [
                  {
                    'char_id': 'char_1',
                    'char_name': 'Sam',
                    'content': 'Opening line.',
                  },
                ],
              },
            ],
          },
        },
      ],
      const ['loc_1'],
    );

    expect(messages.first.content, 'Opening time.');
    expect(messages.last.content, 'Opening line.');
    expect(messages.last.currentTime, 'Opening time.');
  });

  test(
    'origin opening preview prefers top-level init group and keeps nar_pic',
    () {
      final origin = _originDetail(
        characters: const <OriginCharacter>[],
        locations: [
          OriginLocation.fromJson(const {
            'id': 12,
            'origin_id': 1,
            'location_id': 'loc_1',
            'location_name': 'Town Square',
          }),
        ],
        initLocationGroup: const OriginInitLocationGroup(
          locationId: 'loc_1',
          initialDialogue: [
            OriginDialogueLine(
              charId: 'nar',
              charName: 'Narrator',
              content: 'The square wakes.',
            ),
            OriginDialogueLine(
              charId: 'char_1',
              charName: 'Sam',
              content: 'We should go.',
            ),
            OriginDialogueLine(
              charId: 'nar_pic',
              charName: 'Narrator',
              content: 'https://cdn.example.com/opening.webp',
            ),
          ],
        ),
        ticks: const [
          {
            'tick_no': 1,
            'tick_result': {
              'location_groups': [
                {
                  'location_id': 'loc_1',
                  'initial_dialogue': [
                    {
                      'char_id': 'char_legacy',
                      'char_name': 'Legacy',
                      'content': 'Legacy tick line.',
                    },
                  ],
                },
              ],
            },
          },
        ],
      );

      final messages = originOpeningPreviewMessagesForTesting(origin, const [
        'loc_1',
      ]);

      expect(messages.map((message) => message.content), [
        'The square wakes.',
        'We should go.',
        'https://cdn.example.com/opening.webp',
      ]);
      expect(messages.map((message) => message.senderType), [
        'narrator',
        'character',
        'image',
      ]);
      expect(
        messages.map((message) => message.content),
        isNot(contains('Legacy tick line.')),
      );
    },
  );

  test('origin location opening preview resolves character avatars', () {
    final messages = originLocationOpeningPreviewMessagesForTesting(
      [
        {
          'tick_no': 1,
          'tick_result': {
            'location_groups': [
              {
                'location_id': 'loc_1',
                'initial_dialogue': [
                  {
                    'char_id': 'char_1',
                    'char_name': 'Sam',
                    'content': 'Opening line.',
                  },
                ],
              },
            ],
          },
        },
      ],
      const ['loc_1'],
    );

    final entities = originLocationOpeningPreviewEntitiesForTesting(
      [
        OriginCharacter(
          id: 7,
          characterId: 'char_1',
          originId: 1,
          name: 'Sam',
          avatar: 'https://example.com/sam.png',
          tags: '',
          currentLocationId: 0,
          initialLocationId: 0,
          createdAt: null,
          updatedAt: null,
        ),
      ],
      messages,
      'loc_1',
    );

    expect(entities.single.id, 'char_1');
    expect(entities.single.avatarUrl, 'https://example.com/sam.png');
    expect(entities.single.isAi, isTrue);
  });

  testWidgets(
    'origin opening preview passes character avatar to location chat',
    (tester) async {
      const avatarAsset = 'assets/images/default_list_image.png';
      final messages = originLocationOpeningPreviewMessagesForTesting(
        [
          {
            'tick_no': 1,
            'tick_result': {
              'location_groups': [
                {
                  'location_id': 'loc_1',
                  'initial_dialogue': [
                    {
                      'char_id': 'nar',
                      'char_name': 'Narrator',
                      'content': 'The location wakes.',
                    },
                    {
                      'char_id': 'nar_pic',
                      'char_name': 'Narrator',
                      'content': avatarAsset,
                    },
                    {
                      'char_id': 'char_1',
                      'char_name': 'Sam',
                      'content': 'Opening line.',
                    },
                  ],
                },
              ],
            },
          },
        ],
        const ['loc_1'],
      );
      final entities = originLocationOpeningPreviewEntitiesForTesting(
        [
          OriginCharacter(
            id: 7,
            characterId: 'char_1',
            originId: 1,
            name: 'Sam',
            avatar: avatarAsset,
            tags: '',
            currentLocationId: 0,
            initialLocationId: 0,
            createdAt: null,
            updatedAt: null,
          ),
        ],
        messages,
        'loc_1',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LocationChatPanel(
            worldId: 'origin-preview',
            locationId: 'loc_1',
            active: false,
            openingPreviewMessages: messages,
            openingPreviewEntities: entities,
          ),
        ),
      );
      await tester.pump();

      final avatar = tester.widget<ChatAvatar>(find.byType(ChatAvatar));
      expect(avatar.imageUrl, avatarAsset);
      expect(find.byType(ChatAvatar), findsOneWidget);
      expect(find.byType(ChatImageMessage), findsOneWidget);
    },
  );

  testWidgets(
    'origin opening preview reveals AI notice above its first message',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final messages = originLocationOpeningPreviewMessagesForTesting(
        [
          {
            'tick_no': 1,
            'tick_result': {
              'current_time': 'Day 1, 08:30',
              'location_groups': [
                {
                  'location_id': 'loc_1',
                  'initial_dialogue': [
                    {
                      'char_id': 'nar',
                      'char_name': 'Narrator',
                      'content': 'The location wakes.',
                    },
                    {
                      'char_id': 'char_1',
                      'char_name': 'Sam',
                      'content': 'Opening line.',
                    },
                  ],
                },
              ],
            },
          },
        ],
        const ['loc_1'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LocationChatPanel(
            worldId: 'origin-preview',
            locationId: 'loc_1',
            active: false,
            openingPreviewMessages: messages,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find.descendant(
        of: find.byKey(const ValueKey<String>('location-chat-message-list')),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(find.text(kAiContentDisclaimerText), findsOneWidget);
      expect(position.pixels, closeTo(position.maxScrollExtent, 0.1));
      expect(
        tester.getCenter(find.text(kAiContentDisclaimerText)).dy,
        lessThanOrEqualTo(tester.getBottomLeft(find.byType(ChatHeader)).dy),
      );

      await tester.drag(scrollable, const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(position.pixels, 0);
      expect(
        tester.getCenter(find.text(kAiContentDisclaimerText)).dy,
        greaterThan(tester.getBottomLeft(find.byType(ChatHeader)).dy),
      );
    },
  );

  test('origin location parses dialogue lines', () {
    final location = OriginLocation.fromJson(const {
      'id': 12,
      'origin_id': 1,
      'location_id': 'loc_1',
      'location_name': 'Town Square',
      'dialogue': [
        {
          'char_id': 'char_1',
          'char_name': 'Casey',
          'content': 'Doors open at eight.',
        },
      ],
    });

    expect(location.dialogue, hasLength(1));
    expect(location.dialogue.single.charId, 'char_1');
    expect(location.dialogue.single.charName, 'Casey');
    expect(location.dialogue.single.content, 'Doors open at eight.');
  });

  test('origin map bubbles use location dialogue and character avatar ids', () {
    final origin = _originDetail(
      characters: [
        OriginCharacter(
          id: 7,
          characterId: 'char_1',
          originId: 1,
          name: 'Casey',
          avatar: '',
          tags: '',
          currentLocationId: 12,
          initialLocationId: 12,
          createdAt: null,
          updatedAt: null,
        ),
      ],
      locations: [
        OriginLocation.fromJson(const {
          'id': 12,
          'origin_id': 1,
          'location_id': 'loc_1',
          'location_name': 'Town Square',
          'dialogue': [
            {
              'char_id': 'char_1',
              'content': '*Casey flips the sign.* 「Open before sunrise.」',
            },
            {'char_id': 'nar', 'content': 'Narration should not show.'},
            {'char_id': 'missing', 'content': 'Missing character.'},
            {'char_id': 'char_1', 'content': ''},
          ],
        }),
      ],
    );

    final bubbles = originMapMessageBubblesForTesting(origin);

    expect(bubbles, hasLength(1));
    expect(bubbles.single.characterId, '7');
    expect(bubbles.single.content, 'Open before sunrise.');
  });

  test('origin map bubbles use init location dialogue first', () {
    final origin = _originDetail(
      characters: [
        OriginCharacter(
          id: 7,
          characterId: 'char_1',
          originId: 1,
          name: 'Casey',
          avatar: '',
          tags: '',
          currentLocationId: 12,
          initialLocationId: 12,
          createdAt: null,
          updatedAt: null,
        ),
      ],
      locations: [
        OriginLocation.fromJson(const {
          'id': 12,
          'origin_id': 1,
          'location_id': 'loc_1',
          'location_name': 'Town Square',
          'dialogue': <Object?>[
            <String, Object?>{
              'char_id': 'char_1',
              'content': 'Legacy location line.',
            },
          ],
        }),
      ],
      initLocationGroup: const OriginInitLocationGroup(
        locationId: 'loc_1',
        initialDialogue: [
          OriginDialogueLine(
            charId: 'char_1',
            charName: 'Casey',
            content: '*Casey checks the street.* 「The coast is clear.」',
          ),
          OriginDialogueLine(
            charId: 'nar',
            charName: 'Narrator',
            content: 'Narration should not show.',
          ),
        ],
      ),
    );

    final bubbles = originMapMessageBubblesForTesting(origin);

    expect(bubbles, hasLength(2));
    expect(bubbles.first.characterId, '7');
    expect(bubbles.map((bubble) => bubble.content), [
      'The coast is clear.',
      'Legacy location line.',
    ]);
  });

  test('origin map bubbles do not read tick opening dialogue', () {
    final origin = _originDetail(
      characters: [
        OriginCharacter(
          id: 7,
          characterId: 'char_1',
          originId: 1,
          name: 'Casey',
          avatar: '',
          tags: '',
          currentLocationId: 12,
          initialLocationId: 12,
          createdAt: null,
          updatedAt: null,
        ),
      ],
      locations: [
        OriginLocation.fromJson(const {
          'id': 12,
          'origin_id': 1,
          'location_id': 'loc_1',
          'location_name': 'Town Square',
        }),
      ],
      ticks: const [
        {
          'tick_no': 1,
          'tick_result': {
            'location_groups': [
              {
                'location_id': 'loc_1',
                'initial_dialogue': [
                  {
                    'char_id': 'char_1',
                    'char_name': 'Casey',
                    'content': 'The fallback line is visible.',
                  },
                ],
              },
            ],
          },
        },
      ],
    );

    final bubbles = originMapMessageBubblesForTesting(origin);

    expect(bubbles, isEmpty);
  });

  test('origin character resolves string current location ids', () {
    final character = OriginCharacter.fromJson(const {
      'id': 7,
      'character_id': 'char_1',
      'name': 'Casey',
      'current_location_id': 'loc_1',
    });
    final location = OriginLocation.fromJson(const {
      'location_id': 'loc_1',
      'location_name': 'Town Square',
    });

    expect(character.currentLocationBusinessId, 'loc_1');
    expect(character.currentLocationId, location.id);
  });

  test('origin map avatars have no AI star marker or white frame trigger', () {
    final avatar = originMapAvatarForTesting(
      OriginCharacter(
        id: 7,
        characterId: 'char_1',
        originId: 1,
        name: 'Casey',
        avatar: '',
        tags: '',
        currentLocationId: 12,
        initialLocationId: 12,
        createdAt: null,
        updatedAt: null,
      ),
    );

    expect(avatar.showStar, isFalse);
    expect(avatar.isPlayerControlledRole, isFalse);
  });

  test(
    'origin map bubbles ignore dialogue when character is at another location',
    () {
      final origin = _originDetail(
        characters: [
          OriginCharacter(
            id: 7,
            characterId: 'char_1',
            originId: 1,
            name: 'Casey',
            avatar: '',
            tags: '',
            currentLocationId: 13,
            initialLocationId: 13,
            createdAt: null,
            updatedAt: null,
          ),
        ],
        locations: [
          OriginLocation.fromJson(const {
            'id': 12,
            'origin_id': 1,
            'location_id': 'loc_1',
            'location_name': 'Town Square',
            'dialogue': [
              {'char_id': 'char_1', 'content': 'I am somewhere else.'},
            ],
          }),
          OriginLocation.fromJson(const {
            'id': 13,
            'origin_id': 1,
            'location_id': 'loc_2',
            'location_name': 'Harbor',
          }),
        ],
      );

      expect(originMapMessageBubblesForTesting(origin), isEmpty);
    },
  );

  test('origin character tagline reads brief directly', () {
    final character = OriginCharacter.fromJson(const {
      'character_id': 'char_1',
      'name': 'Sam',
      'identity': 'Archivist',
      'tagline': 'Old tagline should be ignored',
      'brief': 'Brief from API',
      'description': 'Description should be ignored',
      'goal': 'Protect the archive',
    });

    expect(character.tagline, 'Brief from API');
  });

  test(
    'origin character section omits description and uses unified body rhythm',
    () {
      final source = originSectionsSource;
      final characterRow = source.substring(
        source.indexOf('class _OriginCharacterRow'),
        source.indexOf('class _OriginCharacterPortrait'),
      );
      final bodyStyle = source.substring(
        source.indexOf('const _bodyTextStyle'),
        source.indexOf('const _mutedBodyTextStyle'),
      );

      expect(characterRow, isNot(contains('visibleDescription')));
      expect(characterRow, isNot(contains('character.description')));
      expect(characterRow, isNot(contains('_sameCharacterText')));
      expect(characterRow, isNot(contains('SizedBox(height: 9)')));
      expect(characterRow, contains("Text('Goal: \$goal'"));
      expect(bodyStyle, contains('height: 1.4'));
      expect(bodyStyle, isNot(contains('height: 1.45')));
      expect(bodyStyle, isNot(contains('height: 1.35')));
      expect(source, isNot(contains('bool _sameCharacterText')));
    },
  );

  test('origin info images use the requested DPR policies', () {
    final worldoBriefImage = originSectionsSource.substring(
      originSectionsSource.indexOf('class _OriginPreviewImage'),
      originSectionsSource.indexOf('class _LaunchPreviewSection'),
    );
    final characterPortrait = originSectionsSource.substring(
      originSectionsSource.indexOf('class _OriginCharacterPortrait'),
      originSectionsSource.indexOf('const _bodyTextStyle'),
    );

    expect(
      worldoBriefImage,
      contains('static const double _maxDevicePixelRatio = 2;'),
    );
    expect(
      worldoBriefImage,
      contains('maxDevicePixelRatio: _maxDevicePixelRatio'),
    );
    expect(
      characterPortrait,
      contains('maxDevicePixelRatio: devicePixelRatio'),
    );
    expect(
      characterPortrait,
      isNot(contains('_originRoleCardAvatarUrl(context, url)')),
    );
  });
}

OriginDetail _originDetail({
  required List<OriginCharacter> characters,
  required List<OriginLocation> locations,
  OriginInitLocationGroup? initLocationGroup,
  List<Map<String, dynamic>> ticks = const <Map<String, dynamic>>[],
}) {
  return OriginDetail(
    id: 1,
    oid: 'o_test',
    name: 'Origin',
    description: '',
    mapImage: '',
    worldMap: '',
    worldView: '',
    copyCount: 0,
    interactCount: 0,
    tags: const <String>[],
    createdAt: null,
    updatedAt: null,
    characters: characters,
    locations: locations,
    initLocationGroup: initLocationGroup,
    ticks: ticks,
  );
}
