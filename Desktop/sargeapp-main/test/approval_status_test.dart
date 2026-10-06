import 'package:flutter_test/flutter_test.dart';
import 'package:sarge_depo_app/core/models/app_user.dart';

/// Regression tests for the v4.4.0 registration-approval system.
///
/// The critical invariant is the LEGACY FALLBACK: a `users` document that
/// predates the `approvalStatus` field must be read as `'approved'`, otherwise
/// every existing member would be locked behind the waiting screen after the
/// update ships.
void main() {
  /// Builds an [AppUser] the way `AppUser.fromDoc` does, from raw Firestore
  /// data, so the fallback logic is exercised exactly as it is in production.
  ///
  /// `DocumentSnapshot` is a sealed class, so we cannot hand-build one for a
  /// test. The fallback therefore also exists in [AppUser.applyApprovalFallback]
  /// — a tiny pure helper that `fromDoc` uses — and is what these tests target.
  AppUser userFromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'İsimsiz Üye',
      approvalStatus: AppUser.applyApprovalFallback(data['approvalStatus']),
    );
  }

  group('approvalStatus legacy fallback (never lock out existing members)', () {
    test('missing approvalStatus reads as approved', () {
      final user = userFromMap('u1', {'displayName': 'Eski Üye'});
      expect(user.approvalStatus, approvalApproved);
      expect(user.isApproved, isTrue);
      expect(user.needsApproval, isFalse);
      expect(user.isPendingApproval, isFalse);
      expect(user.isRejected, isFalse);
    });

    test('explicit null reads as approved', () {
      final user = userFromMap('u1', {
        'displayName': 'Eski Üye',
        'approvalStatus': null,
      });
      expect(user.approvalStatus, approvalApproved);
      expect(user.isApproved, isTrue);
    });

    test('explicit pending keeps the user behind the waiting screen', () {
      final user = userFromMap('u2', {
        'displayName': 'Yeni Üye',
        'approvalStatus': approvalPending,
      });
      expect(user.isApproved, isFalse);
      expect(user.isPendingApproval, isTrue);
      expect(user.needsApproval, isTrue);
    });

    test('explicit rejected blocks the user too', () {
      final user = userFromMap('u3', {
        'displayName': 'Reddedilen',
        'approvalStatus': approvalRejected,
      });
      expect(user.isApproved, isFalse);
      expect(user.isRejected, isTrue);
      expect(user.isPendingApproval, isFalse);
      // Rejected users are still gated out of the shell (but are NOT listed in
      // the admin's pending queue, which filters on 'pending' only).
      expect(user.needsApproval, isTrue);
    });

    test('explicit approved passes the gate', () {
      final user = userFromMap('u4', {
        'displayName': 'Onaylı',
        'approvalStatus': approvalApproved,
      });
      expect(user.isApproved, isTrue);
      expect(user.needsApproval, isFalse);
    });
  });

  group('approval constants', () {
    test('the three states are distinct strings', () {
      expect(
        {approvalPending, approvalApproved, approvalRejected}.length,
        3,
      );
    });

    test('constructor defaults to approved (never gate a hand-built AppUser)',
        () {
      const user = AppUser(uid: 'x', email: 'x@y.z', displayName: 'X');
      expect(user.isApproved, isTrue);
    });
  });
}
