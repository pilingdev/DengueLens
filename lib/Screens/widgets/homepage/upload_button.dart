import 'package:flutter/material.dart';

class UploadButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const UploadButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        side: BorderSide(color: Colors.grey[300]!),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      icon: const Icon(
        Icons.photo_library_outlined,
        color: Colors.black87,
        size: 20,
      ),
      label: const Text(
        'Upload from Gallery',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
    );
  }
}
