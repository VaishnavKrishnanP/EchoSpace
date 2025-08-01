import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

// Create a vector from text using a bag-of-words approach
Map<String, int> createVector(String text) {
  final words = text.toLowerCase().split(' ');
  final vector = <String, int>{};

  for (final word in words) {
    vector[word] = (vector[word] ?? 0) + 1;
  }

  return vector;
}

// Compute cosine similarity between two vectors
double cosineSimilarity(Map<String, int> vectorA, Map<String, int> vectorB) {
  // Get all unique words from both vectors
  final allWords = {...vectorA.keys, ...vectorB.keys};

  // Compute dot product
  double dotProduct = 0.0;
  for (final word in allWords) {
    dotProduct += (vectorA[word] ?? 0) * (vectorB[word] ?? 0);
  }

  // Compute magnitudes
  double magnitudeA = 0.0;
  double magnitudeB = 0.0;
  for (final word in allWords) {
    magnitudeA += pow((vectorA[word] ?? 0), 2);
    magnitudeB += pow((vectorB[word] ?? 0), 2);
  }
  magnitudeA = sqrt(magnitudeA);
  magnitudeB = sqrt(magnitudeB);

  // Avoid division by zero
  if (magnitudeA == 0 || magnitudeB == 0) {
    return 0.0;
  }

  return dotProduct / (magnitudeA * magnitudeB);
}

// Fetch recent spaces visited by the user
Future<List<String>> fetchUserRecentSpaces(String userId) async {
  final recentSpaces = await FirebaseFirestore.instance
      .collection('Users')
      .doc(userId)
      .collection('recentSpaces')
      .orderBy('timestamp', descending: true)
      .limit(50)
      .get();

  return recentSpaces.docs.map((doc) => doc['text'] as String).toList();
}

// Generate recommendations for the user
Future<List<Map<String, dynamic>>> generateRecommendations(String userId) async {
  // Fetch the user's recent spaces (concatenated name and description)
  final recentSpaceTexts = await fetchUserRecentSpaces(userId);

  // If no recent spaces, recommend random spaces (excluding the user's own space)
  if (recentSpaceTexts.isEmpty) {
    final allSpaces = await FirebaseFirestore.instance
        .collection('Spaces')
        .where('createdBy', isNotEqualTo: userId)
        .limit(50)
        .get();

    return allSpaces.docs.map((space) {
      return {
        'space': space,
        'similarity': 0.0, // No similarity score for random recommendations
      };
    }).toList();
  }

  // Create vectors for recent spaces
  final recentVectors = recentSpaceTexts.map((text) => createVector(text)).toList();

  // Fetch all spaces (excluding the user's own space)
  final allSpaces = await FirebaseFirestore.instance
      .collection('Spaces')
      .where('createdBy', isNotEqualTo: userId)
      .get();

  // Compute similarity for all spaces
  final recommendations = allSpaces.docs.map((space) {
    final text = space['name'] + " " + space['description'];
    final spaceVector = createVector(text);

    // Compute average similarity with recent spaces
    double totalSimilarity = 0.0;
    for (final recentVector in recentVectors) {
      totalSimilarity += cosineSimilarity(spaceVector, recentVector);
    }
    final averageSimilarity = totalSimilarity / recentVectors.length;

    return {
      'space': space,
      'similarity': averageSimilarity,
    };
  }).toList();

  // Sort by similarity
  recommendations.sort((a, b) {
    final similarityA = a['similarity'] as double; // Explicitly cast to double
    final similarityB = b['similarity'] as double; // Explicitly cast to double
    return similarityB.compareTo(similarityA); // Now compareTo is valid
  });

  // Return top 50 recommendations
  return recommendations.take(50).toList();
}