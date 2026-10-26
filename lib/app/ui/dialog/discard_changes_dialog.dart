import 'package:flutter/material.dart';

enum DiscardDialogAction {
  discard,
  saveDraft,
  keepEditing,
}

class DiscardChangesDialog extends StatelessWidget {
  const DiscardChangesDialog({super.key});

  static Future<DiscardDialogAction?> show(BuildContext context) {
    return showDialog<DiscardDialogAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const DiscardChangesDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Instagram style dialog styling
    final cardBg = isDark ? const Color(0xFF262626) : Colors.white;
    final dividerColor = isDark
        ? const Color(0xFF363636)
        : Colors.black.withOpacity(0.08);
    final titleColor = isDark ? Colors.white : const Color(0xFF262626);
    final subtitleColor = isDark
        ? const Color(0xFFA8A8A8)
        : const Color(0xFF737373);
    const discardColor = Color(0xFFED4956); // Instagram alert red
    final saveDraftColor = isDark ? const Color(0xFF3897F0) : theme.primaryColor;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 340,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header & Message
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 22),
                child: Column(
                  children: [
                    Text(
                      'Discard changes?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'If you close this window now, you can save your progress as a draft or discard your changes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: subtitleColor,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),

              Divider(height: 1, thickness: 1, color: dividerColor),

              // Option 1: Discard
              _DialogButton(
                title: 'Discard',
                textColor: discardColor,
                isBold: true,
                onTap: () => Navigator.of(context).pop(DiscardDialogAction.discard),
              ),

              Divider(height: 1, thickness: 1, color: dividerColor),

              // Option 2: Save Draft
              _DialogButton(
                title: 'Save Draft',
                textColor: saveDraftColor,
                isBold: true,
                onTap: () =>
                    Navigator.of(context).pop(DiscardDialogAction.saveDraft),
              ),

              Divider(height: 1, thickness: 1, color: dividerColor),

              // Option 3: Keep Editing
              _DialogButton(
                title: 'Keep Editing',
                textColor: titleColor,
                isBold: false,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                onTap: () =>
                    Navigator.of(context).pop(DiscardDialogAction.keepEditing),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatefulWidget {
  final String title;
  final Color textColor;
  final bool isBold;
  final VoidCallback onTap;
  final BorderRadius? borderRadius;

  const _DialogButton({
    required this.title,
    required this.textColor,
    required this.isBold,
    required this.onTap,
    this.borderRadius,
  });

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      onHover: (hovered) => setState(() => _isHovered = hovered),
      borderRadius: widget.borderRadius,
      child: Container(
        height: 48,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _isHovered
              ? widget.textColor.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: widget.borderRadius,
        ),
        child: Text(
          widget.title,
          style: TextStyle(
            color: widget.textColor,
            fontSize: 14,
            fontWeight: widget.isBold ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: -0.1,
          ),
        ),
      ),
    );
  }
}
