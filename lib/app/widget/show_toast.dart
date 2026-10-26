import 'package:flutter/material.dart';
import 'package:media_house/app/core/utils/user_message.dart';

class CustomToast {
  static String? _lastMessage;
  static DateTime? _lastShownAt;

  static void show(
    BuildContext context,
    String message, {
    bool isSuccess = true,
    bool isWarning = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    final safeMessage = UserMessage.sanitize(message) ??
        'Unable to complete the request. Please try again.';
    final now = DateTime.now();
    if (_lastMessage == safeMessage &&
        _lastShownAt != null &&
        now.difference(_lastShownAt!) < const Duration(milliseconds: 800)) {
      return;
    }
    _lastMessage = safeMessage;
    _lastShownAt = now;
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        right: 16,
        child: _ToastWidget(
          message: safeMessage,
          isSuccess: isSuccess,
        ),
      ),
    );

    overlay.insert(entry);

    // Remove the toast after the specified duration
    Future.delayed(duration, () {
      entry.remove();
    });
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final bool isSuccess;

  const _ToastWidget({required this.message, required this.isSuccess});

  @override
  __ToastWidgetState createState() => __ToastWidgetState();
}

class __ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: widget.isSuccess ? Colors.green : Colors.red,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(2, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isSuccess ? Icons.check_circle : Icons.error,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                widget.message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
