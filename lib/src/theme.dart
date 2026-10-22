import 'package:flutter/material.dart';

const Color kCanvas = Color(0xFFE4E4E6);
const Color kBg = Color(0xFFF7F7F5);
const Color kInk = Color(0xFF121212);
const Color kMint = Color(0xFFD7EFE6);
const Color kGold = Color(0xFFF3D392);
const Color kLilac = Color(0xFFE8DDF6);
const Color kMute = Color(0xFF8D8D92);
const Color kGreen = Color(0xFF1F9D62);
const Color kLine = Color(0xFFE8E8EA);

const LinearGradient kBlackGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: <Color>[Color(0xFF323236), Color(0xFF17171A), Color(0xFF0C0C0E)],
);

const LinearGradient kMintGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: <Color>[Color(0xFFF7FCFB), Color(0xFFD7EFE6), Color(0xFFC3E3D6)],
);

const LinearGradient kGoldGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: <Color>[Color(0xFFFFF6E4), Color(0xFFF3D392), Color(0xFFE7C27A)],
);

const BorderRadius kCardRadius = BorderRadius.all(Radius.circular(32));

BoxDecoration blackCardDecoration({BorderRadius radius = kCardRadius}) {
  return BoxDecoration(
    gradient: kBlackGradient,
    borderRadius: radius,
    border: Border.all(color: const Color(0x2EFFFFFF)),
    boxShadow: const <BoxShadow>[
      BoxShadow(
        color: Color(0x1A000000),
        blurRadius: 22,
        offset: Offset(0, 12),
      ),
    ],
  );
}

const LinearGradient kAppWash = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: <Color>[Color(0xFFF7F7F5), Color(0xFFE5F6F0), Color(0xFFFFF4E4)],
  stops: <double>[0, 0.55, 1],
);

const LinearGradient kLilacGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: <Color>[Color(0xFFF8F4FC), Color(0xFFE8DDF6), Color(0xFFD8CBED)],
);

LinearGradient gradientFor(Color color) {
  if (color == kInk) {
    return kBlackGradient;
  }
  if (color == kGold) {
    return kGoldGradient;
  }
  if (color == kLilac) {
    return kLilacGradient;
  }
  if (color == kMint) {
    return kMintGradient;
  }
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color.lerp(Colors.white, color, 0.35)!,
      color,
      Color.lerp(kInk, color, 0.08)!,
    ],
  );
}

ThemeData driftTheme() {
  const TextStyle outfit = TextStyle(fontFamily: 'Outfit');
  final ThemeData base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Outfit',
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: kInk,
      onPrimary: Colors.white,
      secondary: kMint,
      onSecondary: kInk,
      tertiary: kGold,
      onTertiary: kInk,
      surface: kBg,
      onSurface: kInk,
      error: Color(0xFFB3261E),
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: kBg,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'Outfit', bodyColor: kInk, displayColor: kInk),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Outfit'),
    appBarTheme: const AppBarTheme(
      backgroundColor: kBg,
      foregroundColor: kInk,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Outfit',
        color: kInk,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: kInk,
      contentTextStyle: TextStyle(fontFamily: 'Outfit', color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: kBg,
      titleTextStyle: TextStyle(
        fontFamily: 'Outfit',
        color: kInk,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: outfit,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      labelStyle: outfit,
      hintStyle: TextStyle(fontFamily: 'Outfit', color: kMute),
    ),
  );
}

class DriftlineMark extends StatelessWidget {
  const DriftlineMark({super.key, this.size = 42, this.showName = true});

  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final Widget logo = Image.asset(
      'assets/brand/driftline_logo.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
    );
    if (!showName) {
      return logo;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        logo,
        const SizedBox(width: 10),
        const Text(
          'DRIFTLINE',
          style: TextStyle(
            fontFamily: 'Outfit',
            color: kInk,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 3.2,
          ),
        ),
      ],
    );
  }
}

/// Black list joined to a navigation pill, matching the template dock.
class DockClipper extends CustomClipper<Path> {
  const DockClipper();

  static Path pathFor(Size size) {
    final double w = size.width;
    final double h = size.height;
    const double top = 32;
    const double neck = 16;
    final double pillTop = h - 86;
    final double pillBottom = h - 2;
    final double pillR = (pillBottom - pillTop) / 2;
    final double left = neck + pillR;
    final double right = w - neck - pillR;
    return Path()
      ..moveTo(top, 0)
      ..lineTo(w - top, 0)
      ..arcToPoint(Offset(w, top), radius: const Radius.circular(top))
      ..lineTo(w, pillTop - 26)
      ..quadraticBezierTo(w - 4, pillTop + 4, right, pillTop)
      ..arcToPoint(
        Offset(right, pillBottom),
        radius: Radius.circular(pillR),
        clockwise: true,
      )
      ..lineTo(left, pillBottom)
      ..arcToPoint(
        Offset(left, pillTop),
        radius: Radius.circular(pillR),
        clockwise: true,
      )
      ..quadraticBezierTo(4, pillTop + 4, 0, pillTop - 26)
      ..lineTo(0, top)
      ..arcToPoint(const Offset(top, 0), radius: const Radius.circular(top))
      ..close();
  }

  @override
  Path getClip(Size size) => pathFor(size);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class DockOutlinePainter extends CustomPainter {
  const DockOutlinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0x3DFFFFFF);
    canvas.drawPath(DockClipper.pathFor(size), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Grey desk on wide windows, and a full-bleed surface on a phone.
class Stage extends StatelessWidget {
  const Stage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        if (!width.isFinite || width <= 500) {
          if (constraints.hasBoundedHeight) {
            return DecoratedBox(
              decoration: const BoxDecoration(gradient: kAppWash),
              child: SizedBox.expand(child: child),
            );
          }
          return DecoratedBox(
            decoration: const BoxDecoration(gradient: kAppWash),
            child: child,
          );
        }

        final double maxHeight = constraints.maxHeight;
        final bool roomy = maxHeight.isFinite && maxHeight > 720;
        final double inset = roomy ? 28 : 0;
        final double frameHeight = maxHeight.isFinite
            ? maxHeight - inset * 2
            : 720;

        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFFE8E8EB),
                Color(0xFFD7EFE6),
                Color(0xFFF3D392),
              ],
              stops: <double>[0, 0.62, 1],
            ),
          ),
          child: Center(
            child: SizedBox(
              width: 430,
              height: frameHeight,
              child: Material(
                color: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: roomy ? 18 : 0,
                shadowColor: const Color(0x2E000000),
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(roomy ? 36 : 0),
                  side: roomy
                      ? const BorderSide(color: kInk, width: 3)
                      : BorderSide.none,
                ),
                child: DecoratedBox(
                  decoration: const BoxDecoration(gradient: kAppWash),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
