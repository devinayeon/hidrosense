import 'package:flutter/material.dart';
import '../widgets/custom_back_button.dart';

class Header extends StatelessWidget implements PreferredSizeWidget {
  final String titleText;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const Header({
    super.key,
    this.titleText = 'HidroSense',
    this.showBackButton = false,
    this.onBackPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color.fromRGBO(250, 250, 247, 1),
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: showBackButton ? 12 : 16,
      leadingWidth: showBackButton ? 56 : 0,
      leading: showBackButton
          ? Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Center(child: CustomBackButton(onTap: onBackPressed)),
            )
          : null,
      title: Text(
        titleText,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w800,
          fontSize: 20,
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
              icon: const Icon(Icons.person_outline, color: Colors.black),
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
