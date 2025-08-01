import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache for user nicknames to reduce database reads
  final Map<String, String> _userNicknameCache = {};

  // Map to track active corners and their timers
  final Map<String, Timer> _cornerTimers = {};

  // Stream controller for corner invitations
  final StreamController<Map<String, dynamic>> _cornerInvitationsController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Getter for the corner invitations stream
  Stream<Map<String, dynamic>> get cornerInvitations =>
      _cornerInvitationsController.stream;

  // Fetch users with their nicknames
  Stream<List<Map<String, dynamic>>> getUserStream() {
    return _firestore.collection("Users").snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final user = doc.data();
        return user;
      }).toList();
    });
  }

  Future<bool> isExpired(String chatID, bool isSpace) async {
  try {
    final DocumentSnapshot chatDoc = await _firestore
        .collection(isSpace ? "Spaces" : "Corners")
        .doc(chatID)
        .get();

    if (chatDoc.exists) {
      final data = chatDoc.data() as Map<String, dynamic>;
      if (data.containsKey('expiresAt')) {
        final Timestamp expiresAt = data['expiresAt'];
        return DateTime.now().isAfter(expiresAt.toDate());
      }
    }
    return false;
  } catch (e) {
    print("Error checking expiration: $e");
    return false;
  }
}

  // Fetch spaces
  Stream<QuerySnapshot> getSpacesStream() {
    return _firestore.collection("Spaces").snapshots();
  }

  // Get user nickname with caching
  Future<String> getUserNickname(String userID) async {
    // Check cache first
    if (_userNicknameCache.containsKey(userID)) {
      return _userNicknameCache[userID]!;
    }

    try {
      final DocumentSnapshot userDoc = await _firestore.collection("Users").doc(userID).get();
      if (userDoc.exists) {
        final String nickname = userDoc['nickname'] ?? 'Unknown';
        // Cache the result
        _userNicknameCache[userID] = nickname;
        return nickname;
      }
      return 'Unknown';
    } catch (e) {
      // Handle error
      return 'Unknown';
    }
  }

  // Send a message to a space
  Future<void> sendMessageToSpace(String spaceID, String message, {bool isSystemMessage = false}) async {
    final String currentUserID = _auth.currentUser!.uid;
    String senderNickname = 'System';

    // Only fetch nickname for non-system messages
    if (!isSystemMessage) {
      senderNickname = await getUserNickname(currentUserID);
    }

    final Timestamp timestamp = Timestamp.now();

    // Create a new message
    final Map<String, dynamic> newMessage = {
      'senderID': isSystemMessage ? 'system' : currentUserID,
      'senderNickname': senderNickname,
      'message': message,
      'timestamp': timestamp,
      'isSystemMessage': isSystemMessage,
    };

    // Add the message to the space's messages collection
    await _firestore
        .collection("Spaces")
        .doc(spaceID)
        .collection("messages")
        .add(newMessage);

    // Update the space's lastActivity field
    await _firestore
        .collection("Spaces")
        .doc(spaceID)
        .update({
          'lastActivity': timestamp,
          'lastMessage': message,
          'lastMessageSender': senderNickname,
        });
  }

  // Send a message to a corner
  Future<void> sendMessageToCorner(String cornerID, String message, {bool isSystemMessage = false}) async {
    final String currentUserID = _auth.currentUser!.uid;
    String senderNickname = 'System';

    // Only fetch nickname for non-system messages
    if (!isSystemMessage) {
      senderNickname = await getUserNickname(currentUserID);
    }

    final Timestamp timestamp = Timestamp.now();

    // Create a new message
    final Map<String, dynamic> newMessage = {
      'senderID': isSystemMessage ? 'system' : currentUserID,
      'senderNickname': senderNickname,
      'message': message,
      'timestamp': timestamp,
      'isSystemMessage': isSystemMessage,
    };

    // Add the message to the corner's messages collection
    await _firestore
        .collection("Corners")
        .doc(cornerID)
        .collection("messages")
        .add(newMessage);

    // Update the corner's lastActivity field
    await _firestore
        .collection("Corners")
        .doc(cornerID)
        .update({
          'lastActivity': timestamp,
          'lastMessage': message,
          'lastMessageSender': senderNickname,
        });
  }

  // General function to send a message (for both spaces and corners)
  Future<void> sendMessage(String chatID, String message, {bool isSpace = true, bool isSystemMessage = false}) async {
    if (isSpace) {
      await sendMessageToSpace(chatID, message, isSystemMessage: isSystemMessage);
    } else {
      await sendMessageToCorner(chatID, message, isSystemMessage: isSystemMessage);
    }
  }

  // General function to fetch messages (for both spaces and corners)
  Stream<QuerySnapshot> getMessages(String chatID, {bool isSpace = true}) {
    if (isSpace) {
      return _firestore
          .collection("Spaces")
          .doc(chatID)
          .collection("messages")
          .orderBy("timestamp", descending: false)
          .snapshots();
    } else {
      return _firestore
          .collection("Corners")
          .doc(chatID)
          .collection("messages")
          .orderBy("timestamp", descending: false)
          .snapshots();
    }
  }

  // Get space details
  Future<DocumentSnapshot> getSpaceDetails(String spaceID) {
    return _firestore.collection("Spaces").doc(spaceID).get();
  }

  // Get space members
  Future<QuerySnapshot> getSpaceMembers(String spaceID) {
    return _firestore
        .collection("Spaces")
        .doc(spaceID)
        .collection("members")
        .get();
  }

  // Check if user is space creator
  Future<bool> isSpaceCreator(String spaceID) async {
    final String currentUserID = _auth.currentUser!.uid;
    final spaceDoc = await _firestore.collection("Spaces").doc(spaceID).get();

    if (spaceDoc.exists) {
      return spaceDoc['createdBy'] == currentUserID;
    }
    return false;
  }

  // Show about space dialog - moved from ChatPage
  Future<Map<String, dynamic>> getSpaceInfo(String spaceID) async {
    try {
      final spaceDoc = await _firestore.collection("Spaces").doc(spaceID).get();
      if (!spaceDoc.exists) {
        return {'error': 'Space information not available'};
      }

      final data = spaceDoc.data() as Map<String, dynamic>;
      final createdBy = data['createdBy'] ?? 'Unknown';
      final creatorNickname = await getUserNickname(createdBy);

      return {
        'name': data['name'] ?? 'Unknown Space',
        'description': data['description'] ?? 'No description available',
        'createdBy': createdBy,
        'creatorNickname': creatorNickname,
        'createdAt': data['createdAt'],
        'memberCount': data['memberCount'] ?? 0,
      };
    } catch (e) {
      return {'error': 'Error loading space details: $e'};
    }
  }

  // Remove user from space
  Future<void> removeUserFromSpace(String spaceID, String userID) async {
    // Get user's nickname for the system message
    final String nickname = await getUserNickname(userID);

    // Remove user from space members
    await _firestore
        .collection("Spaces")
        .doc(spaceID)
        .collection("members")
        .doc(userID)
        .delete();

    // Update members array in the space document
    final spaceDoc = await _firestore.collection("Spaces").doc(spaceID).get();
    if (spaceDoc.exists) {
      final List<dynamic> members = List.from(spaceDoc['members'] ?? []);
      members.remove(userID);

      // Update member count and members array
      await _firestore
          .collection("Spaces")
          .doc(spaceID)
          .update({
            'memberCount': members.length,
            'members': members
          });
    }

    // Send system message
    await sendMessage(
      spaceID,
      "$nickname has been removed from the space.",
      isSpace: true,
      isSystemMessage: true,
    );
  }

  // Delete space completely - fixed to remove all data
  Future<void> deleteSpace(String spaceID) async {
    try {
      // Send a system message to notify users
      await sendMessage(
        spaceID,
        "This space has been deleted by the admin.",
        isSpace: true,
        isSystemMessage: true,
      );

      // Get all messages in the space
      final messagesSnapshot = await _firestore
          .collection("Spaces")
          .doc(spaceID)
          .collection("messages")
          .get();

      // Delete all messages in batches
      final WriteBatch batch = _firestore.batch();
      int operationCount = 0;

      for (var doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
        operationCount++;

        // Firestore batches are limited to 500 operations
        if (operationCount >= 450) {
          await batch.commit();
          operationCount = 0;
        }
      }

      if (operationCount > 0) {
        await batch.commit();
      }

      // Get all members in the space
      final membersSnapshot = await _firestore
          .collection("Spaces")
          .doc(spaceID)
          .collection("members")
          .get();

      // Delete all member documents
      final WriteBatch membersBatch = _firestore.batch();
      operationCount = 0;

      for (var doc in membersSnapshot.docs) {
        membersBatch.delete(doc.reference);
        operationCount++;

        if (operationCount >= 450) {
          await membersBatch.commit();
          operationCount = 0;
        }
      }

      if (operationCount > 0) {
        await membersBatch.commit();
      }

      // Finally delete the space document itself
      await _firestore.collection("Spaces").doc(spaceID).delete();
    } catch (e) {
      rethrow;
    }
  }

  // Invite user to a corner with 30-second timer
  Future<Map<String, dynamic>> inviteToCorner(String inviteeID, String spaceID) async {
  try {
    final String inviterID = _auth.currentUser!.uid;
    final String inviterNickname = await getUserNickname(inviterID);
    final String inviteeNickname = await getUserNickname(inviteeID);

    // Fetch the parent space's foulLanguageDetection setting and expiration time
    final spaceDoc = await _firestore.collection("Spaces").doc(spaceID).get();
    final bool foulLanguageDetection = spaceDoc['foulLanguageDetection'] ?? false;

    // Check if the space is expired
    if (spaceDoc.data() is Map<String, dynamic>) {
      final spaceData = spaceDoc.data() as Map<String, dynamic>;
      if (spaceData.containsKey('expiresAt')) {
        final Timestamp expiresAt = spaceData['expiresAt'];
        if (DateTime.now().isAfter(expiresAt.toDate())) {
          return {
            'success': false,
            'error': 'The space has expired',
          };
        }
      }
    }

    // Create a new corner document
    final cornerRef = _firestore.collection("Corners").doc();
    final String cornerID = cornerRef.id;
    final Timestamp now = Timestamp.now();

    // Set corner expiration time (30 seconds for invitation, or inherit from space)
    Timestamp cornerExpiresAt;
    if (spaceDoc.data() is Map<String, dynamic>) {
      final spaceData = spaceDoc.data() as Map<String, dynamic>;
      if (spaceData.containsKey('expiresAt')) {
        // Use the space's expiration time if it exists
        cornerExpiresAt = spaceData['expiresAt'];
      } else {
        // Default to 30 seconds for invitation
        cornerExpiresAt = Timestamp.fromDate(DateTime.now().add(Duration(seconds: 30)));
      }
    } else {
      // Default to 30 seconds for invitation
      cornerExpiresAt = Timestamp.fromDate(DateTime.now().add(Duration(seconds: 30)));
    }

    // Set corner data
    await cornerRef.set({
      'type': 'temporary',
      'status': 'pending',
      'parentSpaceID': spaceID,
      'inviterID': inviterID,
      'inviteeID': inviteeID,
      'inviterNickname': inviterNickname,
      'inviteeNickname': inviteeNickname,
      'createdAt': now,
      'expiresAt': cornerExpiresAt,
      'participants': [inviterID],
      'accepted': false,
      'foulLanguageDetection': foulLanguageDetection,
    });

    // Start a timer to delete the corner if not accepted
    _cornerTimers[cornerID] = Timer(Duration(seconds: 30), () async {
      await _handleExpiredCornerInvitation(cornerID);
    });

    // Notify the invitee through the stream
    _cornerInvitationsController.add({
      'type': 'invitation',
      'cornerID': cornerID,
      'inviterID': inviterID,
      'inviterNickname': inviterNickname,
      'inviteeID': inviteeID,
      'spaceID': spaceID,
      'timestamp': now,
    });

    return {
      'success': true,
      'cornerID': cornerID,
      'inviteeNickname': inviteeNickname,
    };
  } catch (e) {
    return {
      'success': false,
      'error': e.toString(),
    };
  }
}

