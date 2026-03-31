import 'package:flutter/material.dart';

class MapThemeConfig {
  const MapThemeConfig({
    required this.label,
    required this.urlTemplate,
    required this.subdomains,
    required this.appBarColor,
    required this.appBarForeground,
    required this.accentColor,
    this.backgroundColor = Colors.white,
  });

  final String label;
  final String urlTemplate;
  final List<String> subdomains;
  final Color appBarColor;
  final Color appBarForeground;
  final Color accentColor;
  final Color backgroundColor;
}

