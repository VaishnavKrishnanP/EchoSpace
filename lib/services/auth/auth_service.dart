import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  Future<UserCredential> signInWithEmailPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }

  Future<UserCredential> signUpWithEmailPassword(String email, String password, String nickname) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );



      // Store user data in Firestore
      await _firestore.collection("Users").doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': email,
        'nickname': nickname,
      });


      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }

  Future<void> signOut() async {
    return await _auth.signOut();
  }

  Future<void> sendOTP(String email) async {
    try {
      final HttpsCallable generateOTP = FirebaseFunctions.instance.httpsCallable('generateOTP');
      await generateOTP.call({'email': email});
    } on FirebaseException catch (e) {
      throw Exception(e.message);
    }
  }

  Future<void> verifyOTP(String email, String otp) async {
    try {
      final HttpsCallable verifyOTP = FirebaseFunctions.instance.httpsCallable('verifyOTP');
      await verifyOTP.call({'email': email, 'otp': otp});
    } on FirebaseException catch (e) {
      throw Exception(e.message);
    }
  }
}
