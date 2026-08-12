import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    this.label,
    this.controller,
    this.hint,
    this.helperText,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.leadingIcon,
    this.trailing,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.obscureText = false,
    this.maxLines = 1,
    this.autofocus = false,
    this.semanticLabel,
    super.key,
  });

  /// Floating label shown above the field. Optional -- a caller that only
  /// wants placeholder-style guidance (e.g. a chat composer, where a
  /// floating label above every message field would be redundant chrome)
  /// can pass [hint] alone and leave this null.
  final String? label;
  final TextEditingController? controller;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final IconData? leadingIcon;
  final Widget? trailing;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool obscureText;
  final int maxLines;

  /// Requests focus (and opens the keyboard) as soon as this field is
  /// built -- e.g. a quick-ask bottom sheet that should be ready to type
  /// into the instant it opens, without an extra tap. Defaults to false,
  /// matching every existing caller's current behaviour.
  final bool autofocus;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        errorText: errorText,
        prefixIcon: leadingIcon == null ? null : Icon(leadingIcon),
        suffixIcon: trailing,
      ),
    );

    if (semanticLabel == null) {
      return field;
    }

    return Semantics(textField: true, label: semanticLabel, child: field);
  }
}
