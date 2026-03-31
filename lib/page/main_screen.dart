import 'package:flutter/material.dart';
import 'package:parking_app/page/appmain.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeScreen(
      hideParkingMarkers: true,
      showBackButton: false,
      showBottomFunctionBar: true,
    );
  }
}
