import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class CustomAuthException implements Exception {
  final String code;
  final String message;
  CustomAuthException(this.code, this.message);

  @override
  String toString() => message;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream of User changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user data
  Future<UserModel?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;

    return UserModel.fromMap(doc.data()!, doc.id);
  }

  // Stream of User Data (for real-time updates)
  Stream<UserModel?> streamUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromMap(doc.data()!, doc.id);
    });
  }

  // Sign Up
  Future<UserModel> signUp(String email, String password, String name) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user!.uid;
      final partnerCode = _generatePartnerCode();

      final newUser = UserModel(
        id: uid,
        name: name,
        email: email,
        partnerCode: partnerCode,
      );

      await _db.collection('users').doc(uid).set({
        ...newUser.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // So Firebase email templates (password reset, etc.) can use %DISPLAY_NAME%
      await credential.user!.updateProfile(displayName: name);

      return newUser;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw CustomAuthException('unknown', 'Failed to sign up: $e');
    }
  }

  // Sign In
  Future<UserModel> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user!;
      final uid = user.uid;
      final doc = await _db.collection('users').doc(uid).get();

      if (!doc.exists) {
        throw CustomAuthException('user-not-found', 'User data not found');
      }

      final userModel = UserModel.fromMap(doc.data()!, uid);
      // Keep Auth displayName in sync so Firebase email templates show the user's name
      if ((user.displayName == null || user.displayName!.isEmpty) &&
          userModel.name.isNotEmpty) {
        await user.updateProfile(displayName: userModel.name);
      }
      return userModel;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw CustomAuthException('unknown', 'Failed to sign in: $e');
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Reset Password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw CustomAuthException('unknown', 'Failed to send reset email: $e');
    }
  }

  // Update Display Name
  Future<void> updateDisplayName(String newName) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw CustomAuthException('no-user', 'No user is currently signed in');
      }

      await _db.collection('users').doc(user.uid).update({'name': newName});
      // So Firebase email templates use the updated name
      await user.updateProfile(displayName: newName);
    } catch (e) {
      throw CustomAuthException('unknown', 'Failed to update name: $e');
    }
  }

  // Update Email
  Future<void> updateEmail(
    String newEmail,
    String oldEmail,
    String currentPassword,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw CustomAuthException('no-user', 'No user is currently signed in');
      }

      // Refresh user state to ensure we have the latest email (especially if verified recently)
      await user.reload();
      final freshUser = _auth.currentUser!;

      // 1. Re-authenticate user with current password to satisfy security requirements
      final credential = EmailAuthProvider.credential(
        email: freshUser.email!,
        password: currentPassword,
      );

      try {
        await freshUser.reauthenticateWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'invalid-credential' || e.code == 'wrong-password') {
          throw CustomAuthException(
            'wrong-password',
            'The password you entered is incorrect.',
          );
        }
        rethrow;
      }

      // 2. Send verification email to new address
      await user.verifyBeforeUpdateEmail(newEmail);

      // 3. Update email in Firestore
      await _db.collection('users').doc(user.uid).update({'email': newEmail});

      debugPrint('Verification email sent to $newEmail. Firestore updated.');
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e.toString().contains('permission-denied')) {
        throw CustomAuthException(
          'permission-denied',
          'You do not have permission to update this email address.',
        );
      }
      throw CustomAuthException('unknown', 'Failed to update email: $e');
    }
  }

  // Update Password
  Future<void> updatePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        throw CustomAuthException('no-user', 'No user is currently signed in');
      }

      // Refresh user state
      await user.reload();
      final freshUser = _auth.currentUser!;

      // Re-authenticate user with current password
      final credential = EmailAuthProvider.credential(
        email: freshUser.email!,
        password: currentPassword,
      );

      try {
        await freshUser.reauthenticateWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'invalid-credential' || e.code == 'wrong-password') {
          throw CustomAuthException(
            'wrong-password',
            'The current password you entered is incorrect.',
          );
        }
        rethrow;
      }

      // Update password
      await freshUser.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw CustomAuthException('unknown', 'Failed to update password: $e');
    }
  }

  /// Find a user by their partner code (so you can send a partner request).
  /// Returns null if not found or if code is empty. Requires Firestore index on users.partnerCode.
  Future<UserModel?> findUserByPartnerCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    final q = await _db
        .collection('users')
        .where('partnerCode', isEqualTo: normalized)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    final doc = q.docs.first;
    return UserModel.fromMap(doc.data(), doc.id);
  }

  /// Get a user by uid (for showing names).
  Future<UserModel?> getUser(String uid) async {
    if (uid.isEmpty) return null;
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!, doc.id);
  }

  /// Send a partner request: you entered their code. Creates partner_requests doc and sets your pendingRequestToId.
  Future<void> sendPartnerRequest(String myUid, String theirUid) async {
    final batch = _db.batch();
    batch.update(_db.collection('users').doc(myUid), {
      'pendingRequestToId': theirUid,
    });
    batch.set(_db.collection('partner_requests').doc(), {
      'fromUid': myUid,
      'toUid': theirUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Accept incoming request: link both users by partnerId, delete request doc, clear their pendingRequestToId.
  Future<void> acceptPartnerRequest(String myUid, String theirUid, String requestDocId) async {
    final batch = _db.batch();
    batch.update(_db.collection('users').doc(myUid), {
      'partnerId': theirUid,
    });
    batch.update(_db.collection('users').doc(theirUid), {
      'partnerId': myUid,
      'pendingRequestToId': null,
    });
    batch.delete(_db.collection('partner_requests').doc(requestDocId));
    await batch.commit();
  }

  /// Decline incoming request: delete the request doc.
  Future<void> declinePartnerRequest(String myUid, String theirUid, String requestDocId) async {
    await _db.collection('partner_requests').doc(requestDocId).delete();
  }

  /// Cancel outgoing request: delete request doc and clear your pendingRequestToId.
  Future<void> cancelPartnerRequest(String myUid, String theirUid) async {
    final q = await _db
        .collection('partner_requests')
        .where('fromUid', isEqualTo: myUid)
        .where('toUid', isEqualTo: theirUid)
        .limit(1)
        .get();
    final batch = _db.batch();
    for (final doc in q.docs) {
      batch.delete(doc.reference);
    }
    batch.update(_db.collection('users').doc(myUid), {
      'pendingRequestToId': null,
    });
    await batch.commit();
  }

  /// Stream of incoming partner requests for the current user (toUid == myUid).
  Stream<Map<String, String>?> streamIncomingRequest(String myUid) {
    return _db
        .collection('partner_requests')
        .where('toUid', isEqualTo: myUid)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;
          final doc = snap.docs.first;
          final d = doc.data();
          return {
            'requestId': doc.id,
            'fromUid': d['fromUid'] as String? ?? '',
          };
        });
  }

  /// Remove linked partner on both sides.
  Future<void> removePartner(String myUid, String partnerUid) async {
    await _db.collection('users').doc(myUid).update({
      'partnerId': null,
    });
    await _db.collection('users').doc(partnerUid).update({
      'partnerId': null,
    });
  }

  /// Generates a 10-character partner code (32^10 ~ 1e15 combos) to avoid collisions at scale.
  String _generatePartnerCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(10, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  CustomAuthException _handleAuthException(FirebaseAuthException e) {
    String message;
    switch (e.code) {
      case 'user-not-found':
        message = 'No user found for that email.';
        break;
      case 'wrong-password':
        message = 'Wrong password provided.';
        break;
      case 'email-already-in-use':
        message = 'The account already exists for that email.';
        break;
      case 'weak-password':
        message = 'The password provided is too weak.';
        break;
      case 'invalid-email':
        message = 'The email address is invalid.';
        break;
      case 'invalid-credential':
        message = 'Invalid email or password.';
        break;
      case 'requires-recent-login':
        message =
            'For security, please log out and log back in before changing your email.';
        break;
      default:
        message = e.message ?? 'Authentication failed';
    }
    return CustomAuthException(e.code, message);
  }
}
