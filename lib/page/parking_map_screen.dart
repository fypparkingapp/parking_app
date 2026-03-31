import 'package:flutter/material.dart';
import 'package:parking_app/page/appmain.dart';

class ParkingMapScreen extends StatelessWidget {
  const ParkingMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeScreen(
      hideParkingMarkers: false,
      showBackButton: true,
      showBottomFunctionBar: false,
    );
  }
}
