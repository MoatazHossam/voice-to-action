import 'package:flutter/material.dart';

const voiceBlue = Color(0xFF0878D7);
const voiceNavy = Color(0xFF062846);

class VoiceFlowHeader extends StatelessWidget {
  const VoiceFlowHeader({super.key, this.onClose, this.compact = false});

  final VoidCallback? onClose;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 108 : 116,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF278DDC), Color(0xFF0066BC), Color(0xFF064982)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Color(0x30005CAB), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Stack(
        children: [
          Positioned(right: -35, top: -52, child: _Bubble(size: 174)),
          Positioned(left: -28, top: -62, child: _Bubble(size: 168)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('الإضافة الذكية', style: TextStyle(color: Colors.white.withValues(alpha: .55), fontSize: 14, letterSpacing: 1)),
                const SizedBox(height: 6),
                const Text('تسجيل صوتي', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Positioned(
            right: 24,
            top: 32,
            child: Material(
              color: Colors.white.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(19),
              child: InkWell(
                onTap: onClose ?? () => Navigator.maybePop(context),
                borderRadius: BorderRadius.circular(19),
                child: const SizedBox(width: 50, height: 50, child: Icon(Icons.close_rounded, color: Colors.white, size: 27)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .055)),
      );
}

class VoiceGradientBackground extends StatelessWidget {
  const VoiceGradientBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [voiceNavy, Color(0xFF064B83), Color(0xFF0879D7)],
            stops: [0, .48, 1],
          ),
        ),
        child: child,
      );
}
