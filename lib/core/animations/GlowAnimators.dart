part of genz_app;

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  const _GlowOrb({
    required this.color,
    required this.size,
    required this.opacity,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(opacity),
          blurRadius: size * 0.8,
          spreadRadius: size * 0.1,
        ),
      ],
      color: color.withOpacity(opacity * 0.3),
    ),
  );
}
