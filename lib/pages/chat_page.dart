import 'package:echospace/components/chat_bubble.dart';
import 'package:echospace/components/my_textfield.dart';
import 'package:echospace/services/auth/auth_service.dart';
import 'package:echospace/services/chat/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../themes/theme_provider.dart';
import 'dart:async';
import 'home_page.dart';
import 'package:echospace/services/foul_language.dart';
import 'package:echospace/services/encrypt.dart';

class ChatPage extends StatefulWidget {
  final String chatID;
  final String chatName;
  final bool isSpace;
  final bool foulLanguageDetection;

  const ChatPage({
    super.key,
    required this.chatID,
    required this.chatName,
    required this.isSpace,
    required this.foulLanguageDetection,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FoulLanguageDetector _foulLanguageDetector = FoulLanguageDetector()..loadFoulWords(foulWords);
  final Map<String, String> _userNicknameCache = {};
  StreamSubscription<DocumentSnapshot>? _expirationSubscription;

  bool _isSpaceCreator = false;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isExpired = false;
  String? _errorMessage;
  DateTime? _expirationTime;
  int _previousMessageCount = 0;


  @override
  void initState() {
    super.initState();
    _initializeChat();
    _setupExpirationListener();
    _addToRecentSpaces();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _expirationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _addToRecentSpaces() async {
  if (!widget.isSpace) return;

  final userId = _authService.getCurrentUser()!.uid;
  final recentSpacesRef = _firestore.collection('Users')
      .doc(userId)
      .collection('recentSpaces')
      .doc(widget.chatID);

  // First check if this space is already in recentSpaces
  final existingDoc = await recentSpacesRef.get();

  final spaceDoc = await _firestore.collection('Spaces').doc(widget.chatID).get();

  if (spaceDoc.exists) {
    final spaceName = spaceDoc['name'] as String? ?? '';
    final spaceDesc = spaceDoc['description'] as String? ?? '';
    final combinedText = '$spaceName $spaceDesc'.trim();

    if (existingDoc.exists) {
      // Update existing document with new timestamp
      await recentSpacesRef.update({
        'timestamp': FieldValue.serverTimestamp(),
        // Optionally update the text if space details changed
        'text': combinedText,
      });
    } else {
      // Create new document
      await recentSpacesRef.set({
        'text': combinedText,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }
}

  Future<void> _initializeChat() async {
    try {
      await _checkIfUserIsSpaceCreator();
      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = "Failed to initialize chat: ${e.toString()}";
      });
    }
  }

void _setupExpirationListener() {
  _expirationSubscription = _firestore
      .collection(widget.isSpace ? "Spaces" : "Corners")
      .doc(widget.chatID)
      .snapshots()
      .listen((doc) async {  // Make this async
      if (!doc.exists) {
        if (!mounted) return;
        setState(() => _isExpired = true);
        _handleExpiration();
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      if (data.containsKey('expiresAt')) {
        final expiresAt = (data['expiresAt'] as Timestamp).toDate();
        final now = DateTime.now();
        final isExpired = expiresAt.isBefore(now);

        if (!mounted) return;
        setState(() {
          _expirationTime = expiresAt;
          _isExpired = isExpired;
        });

        if (isExpired) {
          await _handleExpiration(); // Make this await
        }
      }
    }, onError: (error) {
      debugPrint("Error listening to expiration: $error");
    });
}

  Future<void> _handleExpiration() async {
  if (!mounted || _isExpired) return;

  try {
    setState(() => _isExpired = true);

    // 3. Navigate to home after delay
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => HomePage()), // Your home page widget
        (Route<dynamic> route) => false, // Remove all routes
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("This ${widget.isSpace ? 'space' : 'corner'} has expired"),
        backgroundColor: Colors.red,
      ),
    );
  } catch (e) {
    debugPrint("Expiration navigation error: $e");
    // Fallback - try normal pop if the above fails
    if (mounted) Navigator.of(context).pop();
  }
}

  Future<void> _checkIfUserIsSpaceCreator() async {
    if (!widget.isSpace) return;
    final isCreator = await _chatService.isSpaceCreator(widget.chatID);
    if (!mounted) return;
    setState(() => _isSpaceCreator = isCreator);
  }

  void scrollDown() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void sendMessage() async {
  if (_isSending) return;

  final message = _messageController.text.trim();
  if (message.isEmpty) {
    _showErrorToast("Empty message cannot be sent");
    return;
  }

  if (widget.foulLanguageDetection &&
      _foulLanguageDetector.hasFoulLanguage(message)) {
    _showErrorToast("Foul language detected in message");
    return;
  }

  _isSending = true;
  _messageController.clear();
  scrollDown();

  try {
    final encryptedMessage = crypto.encrypt(message);

    unawaited(
      _chatService.sendMessage(widget.chatID, encryptedMessage).then((_) {
        if (mounted) setState(() => _isSending = false);
      }).catchError((e) {
        if (mounted) {
          setState(() => _isSending = false);
          _showErrorToast("Failed to send: ${e.toString()}");
        }
      }),
    );
  } catch (e) {
    if (mounted) {
      setState(() => _isSending = false);
      _showErrorToast("Encryption failed: ${e.toString()}");
    }
  }
}


  Widget _buildTimeRemaining() {
    if (_expirationTime == null) return const SizedBox.shrink();

    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, _) {
        final now = DateTime.now();
        final difference = _expirationTime!.difference(now);

        if (difference.isNegative) {
          if (!_isExpired) _handleExpiration();
          return const SizedBox.shrink();
        }

        final hours = difference.inHours;
        final minutes = difference.inMinutes.remainder(60);
        final seconds = difference.inSeconds.remainder(60);

        return Text(
          "Expires: ${hours > 0 ? '$hours:' : ''}${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}",
          style: TextStyle(
            fontSize: 12,
            color: _isExpired ? Colors.red : Colors.white70,
          ),
        );
      },
    );
  }

