import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crookwatch/CommentsPage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Crook Reports"),
        backgroundColor: Colors.redAccent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('crime_reports')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading reports"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "🚨 No reports yet.\nBe the first to report!",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
            );
          }

          final currentUser = FirebaseAuth.instance.currentUser;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final title = data['title'] ?? 'Untitled';
              final description = data['description'] ?? '';
              final location = data['location'] ?? '';
              final imageUrl = data['imageUrl'] ?? '';
              final userEmail = data['userEmail'] ?? '';
              final upvotes = (data['upvotes'] ?? 0) as int;
              final downvotes = (data['downvotes'] ?? 0) as int;
              final votes = Map<String, int>.from(data['votes'] ?? {});
              final userVote = votes[currentUser?.uid] ?? 0;

              return Card(
                margin: const EdgeInsets.all(8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (location.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            "📍 $location",
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                      if (userEmail.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            "👤 $userEmail",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(description),
                      if (imageUrl.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Image.network(imageUrl),
                        ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.thumb_up_alt_outlined,
                              color: userVote == 1 ? Colors.green : null,
                            ),
                            onPressed: () => _vote(docs[index].id, true),
                          ),
                          Text(upvotes.toString()),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: Icon(
                              Icons.thumb_down_alt_outlined,
                              color: userVote == -1 ? Colors.red : null,
                            ),
                            onPressed: () => _vote(docs[index].id, false),
                          ),
                          Text(downvotes.toString()),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CommentsPage(
                                    reportId: docs[index].id,
                                    reportTitle: title,
                                  ),
                                ),
                              );
                            },
                            child: const Text("View Comments"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddReportDialog(context),
        backgroundColor: Colors.redAccent,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _vote(String docId, bool isUpvote) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('crime_reports')
        .doc(docId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final currentData = snapshot.data()!;
      final votes = Map<String, int>.from(currentData['votes'] ?? {});
      final uid = user.uid;

      if (votes[uid] == (isUpvote ? 1 : -1)) return;

      int upvotes = (currentData['upvotes'] ?? 0) as int;
      int downvotes = (currentData['downvotes'] ?? 0) as int;

      if (votes.containsKey(uid)) {
        if (votes[uid] == 1) upvotes -= 1;
        if (votes[uid] == -1) downvotes -= 1;
      }

      if (isUpvote)
        upvotes += 1;
      else
        downvotes += 1;

      votes[uid] = isUpvote ? 1 : -1;

      transaction.update(docRef, {
        'upvotes': upvotes,
        'downvotes': downvotes,
        'votes': votes,
      });
    });
  }

  void _openAddReportDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final locationController = TextEditingController();
    XFile? pickedImage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("Report Crime"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: "Title"),
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: "Description"),
                  maxLines: 3,
                ),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(labelText: "Location"),
                ),
                const SizedBox(height: 8),
                if (pickedImage != null)
                  Image.file(File(pickedImage?.path ?? ''), height: 150),
                TextButton.icon(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (image != null) {
                      setState(() {
                        pickedImage = image;
                      });
                    }
                  },
                  icon: const Icon(Icons.image),
                  label: const Text("Add Image (optional)"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("You must be logged in to post."),
                    ),
                  );
                  return;
                }

                String imageUrl = '';
                if (pickedImage != null) {
                  imageUrl = await _uploadToCloudinary(pickedImage!);
                }

                try {
                  await FirebaseFirestore.instance
                      .collection('crime_reports')
                      .add({
                        'title': titleController.text.trim(),
                        'description': descController.text.trim(),
                        'location': locationController.text.trim(),
                        'imageUrl': imageUrl,
                        'timestamp': FieldValue.serverTimestamp(),
                        'userId': user.uid,
                        'userEmail': user.email ?? '',
                        'upvotes': 0,
                        'downvotes': 0,
                        'votes': {},
                      });
                  Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to post report: $e')),
                  );
                }
              },
              child: const Text("Post"),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _uploadToCloudinary(XFile image) async {
    const cloudName = 'dcjlmdsdn';
    const uploadPreset = 'crookwatch';

    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );
    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', image.path));

    final response = await request.send();
    final resString = await response.stream.bytesToString();
    final jsonResp = json.decode(resString);

    if (jsonResp['secure_url'] != null) {
      return jsonResp['secure_url'];
    } else {
      throw Exception('Failed to upload image');
    }
  }
}
