import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? _imageFile;
  String? name, username, email, phone;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        name = prefs.getString('name') ?? 'Not set';
        username = prefs.getString('username') ?? 'Not set';
        email = prefs.getString('email') ?? 'Not set';
        phone = prefs.getString('phone_number') ?? 'Not set';
      });
    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final status = await Permission.camera.status;
        if (!status.isGranted) {
          final result = await Permission.camera.request();
          if (!result.isGranted) {
            _showPermissionDialog();
            return;
          }
        }
      } else {
        final status = await Permission.photos.status;
        if (!status.isGranted) {
          final result = await Permission.photos.request();
          if (!result.isGranted) {
            _showPermissionDialog();
            return;
          }
        }
      }

      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 800,
      );
      
      if (image != null && mounted) {
        setState(() => _imageFile = File(image.path));
        // Here you would typically upload the image to your server
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'To update your profile picture, please grant access to your '
          'camera or photo library in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Profile'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildProfilePicture(),
                  const SizedBox(height: 32),
                  Expanded(
                    child: ListView(
                      children: [
                        _infoTile('Username', username, Icons.person, 'username'),
                        _infoTile('Full Name', name, Icons.badge, 'name'),
                        _infoTile('Email', email, Icons.email, 'email'),
                        _infoTile('Phone', phone, Icons.phone, 'phone_number'),
                      ],
                    ),
                  ),
                  _buildBackButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfilePicture() {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundImage: _imageFile != null
                ? FileImage(_imageFile!)
                : const AssetImage('assets/default_pfp.png') as ImageProvider,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _showImagePickerOptions,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String? value, IconData icon, String key) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(value ?? 'Not set'),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => _editField(key, label, value),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back to Map'),
        ),
      ),
    );
  }

  Future<void> _editField(String key, String label, String? currentValue) async {
    final controller = TextEditingController(text: currentValue ?? '');
    final prefs = await SharedPreferences.getInstance();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit $label'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter your $label',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$label cannot be empty')),
                );
                return;
              }

              try {
                await prefs.setString(key, controller.text.trim());
                if (mounted) {
                  setState(() {
                    switch (key) {
                      case 'name':
                        name = controller.text.trim();
                        break;
                      case 'username':
                        username = controller.text.trim();
                        break;
                      case 'email':
                        email = controller.text.trim();
                        break;
                      case 'phone_number':
                        phone = controller.text.trim();
                        break;
                    }
                  });
                  Navigator.pop(context);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to save: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}