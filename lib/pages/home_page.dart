import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echospace/components/my_drawer.dart';
import 'package:echospace/components/user_tile.dart';
import 'package:echospace/components/my_textfield.dart';
import 'package:echospace/pages/chat_page.dart';
import 'package:echospace/services/auth/auth_service.dart';
import 'package:echospace/services/recommendation.dart';
import 'package:provider/provider.dart';
import '../themes/theme_provider.dart';
import 'create_space.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  bool _hasSpace = false;
  DocumentSnapshot? _mySpace;
  List<Map<String, dynamic>> recommendedSpaces = [];
  List<DocumentSnapshot> allSpaces = []; // List to store all spaces
  String message = "Loading recommendations...";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkIfUserHasSpace();
    _fetchRecommendations();
    _fetchAllSpaces(); // Fetch all spaces when the page loads

  }

  // Check if the user has a space
  Future<void> _checkIfUserHasSpace() async {
    final currentUserID = _authService.getCurrentUser()!.uid;
    final userDoc = await FirebaseFirestore.instance.collection("Users").doc(currentUserID).get();

    if (userDoc.exists && userDoc['hasSpace'] == true) {
      final spaceQuery = await FirebaseFirestore.instance
          .collection("Spaces")
          .where("createdBy", isEqualTo: currentUserID)
          .limit(1)
          .get();

      if (spaceQuery.docs.isNotEmpty) {
        setState(() {
          _hasSpace = true;
          _mySpace = spaceQuery.docs.first;
        });
      }
    }
  }

  // Fetch recommendations
  Future<void> _fetchRecommendations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final recommendations = await generateRecommendations(_authService.getCurrentUser()!.uid);
      setState(() {
        recommendedSpaces = recommendations;
        message = "Recommendations loaded successfully.";
      });
    } catch (e) {
      setState(() {
        message = "Error fetching recommendations. Please try again.";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Fetch all spaces (excluding the user's own space)
  Future<void> _fetchAllSpaces() async {
    final currentUserID = _authService.getCurrentUser()!.uid;
    final spacesQuery = await FirebaseFirestore.instance
        .collection("Spaces")
        .where("createdBy", isNotEqualTo: currentUserID) // Exclude user's own space
        .get();

    setState(() {
      allSpaces = spacesQuery.docs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("EchoSpace"),
        backgroundColor: Provider.of<ThemeProvider>(context).accentColor,
        foregroundColor: Colors.white,
      ),
      drawer: const MyDrawer(),
      body: RefreshIndicator(
        onRefresh: _fetchRecommendations,
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: MyTextField(
                edgePadding: 10.0,
                hintText: "Search Spaces",
                obscureText: false,
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) {
                  setState(() {
                    _searchQuery = value; // Update the search query
                  });
                },
              ),
            ),

            // List of Spaces
            Expanded(
              child: _buildSpaceList(),
            ),
          ],
        ),
      ),
      floatingActionButton: _hasSpace
          ? null
          : FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateSpace(),
                  ),
                );
              },
              backgroundColor: Provider.of<ThemeProvider>(context, listen: false).accentColor,
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildSpaceList() {
    // If there's a search query, filter all spaces
    if (_searchQuery.isNotEmpty) {
      final filteredSpaces = allSpaces.where((space) {
        final spaceName = space['name'].toString().toLowerCase();
        return spaceName.contains(_searchQuery.toLowerCase());
      }).toList();

      // Show a message if no spaces match the search query
      if (filteredSpaces.isEmpty) {
        return Center(
          child: Text(
            "No spaces match your search.",
            style: const TextStyle(fontSize: 16.0),
          ),
        );
      }

      return ListView(
        children: [
          // Display the user's own space (if it exists)
          if (_hasSpace && _mySpace != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "Your Space:",
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                UserTile(
                  text: _mySpace!['name'] as String,
                  description: _mySpace!['description'] as String,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatPage(
                          chatID: _mySpace!.id,
                          chatName: _mySpace!['name'] as String,
                          isSpace: true,
                          foulLanguageDetection: _mySpace!['foulLanguageDetection'] as bool,
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 20.0, thickness: 2.0),
              ],
            ),

          // Display filtered spaces
          ...filteredSpaces.map((space) {
            return UserTile(
              text: space['name'] as String,
              description: space['description'] as String,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatPage(
                      chatID: space.id,
                      chatName: space['name'] as String,
                      isSpace: true,
                      foulLanguageDetection: space['foulLanguageDetection'] as bool,
                    ),
                  ),
                );
              },
            );
          }),
        ],
      );
    }

    // If there's no search query, show recommendations
    if (recommendedSpaces.isEmpty) {
      return Center(
        child: Text(
          message,
          style: const TextStyle(fontSize: 16.0),
        ),
      );
    }

    return ListView(
      children: [
        // Display the user's own space (if it exists)
        if (_hasSpace && _mySpace != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Your Space:",
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              UserTile(
                text: _mySpace!['name'] as String,
                description: _mySpace!['description'] as String,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatPage(
                        chatID: _mySpace!.id,
                        chatName: _mySpace!['name'] as String,
                        isSpace: true,
                        foulLanguageDetection: _mySpace!['foulLanguageDetection'] as bool,
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 20.0, thickness: 2.0),
            ],
          ),

        // Display recommended spaces
        ...recommendedSpaces.map((recommendedSpace) {
          final space = recommendedSpace['space'];
          return UserTile(
            text: space['name'] as String,
            description: space['description'] as String,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatPage(
                    chatID: space.id,
                    chatName: space['name'] as String,
                    isSpace: true,
                    foulLanguageDetection: space['foulLanguageDetection'] as bool,
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }
}