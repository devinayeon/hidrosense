import 'package:flutter/material.dart';
import '../pages/account_page.dart';
import '../widgets/custom_back_button.dart';

class Header extends StatelessWidget implements PreferredSizeWidget {
  final String titleText;
  final bool showBackButton;
  final bool showUserIcon;
  final VoidCallback? onBackPressed;

  const Header({
    super.key,
    this.titleText = 'HidroSense',
    this.showBackButton = false,
    this.showUserIcon = true,
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
              child: Center(
                child: CustomBackButton(
                  onTap: onBackPressed ?? () => Navigator.maybePop(context),
                ),
              ),
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
        if (showUserIcon)
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: _HeaderAvatarButton(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AccountPage()),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _HeaderAvatarButton extends StatefulWidget {
  final VoidCallback onTap;
  const _HeaderAvatarButton({required this.onTap});

  @override
  State<_HeaderAvatarButton> createState() => _HeaderAvatarButtonState();
}

class _HeaderAvatarButtonState extends State<_HeaderAvatarButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.92 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color.fromRGBO(221, 244, 90, 1),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color.fromRGBO(23, 34, 49, 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.person_outline, color: Colors.black, size: 22),
        ),
      ),
    );
  }
}
