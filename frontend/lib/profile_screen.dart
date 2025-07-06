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

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      name     = prefs.getString('name');
      username = prefs.getString('username');
      email    = prefs.getString('email');
      phone    = prefs.getString('phone_number');
    });
  }

  Future<void> _pickImage(ImageSource source) async {
  if (source == ImageSource.camera) {
    final status = await Permission.camera.status;

    if (status.isDenied) {
      final result = await Permission.camera.request();
      if (!result.isGranted) {
        _showPermissionDialog(); // ← custom alert
        return;
      }
    }

    if (status.isPermanentlyDenied) {
      _showPermissionDialog(); // ← guide to settings
      return;
    }
  }

  try {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, imageQuality: 85);
    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
      });
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error picking image: $e')),
    );
  }
}
void _showPermissionDialog() {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Camera Permission'),
      content: const Text(
        'Camera access is required to take a profile picture.\n\n'
        'Please enable it in Settings → Privacy → Camera.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(ctx);
            await openAppSettings(); // opens app settings
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
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () => _pickImage(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              onTap: () => _pickImage(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Your Profile')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: _imageFile != null
                        ? FileImage(_imageFile!)
                        : const AssetImage('assets/default_pfp.png')
                            as ImageProvider,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _showImagePickerOptions,
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.black54,
                        child: const Icon(Icons.camera_alt, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _infoTile("Username", username, () => _editField('username', 'Username', username)),
              _infoTile("Full Name", name, () => _editField('name', 'Full Name', name)),
              _infoTile("Email", email, () => _editField('email', 'Email', email)),
              _infoTile("Phone", phone, () => _editField('phone_number', 'Phone', phone)),

              const Spacer(),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Map'),
              ),
            ],
          ),
        ),
      );

  Widget _infoTile(String label, String? value, VoidCallback onEdit) => ListTile(
  title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
  subtitle: Text(value ?? "Not set"),
  trailing: IconButton(
    icon: const Icon(Icons.edit, size: 20),
    onPressed: onEdit,
  ),
);
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
        decoration: InputDecoration(hintText: 'Enter your $label'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            prefs.setString(key, controller.text);
            setState(() {
              switch (key) {
                case 'name': name = controller.text; break;
                case 'username': username = controller.text; break;
                case 'email': email = controller.text; break;
                case 'phone_number': phone = controller.text; break;
              }
            });
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
}