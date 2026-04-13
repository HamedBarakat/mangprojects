import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AuthRepository {
  final FirebaseAuth _auth;

  // Android fallback: store REST API user data manually
  static String? androidUid;
  static String? androidIdToken;

  AuthRepository(this._auth);

  Stream<User?> authStateChanges() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Merge Firebase SDK stream with manual Android auth state
      return _auth.authStateChanges().map((user) {
        if (user != null) return user;
        // Firebase SDK has no user but Android REST login succeeded
        // Return null — we handle this in currentUserProvider via androidUid
        return null;
      });
    }
    return _auth.authStateChanges();
  }

  Future<void> signOut() async {
    androidUid = null;
    androidIdToken = null;
    await _auth.signOut();
  }

  Future<bool> isUserActivated(String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return doc.exists;
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _loginAndroid(email: email, password: password);
    } else {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    }
  }

  Future<void> _loginAndroid({
    required String email,
    required String password,
  }) async {
    const apiKey = 'AIzaSyCT_DzOXrc13yux8rV_p0kfcjEdlFogPsw';

    if (kDebugMode) debugPrint('==> Android REST API login for $email');
    final restResponse = await http.post(
      Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
    );

    final restData = jsonDecode(restResponse.body);
    if (kDebugMode) debugPrint('==> REST status: ${restResponse.statusCode}');

    if (restResponse.statusCode != 200) {
      final errorCode = restData['error']?['message'] ?? 'UNKNOWN_ERROR';
      throw FirebaseAuthException(
        code: _mapErrorCode(errorCode),
        message: errorCode,
      );
    }

    // REST succeeded — store uid and token for manual auth state
    androidUid = restData['localId'] as String;
    androidIdToken = restData['idToken'] as String;
    if (kDebugMode) debugPrint('==> Android login success! uid=$androidUid');
  }

  String _mapErrorCode(String errorCode) {
    if (errorCode.contains('EMAIL_NOT_FOUND')) return 'user-not-found';
    if (errorCode.contains('INVALID_PASSWORD')) return 'wrong-password';
    if (errorCode.contains('INVALID_EMAIL')) return 'invalid-email';
    if (errorCode.contains('TOO_MANY_ATTEMPTS')) return 'too-many-requests';
    if (errorCode.contains('USER_DISABLED')) return 'user-disabled';
    if (errorCode.contains('INVALID_LOGIN_CREDENTIALS')) return 'wrong-password';
    return 'unknown';
  }

  String? getAndroidUid() => androidUid;

  Future<void> sendPasswordResetEmail({required String email}) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
