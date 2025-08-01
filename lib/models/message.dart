import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String senderID;
  final String senderNickname; // Changed from senderEmail
  final String receiverID;
  final String message;
  final Timestamp timestamp;

  Message({
    required this.senderID,
    required this.senderNickname,
    required this.receiverID,
    required this.message,
    required this.timestamp,
  });

  // Convert Message object to a map
  Map<String, dynamic> toMap() {
    return {
      'senderID': senderID,
      'senderNickname': senderNickname,
      'receiverID': receiverID,
      'message': message,
      'timestamp': timestamp,
    };
  }
}

