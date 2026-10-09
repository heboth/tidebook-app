import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/gonordic_theme.dart';

class GoNordicAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBadge;
  final List<Widget>? actions;

  const GoNordicAppBar({
    super.key,
    this.title = '',
    this.showBadge = true,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: GoNordicTheme.pineDark,
      elevation: 0,
      titleSpacing: 16,
      title: Row(
        children: [
          // Logo or Brand typography
          SizedBox(
            height: 24,
            child: SvgPicture.asset(
              'assets/gonordic/logo-wide.svg',
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              placeholderBuilder: (ctx) => const Text(
                'GO NORDIC',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (showBadge)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: GoNordicTheme.lime,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'PASSAGER',
                style: TextStyle(
                  color: GoNordicTheme.pineDark,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
      actions: actions,
    );
  }
}
