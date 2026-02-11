import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  final user = FirebaseAuth.instance.currentUser;
  TextEditingController nameController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  XFile? profileImage;
  String profileImageUrl = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        nameController.text = data['name'] ?? '';
        phoneController.text = data['phone'] ?? '';
        setState(() {
          profileImageUrl = data['profileImage'] ?? '';
        });
      }
    }
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

  void _updateProfile() async {
    if (user == null) return;

    String imageUrl = profileImageUrl;
    if (profileImage != null) {
      imageUrl = await _uploadToCloudinary(profileImage!);
    }

    await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
      'name': nameController.text.trim(),
      'phone': phoneController.text.trim(),
      'profileImage': imageUrl,
      'email': user!.email ?? '',
    }, SetOptions(merge: true));

    setState(() {
      profileImageUrl = imageUrl;
    });

    Get.snackbar(
      "Success",
      "Profile updated",
      backgroundColor: Colors.green,
      colorText: Colors.white,
    );
  }

  void _pickProfileImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        profileImage = image;
      });
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Get.offAllNamed('/login'); // assuming you have a login route
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: profileImage != null
                      ? FileImage(File(profileImage!.path))
                      : (profileImageUrl.isNotEmpty
                                ? NetworkImage(profileImageUrl)
                                : null)
                            as ImageProvider<Object>?,
                  child: profileImageUrl.isEmpty && profileImage == null
                      ? const Icon(Icons.person, size: 60, color: Colors.white)
                      : null,
                  backgroundColor: Colors.redAccent,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    onTap: _pickProfileImage,
                    child: const CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.redAccent,
                      child: Icon(Icons.edit, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Full Name",
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: "Phone Number",
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                labelText: "Email",
                prefixIcon: const Icon(Icons.email),
                border: const OutlineInputBorder(),
              ),
              readOnly: true,
              controller: TextEditingController(text: user?.email ?? ''),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _updateProfile,
              icon: const Icon(Icons.save),
              label: const Text("Update Profile"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text("Logout"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
