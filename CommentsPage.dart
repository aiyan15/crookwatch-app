import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CommentsPage extends StatelessWidget {
  final String reportId;
  final String reportTitle;

  const CommentsPage({
    super.key,
    required this.reportId,
    required this.reportTitle,
  });

  @override
  Widget build(BuildContext context) {
    final commentController = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text("Comments: $reportTitle"),
        backgroundColor: Colors.redAccent,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('crime_reports')
                  .doc(reportId)
                  .collection('comments')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text("Error loading comments"));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "💬 No comments yet. Be the first!",
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final text = data['text'] ?? '';
                    final email = data['userEmail'] ?? '';
                    final timestamp = (data['timestamp'] as Timestamp?)
                        ?.toDate();

                    return ListTile(
                      title: Text(text),
                      subtitle: Text(
                        "$email • ${timestamp != null ? timestamp.toLocal().toString() : ''}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (user != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: commentController,
                      decoration: const InputDecoration(
                        hintText: "Write a comment...",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                    onPressed: () async {
                      final text = commentController.text.trim();
                      if (text.isEmpty) return;

                      try {
                        await FirebaseFirestore.instance
                            .collection('crime_reports')
                            .doc(reportId)
                            .collection('comments')
                            .add({
                              'text': text,
                              'userId': user.uid,
                              'userEmail': user.email ?? '',
                              'timestamp': FieldValue.serverTimestamp(),
                            });
                        commentController.clear();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to post comment: $e')),
                        );
                      }
                    },
                    child: const Text("Send"),
                  ),
                ],
              ),
            ),
          if (user == null)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                "Log in to comment.",
                style: TextStyle(color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }
}
