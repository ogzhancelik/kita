import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Responsive wrapper designed mobile-first.
/// On desktop & tablet (Web), it constrains content to a clean mobile viewport width
/// and centers it, offering an app-like experience.
/// On mobile (Android/iOS), it fills the screen naturally.
class ResponsiveLayout extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final bool showFrameOnWeb;

  const ResponsiveLayout({
    super.key,
    required this.child,
    this.maxWidth = 460.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
    this.showFrameOnWeb = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth > maxWidth;

        if (!isWideScreen) {
          return SafeArea(
            child: Padding(
              padding: padding,
              child: child,
            ),
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 20.0),
              decoration: showFrameOnWeb
                  ? BoxDecoration(
                      color: AppColors.getBackground(isDark),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.getBorder(isDark),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    )
                  : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(showFrameOnWeb ? 18 : 0),
                child: SafeArea(
                  child: Padding(
                    padding: padding,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
