import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

class CustomInputField extends StatelessWidget {
  final String label;
  final String hintText;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final VoidCallback? onTap;
  final bool readOnly;
  final Widget? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;
  final String? errorText;
  final String? suffixText;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final ValueChanged<String>? onFieldSubmitted;

  const CustomInputField({
    super.key,
    required this.label,
    required this.hintText,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.onTap,
    this.readOnly = false,
    this.suffixIcon,
    this.inputFormatters,
    this.errorText,
    this.suffixText,
    this.textInputAction,
    this.focusNode,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          readOnly: readOnly,
          onTap: onTap,
          focusNode: focusNode,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          style: AppTypography.body,
          decoration: InputDecoration(
            labelText: label,
            hintText: hintText,
            labelStyle: AppTypography.subheadline,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            filled: true,
            fillColor: AppColors.cardSurface,
            suffixIcon: suffixIcon,
            suffixText: suffixText,
            errorText: errorText,
            errorMaxLines: 2,
            errorStyle: AppTypography.footnote.copyWith(
              color: AppColors.dangerRed,
            ),
            enabledBorder: _inputBorder(AppColors.borderLight),
            focusedBorder: _inputBorder(AppColors.primaryMint, width: 1.5),
            errorBorder: _inputBorder(AppColors.dangerRed),
            focusedErrorBorder: _inputBorder(AppColors.dangerRed, width: 1.5),
          ),
        ),
      ],
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: color, width: width),
      );
}
