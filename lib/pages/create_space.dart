import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:echospace/components/my_button.dart';
import 'package:echospace/pages/chat_page.dart'; // Use ChatPage instead of SpacePage
import 'package:echospace/services/auth/auth_service.dart';
import 'package:provider/provider.dart';
import '../components/my_textfield.dart';
import '../services/foul_language.dart';
import '../themes/theme_provider.dart';

class CreateSpace extends StatefulWidget {
  const CreateSpace({super.key});

  @override
  State<CreateSpace> createState() => _CreateSpaceState();
}

class _CreateSpaceState extends State<CreateSpace> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  bool _foulLanguageDetection = false;
  int _hours = 0;
  int _minutes = 0;

  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FoulLanguageDetector _foulLanguageDetector = FoulLanguageDetector();

  @override
  void initState() {
    super.initState();
    // Load foul words into the Trie
    _foulLanguageDetector.loadFoulWords(foulWords);
  }

  Future<void> _createSpace() async {
    final String name = _nameController.text.trim();
    final String description = _descController.text.trim();
    final int lifeInMinutes = _hours * 60 + _minutes;

    // Validate inputs
    if (name.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    if (name.length > 63) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Name must be 63 characters or less")),
      );
      return;
    }

    if (description.length > 255) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Description must be 255 characters or less")),
      );
      return;
    }

    if (lifeInMinutes > 1439) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lifetime must be 23 hours 59 minutes or less")),
      );
      return;
    }

    // Check for foul language if enabled
    if (_foulLanguageDetector.hasFoulLanguage(name) ||
        _foulLanguageDetector.hasFoulLanguage(description)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Foul language detected in name or description")),
      );
      return;
    }

    // Create the space in Firestore
    final String currentUserID = _authService.getCurrentUser()!.uid;
    final createdAt = Timestamp.now();
    final expiresAt = Timestamp.fromMillisecondsSinceEpoch(
      createdAt.millisecondsSinceEpoch + lifeInMinutes * 60000, // Convert minutes to milliseconds
    );

    try {
      // Add the space to Firestore
      final spaceRef = await _firestore.collection("Spaces").add({
        'name': name,
        'description': description,
        'foulLanguageDetection': _foulLanguageDetection,
        'createdBy': currentUserID,
        'createdAt': createdAt,
        'expiresAt': expiresAt,
      });

      // Update the user's document to indicate they have a space
      await _firestore.collection("Users").doc(currentUserID).update({
        'hasSpace': true,
      });

      // Navigate to the newly created space using ChatPage
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatPage(
            chatID: spaceRef.id, // Use the auto-generated Firestore document ID
            chatName: name,
            isSpace: true,
            foulLanguageDetection: _foulLanguageDetection,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error creating space: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Space"),
        backgroundColor: Provider.of<ThemeProvider>(context).accentColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Name Input using MyTextField
            MyTextField(
              hintText: "Name (max 63 characters)",
              obscureText: false,
              controller: _nameController,
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 10),

            // Description Input using MyTextField
            MyTextField(
              hintText: "Description (max 255 characters)",
              obscureText: false,
              controller: _descController,
              textInputAction: TextInputAction.newline,
              isMultiline: true, // Enable multiline input
            ),

            // Foul Language Detection Switch
            Padding(
              padding: const EdgeInsets.all(25.0),
              child: Row(
                children: [
                  const Text("Foul Language Detection"),
                  const Spacer(),
                  CupertinoSwitch(
                    value: _foulLanguageDetection,
                    onChanged: (value) {
                      setState(() {
                        _foulLanguageDetection = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Lifetime of Space
            const Text("Lifetime of Space"),
            Padding(
              padding: const EdgeInsets.only(left: 25, right: 25),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButton<int>(
                      value: _hours,
                      items: List.generate(24, (index) => DropdownMenuItem(
                        value: index,
                        child: Text("$index hours"),
                      )),
                      onChanged: (value) {
                        setState(() {
                          _hours = value!;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButton<int>(
                      value: _minutes,
                      items: List.generate(60, (index) => DropdownMenuItem(
                        value: index,
                        child: Text("$index minutes"),
                      )),
                      onChanged: (value) {
                        setState(() {
                          _minutes = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Create Space Button
            MyButton(
              text: "Create Space",
              onTap: _createSpace,
            ),
          ],
        ),
      ),
    );
  }
}