  void _showUserOptions(BuildContext context, String userID, String userNickname) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              userNickname,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text("Invite to Corner"),
              onTap: () {
                Navigator.pop(context);
                _showInfoToast("Feature coming soon");
              },
            ),
            if (_isSpaceCreator && _authService.getCurrentUser()!.uid != userID)
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text("Remove from Space", style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmRemoveUser(userID, userNickname);
                },
              ),
            ListTile(
              leading: const Icon(Icons.flag),
              title: const Text("Report User"),
              onTap: () {
                Navigator.pop(context);
                _showInfoToast("Feature coming soon");
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRemoveUser(String userID, String nickname) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove User"),
        content: Text("Are you sure you want to remove $nickname from this space?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Cancel"),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () {
              Navigator.pop(context);
              _removeUserFromSpace(userID, nickname);
            },
            child: const Text("Remove"),
          ),
        ],
      ),
    );
  }

  Future<void> _removeUserFromSpace(String userID, String nickname) async {
    try {
      await _chatService.removeUserFromSpace(widget.chatID, userID);
      if (!mounted) return; // Check if the widget is still mounted
      _showSuccessToast("User removed successfully");
    } catch (e) {
      if (!mounted) return; // Check if the widget is still mounted
      _showErrorToast("Failed to remove user: ${e.toString()}");
    }
  }

  Future<String> _getUserNickname(String userID) async {
    // Check cache first
    if (_userNicknameCache.containsKey(userID)) {
      return _userNicknameCache[userID]!;
    }

    try {
      final nickname = await _chatService.getUserNickname(userID);
      // Cache the result
      _userNicknameCache[userID] = nickname;
      return nickname;
    } catch (e) {
      return 'Unknown';
    }
  }

  void _showMembersList() async {
    try {
      final membersSnapshot = await _chatService.getSpaceMembers(widget.chatID);
      final List<Map<String, dynamic>> members = [];

      for (var doc in membersSnapshot.docs) {
        final userID = doc.id;
        final nickname = await _getUserNickname(userID);
        members.add({
          'id': userID,
          'nickname': nickname,
          'joinedAt': doc['joinedAt'],
        });
      }

      // Sort by join date
      members.sort((a, b) => (a['joinedAt'] as Timestamp).compareTo(b['joinedAt'] as Timestamp));

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Members (${members.length})"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];
                return ListTile(
                  title: Text(member['nickname']),
                  subtitle: Text("Joined: ${DateFormat('MMM d').format((member['joinedAt'] as Timestamp).toDate())}"),
                  trailing: _isSpaceCreator && _authService.getCurrentUser()!.uid != member['id']
                    ? IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                        onPressed: () {
                          Navigator.pop(context);
                          _confirmRemoveUser(member['id'], member['nickname']);
                        },
                      )
                    : null,
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Close"),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return; // Check if the widget is still mounted
      _showErrorToast("Failed to load members: ${e.toString()}");
    }
  }

  // Show About Space dialog with more details
  void _showAboutSpace() async {
    try {
      final spaceInfo = await _chatService.getSpaceInfo(widget.chatID);
      if (!mounted) return; // Check if the widget is still mounted

      if (spaceInfo.containsKey('error')) {
        _showErrorToast(spaceInfo['error']);
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("About ${widget.chatName}"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Description: ${spaceInfo['description']}"),
              const SizedBox(height: 8),
              Text("Created by: ${spaceInfo['creatorNickname']}"),
              if (spaceInfo['createdAt'] != null)
                Text("Created on: ${DateFormat('MMM d, yyyy').format(spaceInfo['createdAt'].toDate())}"),
              const SizedBox(height: 16),
              Text("Members: ${spaceInfo['memberCount'] ?? 'Unknown'}")
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Close"),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return; // Check if the widget is still mounted
      _showErrorToast("Error loading space details: ${e.toString()}");
    }
  }

  Future<void> _confirmDeleteSpace() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Space"),
        content: Text("Deleting space:\n${widget.chatName}\nAre you sure? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close the dialog
            },
            child: const Text("Cancel"),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () async {
              Navigator.pop(context); // Close the dialog
              await _deleteSpace();
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSpace() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Use the ChatService method to delete the space
      await _chatService.deleteSpace(widget.chatID);

      if (!mounted) return; // Check if the widget is still mounted
      setState(() {
        _isLoading = false;
      });

      // Navigate back to the home page
      Navigator.pop(context);

      _showSuccessToast("Space deleted successfully");
    } catch (e) {
      if (!mounted) return; // Check if the widget is still mounted
      setState(() {
        _isLoading = false;
      });
      _showErrorToast("Error deleting space: ${e.toString()}");
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  String _formatMessageDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return "Today";
    } else if (messageDate == yesterday) {
      return "Yesterday";
    } else {
      return DateFormat('MMMM d, yyyy').format(date);
    }
  }

  Widget _buildSystemMessage(String message, String time) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.grey[800],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            time,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.chatName),
            _buildTimeRemaining(),
          ],
        ),
        backgroundColor: Provider.of<ThemeProvider>(context).accentColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (widget.isSpace)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == "about") {
                  _showAboutSpace();
                } else if (value == "members") {
                  _showMembersList();
                } else if (value == "delete") {
                  _confirmDeleteSpace();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: "about",
                  child: Text("About Space"),
                ),
                const PopupMenuItem(
                  value: "members",
                  child: Text("View Members"),
                ),
                if (_isSpaceCreator)
                  const PopupMenuItem(
                    value: "delete",
                    child: Text("Delete Space", style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : _isExpired
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timer_off, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          const Text(
                            "This space has expired",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("Go Back"),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: _buildMessageList(),
                        ),
                        _buildUserInput(),
                      ],
                    ),
    );
  }

  Widget _buildMessageList() {
  return StreamBuilder(
    stream: _chatService.getMessages(widget.chatID, isSpace: widget.isSpace),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(child: Text("Error: ${snapshot.error}"));
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      final messages = snapshot.data!.docs;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients &&
            messages.length > _previousMessageCount) {
          scrollDown();
        }
        _previousMessageCount = messages.length;
      });

      if (messages.isEmpty) {
        return const Center(
          child: Text(
            "No messages yet. Start the conversation!",
            style: TextStyle(color: Colors.grey),
          ),
        );
      }

      return ListView.builder(
        controller: _scrollController,
        itemCount: messages.length,
        itemBuilder: (context, index) {
          return _buildMessageItem(
            messages[index],
            key: ValueKey(messages[index].id),
            index: index,
            messages: messages,
            context: context,
          );
        },
      );
    },
  );
}

  Widget _buildMessageItem(
  DocumentSnapshot doc, {
  required Key key,
  required int index,
  required List<DocumentSnapshot> messages,
  required BuildContext context,
}) {
  final data = doc.data() as Map<String, dynamic>;
  final isCurrentUser = data['senderID'] == _authService.getCurrentUser()!.uid;
  final isSystemMessage = data['isSystemMessage'] == true;
  final timestamp = data['timestamp'] as Timestamp;
  final dateTime = timestamp.toDate();
  final formattedTime = DateFormat('HH:mm').format(dateTime);

  String decryptedMessage;
  try {
    decryptedMessage = crypto.decrypt(data['message']);
  } catch (_) {
    decryptedMessage = "[Unable to decrypt message]";
  }

  final showDateSeparator = index == 0 ||
      !_isSameDay(messages[index - 1]['timestamp'].toDate(), dateTime);

  final isFirstInGroup = index == 0 ||
      messages[index - 1]['senderID'] != data['senderID'] ||
      showDateSeparator;

  return KeyedSubtree(
    key: key,
    child: Column(
      children: [
        if (showDateSeparator)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _formatMessageDate(dateTime),
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ),
            ),
          ),
        GestureDetector(
          onLongPress: () {
            if (!isCurrentUser && !isSystemMessage && widget.isSpace) {
              _showUserOptions(context, data['senderID'], data['senderNickname']);
            }
          },
          child: Container(
            margin: EdgeInsets.only(
              top: isFirstInGroup ? 12.0 : 1.0,
              bottom: 2.0,
              left: 8,
              right: 8,
            ),
            child: isSystemMessage
                ? _buildSystemMessage(decryptedMessage, formattedTime)
                : ChatBubble(
                    name: data['senderNickname'] ?? 'Unknown',
                    message: decryptedMessage,
                    isCurrentUser: isCurrentUser,
                    isFirstMessage: isFirstInGroup,
                    time: formattedTime,
                  ),
          ),
        ),
      ],
    ),
  );
}


  Widget _buildUserInput() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 0, right: 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: MyTextField(
              edgePadding: 10.0,
              hintText: "Type a message",
              obscureText: false,
              controller: _messageController,
              textInputAction: TextInputAction.newline,
              isMultiline: true,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Provider.of<ThemeProvider>(context).accentColor,
              borderRadius: BorderRadius.circular(5),
            ),
            margin: const EdgeInsets.only(right: 10, left: 0),
            child: IconButton(
              onPressed: _isSending ? null : sendMessage,
              icon: _isSending
                  ? const SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      size: 32,
                      Icons.send,
                      color: Colors.white,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ... (keep remaining helper methods like _isSameDay, _formatMessageDate, etc.)

  // Toast helpers
  void _showSuccessToast(String message) {
    Fluttertoast.showToast(msg: message, backgroundColor: Colors.green);
  }

  void _showErrorToast(String message) {
    Fluttertoast.showToast(msg: message, backgroundColor: Colors.red);
  }

  void _showInfoToast(String message) {
    Fluttertoast.showToast(msg: message, backgroundColor: Colors.blue);
  }
}