import 'package:flutter/material.dart';

/// OMNIX product identity — shared colors, copy, and motion.
abstract final class OmnixBrand {
  static const name = 'OMNIX';
  static const tagline = 'Integrated tools. One workspace.';
  static const workspaceLabel = 'Personal workspace';
  static const versionLabel = 'Suite';

  // Core palette — calm enterprise slate + indigo accent
  static const primary = Color(0xFF4F46E5);
  static const primaryDark = Color(0xFF6366F1);
  static const navy = Color(0xFF0F172A);
  static const slate = Color(0xFF1E293B);
  static const mist = Color(0xFFF1F5F9);

  static const toolCopy = [
    ('Media capture', 'Pinterest and YouTube to your gallery'),
    ('Image optimization', 'Compress to an exact file size'),
    ('QR intelligence', 'Camera, gallery, or clipboard'),
    ('Document studio', 'Merge, split, and receipt PDFs'),
    ('Scan to PDF', 'Multi-page export from photos'),
  ];
}
