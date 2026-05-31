import 'package:flutter/material.dart';

enum ProjectStatus { published, unreleased, inProgress }

class Project {
  const Project({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.tags,
    required this.status,
    this.accentColor,
    this.imagePath,
    this.storeUrl,
    this.videoUrl,
  });

  final String id;
  final String title;
  final String subtitle;
  final String description;
  final List<String> tags;
  final ProjectStatus status;
  final Color? accentColor;
  final String? imagePath;
  final String? storeUrl;
  final String? videoUrl;

  bool get isPublished => status == ProjectStatus.published;
}
