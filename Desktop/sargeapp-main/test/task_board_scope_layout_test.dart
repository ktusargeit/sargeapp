import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarge_depo_app/core/models/app_user.dart';
import 'package:sarge_depo_app/core/models/user_profile_models.dart';
import 'package:sarge_depo_app/core/providers/auth_providers.dart';
import 'package:sarge_depo_app/features/tasks/widgets/task_add_dialog.dart';
import 'package:sarge_depo_app/features/team/providers/team_providers.dart';

/// Minimal `fb.User` stub: `AddTaskDialog` only ever reads `uid` from
/// `authStateProvider`, so no other member needs a real implementation.
class _FakeAuthUser extends Fake implements fb.User {
  _FakeAuthUser(this.uid);

  @override
  final String uid;
}

/// multi-select list inside `AddTaskDialog`.
///
/// TWO bugs are covered here:
///
/// 1. **Old (already fixed) crash** — `Container(maxHeight: 220)` +
///    `ListView(shrinkWrap: true)` inside an `AlertDialog` threw
///    "RenderShrinkWrappingViewport does not support returning intrinsic
///    dimensions." → the list MUST have a bounded height and NO `shrinkWrap`.
///
/// 2. **Ink/material assertion (this fix)** — the list was wrapped in a plain
///    opaque `Container(decoration: BoxDecoration(color: ...))`. A `ListTile`
///    (here `CheckboxListTile`) that finds an opaque, non-`Material` ancestor
///    triggers a debug assertion:
///      "ListTile background color or ink splashes may be invisible."
///    FIX: that box is now a `Material(color: ..., shape: ...)`.
///
/// Both assertions only fire in debug mode, which is exactly how `flutter test`
/// runs — so these tests fail loudly if anyone reverts either fix.
void main() {
  const boardPresident = AppUser(
    uid: 'u1',
    email: 'baskan@example.com',
    displayName: 'Ali Başkan',
    role: TitleType.boardPresident,
  );
  const boardMembers = <AppUser>[
    boardPresident,
    AppUser(
      uid: 'u2',
      email: 'uye@example.com',
      displayName: 'Ayşe Üye',
      role: TitleType.boardMember,
    ),
  ];

  /// Pumps an [AddTaskDialog] opened from a minimal scaffold so the test stays
  /// independent of routing / Firebase plumbing.
  ///
  /// `currentUserIdProvider` returns the board president so the "Yönetim
  /// Kurulu" assignment segment is offered, and `ref.read(currentAppUser)` sees
  /// a board member (`_isBoardCreator`).
  Future<void> pumpDialog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: <Override>[
        authStateProvider.overrideWith(
          (ref) => Stream<fb.User?>.value(
            _FakeAuthUser(boardPresident.uid),
          ),
        ),
        currentAppUserProvider
            .overrideWith((ref) => Stream.value(boardPresident)),
        // A plain StreamProvider → overridable, so no Firestore is created.
        boardMembersProvider.overrideWith((ref) => Stream.value(boardMembers)),
        // The dialog watches the team list too; keep it empty so nothing hits
        // Firestore while the dialog builds.
        clubTeamsProvider.overrideWith((ref) => Stream.value(const [])),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const AddTaskDialog(),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// Selects the "Yönetim Kurulu" assignment segment, which reveals the
  /// board-scope selector.
  Future<void> selectBoardMode(WidgetTester tester) async {
    final segment = find.text('Yönetim Kurulu');
    expect(segment, findsOneWidget,
        reason: 'a board member/admin must be offered the Yönetim Kurulu mode');
    await tester.tap(segment);
    await tester.pumpAndSettle();
  }

  /// Switches the board-scope segment to "Kuruldan Belirli Kişileri Seç" so
  /// the checkbox list gets built.
  Future<void> selectSpecificMembers(WidgetTester tester) async {
    final segment = find.text('Belirli Kişiler');
    expect(segment, findsOneWidget,
        reason: 'board scope selector must offer the specific-member option');
    await tester.tap(segment);
    await tester.pumpAndSettle();
  }

  Future<void> pumpBoardMemberList(WidgetTester tester) async {
    await pumpDialog(tester);
    await selectBoardMode(tester);
    await selectSpecificMembers(tester);
  }

  group('AddTaskDialog — Yönetim Kurulu kişi seçme listesi', () {
    testWidgets('renders the checkbox list without any layout assertion',
        (tester) async {
      await pumpBoardMemberList(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(CheckboxListTile), findsNWidgets(boardMembers.length));
      expect(find.text('Ali Başkan'), findsOneWidget);
      expect(find.text('Ayşe Üye'), findsOneWidget);
    });

    testWidgets(
      'the list keeps a bounded height and never shrink-wraps',
      (tester) async {
        await pumpBoardMemberList(tester);

        final listView = tester.widget<ListView>(find.byType(ListView).last);
        expect(listView.shrinkWrap, isFalse,
            reason: 'shrinkWrap inside AlertDialog throws the '
                'RenderShrinkWrappingViewport intrinsic-size assertion');

        // The viewport must be bounded by the SizedBox(height: 250).
        expect(tester.getSize(find.byType(ListView).last).height, 250);
      },
    );

    testWidgets(
      'the list background is a Material so the ListTile ink splash is visible',
      (tester) async {
        await pumpBoardMemberList(tester);

        // The NEAREST ancestor Material of the checkbox tile must be the
        // surface box itself and carry a color — otherwise Flutter asserts
        // "ListTile background color or ink splashes may be invisible."
        final tile = find.byType(CheckboxListTile).first;
        final nearest = tester.widget<Material>(
          find.ancestor(of: tile, matching: find.byType(Material)).first,
        );
        expect(nearest.color, isNotNull,
            reason: 'the surface box must be a Material with a color '
                '(previously a plain opaque Container)');
        expect(nearest.type, MaterialType.canvas);
        expect(nearest.shape, isA<RoundedRectangleBorder>(),
            reason: 'rounded corners + border must survive the change');
      },
    );

    testWidgets('tapping a row toggles the selection', (tester) async {
      await pumpBoardMemberList(tester);

      final firstTile = find.byType(CheckboxListTile).first;
      expect(tester.widget<CheckboxListTile>(firstTile).value, isFalse);

      await tester.tap(find.text('Ali Başkan'));
      await tester.pumpAndSettle();

      expect(tester.widget<CheckboxListTile>(firstTile).value, isTrue);
    });
  });
}