// Add a method to check if a user can enter a space
Future<bool> canEnterSpace(String spaceID) async {
  try {
    final spaceDoc = await _firestore.collection("Spaces").doc(spaceID).get();

    if (!spaceDoc.exists) {
      return false;
    }

    final data = spaceDoc.data() as Map<String, dynamic>;
    if (data.containsKey('expiresAt')) {
      final Timestamp expiresAt = data['expiresAt'];
      return DateTime.now().isBefore(expiresAt.toDate());
    }

    return true;
  } catch (e) {
    print("Error checking if user can enter space: $e");
    return false;
  }
}

// Add a method to check if a user can enter a corner
Future<bool> canEnterCorner(String cornerID) async {
  try {
    final cornerDoc = await _firestore.collection("Corners").doc(cornerID).get();

    if (!cornerDoc.exists) {
      return false;
    }

    final data = cornerDoc.data() as Map<String, dynamic>;

    // Check if corner is active
    if (data['status'] != 'active') {
      return false;
    }

    // Check expiration
    if (data.containsKey('expiresAt')) {
      final Timestamp expiresAt = data['expiresAt'];
      return DateTime.now().isBefore(expiresAt.toDate());
    }

    return true;
  } catch (e) {
    print("Error checking if user can enter corner: $e");
    return false;
  }
}

  // Handle expired corner invitation
  Future<void> _handleExpiredCornerInvitation(String cornerID) async {
    try {
      // Cancel the timer if it exists
      if (_cornerTimers.containsKey(cornerID)) {
        _cornerTimers[cornerID]!.cancel();
        _cornerTimers.remove(cornerID);
      }

      // Check if the corner still exists and is still pending
      final cornerDoc = await _firestore.collection("Corners").doc(cornerID).get();
      if (cornerDoc.exists && cornerDoc['status'] == 'pending') {
        // Update the corner status
        await _firestore
            .collection("Corners")
            .doc(cornerID)
            .update({
              'status': 'expired',
            });

        // Notify users through the stream
        _cornerInvitationsController.add({
          'type': 'expired',
          'cornerID': cornerID,
        });

        // Delete the corner after a short delay
        Timer(Duration(seconds: 5), () async {
          await _firestore.collection("Corners").doc(cornerID).delete();
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  // Accept corner invitation
  Future<Map<String, dynamic>> acceptCornerInvitation(String cornerID) async {
  try {
    final String currentUserID = _auth.currentUser!.uid;

    // Cancel the timer if it exists
    if (_cornerTimers.containsKey(cornerID)) {
      _cornerTimers[cornerID]!.cancel();
      _cornerTimers.remove(cornerID);
    }

    // Check if the corner still exists and is still pending
    final cornerDoc = await _firestore.collection("Corners").doc(cornerID).get();
    if (!cornerDoc.exists) {
      return {
        'success': false,
        'error': 'Corner invitation no longer exists',
      };
    }

    if (cornerDoc['status'] != 'pending') {
      return {
        'success': false,
        'error': 'Corner invitation has expired',
      };
    }

    // Check if the corner has expired
    if (cornerDoc.data() is Map<String, dynamic>) {
      final data = cornerDoc.data() as Map<String, dynamic>;
      if (data.containsKey('expiresAt')) {
        final Timestamp expiresAt = data['expiresAt'];
        if (DateTime.now().isAfter(expiresAt.toDate())) {
          await _handleExpiredCornerInvitation(cornerID);
          return {
            'success': false,
            'error': 'Corner invitation has expired',
          };
        }
      }
    }

    // Make sure the current user is the invitee
    if (cornerDoc['inviteeID'] != currentUserID) {
      return {
        'success': false,
        'error': 'You are not the invited user',
      };
    }

    // Update the corner status and add the invitee to participants
    final List<dynamic> participants = List.from(cornerDoc['participants'] ?? []);
    if (!participants.contains(currentUserID)) {
      participants.add(currentUserID);
    }

    await _firestore
        .collection("Corners")
        .doc(cornerID)
        .update({
          'status': 'active',
          'accepted': true,
          'participants': participants,
          'acceptedAt': Timestamp.now(),
        });

    // Add welcome message
    await sendMessageToCorner(
      cornerID,
      "Corner created! This is a private conversation.",
      isSystemMessage: true,
    );

    // Notify users through the stream
    _cornerInvitationsController.add({
      'type': 'accepted',
      'cornerID': cornerID,
    });

    return {
      'success': true,
      'cornerID': cornerID,
      'inviterNickname': cornerDoc['inviterNickname'],
    };
  } catch (e) {
    return {
      'success': false,
      'error': e.toString(),
    };
  }
}

  // Decline corner invitation
  Future<void> declineCornerInvitation(String cornerID) async {
    try {
      // Cancel the timer if it exists
      if (_cornerTimers.containsKey(cornerID)) {
        _cornerTimers[cornerID]!.cancel();
        _cornerTimers.remove(cornerID);
      }

      // Update the corner status
      await _firestore
          .collection("Corners")
          .doc(cornerID)
          .update({
            'status': 'declined',
          });

      // Notify users through the stream
      _cornerInvitationsController.add({
        'type': 'declined',
        'cornerID': cornerID,
      });

      // Delete the corner after a short delay
      Timer(Duration(seconds: 5), () async {
        await _firestore.collection("Corners").doc(cornerID).delete();
      });
    } catch (e) {
      // Handle error
    }
  }

  // Exit corner and clean up
  Future<void> exitCorner(String cornerID, String spaceID) async {
    try {
      final String currentUserID = _auth.currentUser!.uid;
      final String userNickname = await getUserNickname(currentUserID);

      // Send system message
      await sendMessageToCorner(
        cornerID,
        "$userNickname has left the corner.",
        isSystemMessage: true,
      );

      // Get corner details
      final cornerDoc = await _firestore.collection("Corners").doc(cornerID).get();
      if (!cornerDoc.exists) return;

      // If this is a temporary corner, delete it
      if (cornerDoc['type'] == 'temporary') {
        // Notify the other participant
        final List<dynamic> participants = List.from(cornerDoc['participants'] ?? []);
        participants.remove(currentUserID);

        if (participants.isEmpty) {
          // If no participants left, just delete the corner
          await _firestore.collection("Corners").doc(cornerID).delete();
        } else {
          // Notify the remaining participant
          _cornerInvitationsController.add({
            'type': 'user_left',
            'cornerID': cornerID,
            'userNickname': userNickname,
            'spaceID': spaceID,
          });

          // Delete the corner after a short delay
          Timer(Duration(seconds: 5), () async {
            await _firestore.collection("Corners").doc(cornerID).delete();
          });
        }
      } else {
        // For permanent corners, just remove the user
        final List<dynamic> participants = List.from(cornerDoc['participants'] ?? []);
        participants.remove(currentUserID);

        await _firestore
            .collection("Corners")
            .doc(cornerID)
            .update({
              'participants': participants,
            });
      }
    } catch (e) {
      // Handle error
    }
  }

  // Register user presence for corner auto-closing
  Future<void> registerUserPresence(String userID, bool isOnline) async {
    try {
      await _firestore
          .collection("Users")
          .doc(userID)
          .update({
            'isOnline': isOnline,
            'lastSeen': Timestamp.now(),
          });
    } catch (e) {
      // Handle error
    }
  }

  // Clean up when app is closed or crashes
  Future<void> handleAppExit() async {
    try {
      final String currentUserID = _auth.currentUser!.uid;

      // Update user presence
      await registerUserPresence(currentUserID, false);

      // Find all temporary corners where user is a participant
      final cornersSnapshot = await _firestore
          .collection("Corners")
          .where('type', isEqualTo: 'temporary')
          .where('participants', arrayContains: currentUserID)
          .get();

      // Exit each corner
      for (var doc in cornersSnapshot.docs) {
        final String cornerID = doc.id;
        final String spaceID = doc['parentSpaceID'] ?? '';

        await exitCorner(cornerID, spaceID);
      }
    } catch (e) {
      // Handle error
    }
  }

  // Dispose method to clean up resources
  void dispose() {
    // Cancel all timers
    for (var timer in _cornerTimers.values) {
      timer.cancel();
    }
    _cornerTimers.clear();

    // Close the stream controller
    _cornerInvitationsController.close();
  }
}