import 'package:flutter/material.dart';

class DashboardHeader extends StatelessWidget implements PreferredSizeWidget {
  const DashboardHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color.fromRGBO(250, 250, 247, 1),
      elevation: 0,
      scrolledUnderElevation: 0,
      title: const Text(
        'HidroSense',
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w800, // Extra Bold
          fontSize: 22,
          height: 1.0,
          color: Colors.black,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color.fromRGBO(221, 244, 90, 1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(
                Icons.person_outline, // Outline / Non-filled icon
                color: Colors.black,
              ),
              onPressed: () {
                // Action profile
              },
            ),
          ),
        ),
      ],
    );
  }
}