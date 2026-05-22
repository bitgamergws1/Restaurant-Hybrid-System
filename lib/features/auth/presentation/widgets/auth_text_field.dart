import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// AuthTextField
/// Branded input field used on all auth screens.
/// Features a glowing orange border on focus and a smooth fill transition.
/// ─────────────────────────────────────────────────────────────────────────────
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.hint,
    this.controller,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.enabled = true,
    this.maxLength,
    this.prefixIcon,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.autofillHints,
  });

  final String label;
  final String hint;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool enabled;
  final int? maxLength;
  final IconData? prefixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final Iterable<String>? autofillHints;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _obscure = false;
  late final FocusNode _focus;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
    _focus = widget.focusNode ?? FocusNode();
    _focus.addListener(() {
      if (mounted) setState(() => _hasFocus = _focus.hasFocus);
    });
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Label ──────────────────────────────────────────────────────────
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: _hasFocus ? AppColors.primary : AppColors.textMuted,
          ),
          child: Text(widget.label.toUpperCase()),
        ),
        const SizedBox(height: 8),

        // ── Field ──────────────────────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: _hasFocus
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 12,
                      spreadRadius: 1,
                    )
                  ]
                : [],
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focus,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            obscureText: _obscure,
            enabled: widget.enabled,
            maxLength: widget.maxLength,
            autofillHints: widget.autofillHints,
            style: GoogleFonts.dmSans(
              fontSize: 15,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w400,
            ),
            validator: widget.validator,
            onChanged: widget.onChanged,
            onFieldSubmitted: widget.onFieldSubmitted,
            cursorColor: AppColors.primary,
            decoration: InputDecoration(
              hintText: widget.hint,
              counterText: '',
              // prefix icon
              prefixIcon: widget.prefixIcon != null
                  ? Icon(
                      widget.prefixIcon,
                      color:
                          _hasFocus ? AppColors.primary : AppColors.textMuted,
                      size: 18,
                    )
                  : null,
              // show/hide toggle for password fields
              suffixIcon: widget.obscureText
                  ? IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textMuted,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
