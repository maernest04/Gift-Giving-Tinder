import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

      final uid = credential.user!.uid;
      final doc = await _db.collection('users').doc(uid).get();

      if (!doc.exists) {
        throw CustomAuthException('user-not-found', 'User data not found');
      }

      return UserModel.fromMap(doc.data()!, uid);
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

      print('Verification email sent to $newEmail. Firestore updated.');
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

  String _generatePartnerCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
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
