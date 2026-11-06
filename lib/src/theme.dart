import 'package:flutter/material.dart';

const String kFont = 'Fraunces';
const String kDisplay = kFont;
const List<FontVariation> kReading = <FontVariation>[
  FontVariation('opsz', 32),
];

const Color kInk = Color(0xFF1B1C1E);
const Color kPaper = Color(0xFFB2A4A1);
const Color kNavy = Color(0xFF192532);
const Color kBlue = Color(0xFF253D5B);
const Color kOrange = Color(0xFFEC8B10);
const Color kEmber = Color(0xFFEB4315);
const Color kVerified = Color(0xFF1F8A4C);

const Color kCanvas = kNavy;
const Color kBg = kPaper;
const Color kMint = kBlue;
const Color kGold = kOrange;
const Color kLilac = kEmber;
const Color kMute = kBlue;
const Color kGreen = kOrange;
const Color kLine = kNavy;

const LinearGradient kBlackGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: <Color>[kBlue, kNavy, kInk],
);

const LinearGradient kMintGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: <Color>[kPaper, kPaper, kBlue],
  stops: <double>[0, 0.72, 1],
);

const LinearGradient kGoldGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: <Color>[kPaper, kOrange, kEmber],
);

const BorderRadius kCardRadius = BorderRadius.all(Radius.circular(32));

BoxDecoration blackCardDecoration({BorderRadius radius = kCardRadius}) {
  return BoxDecoration(
    gradient: kBlackGradient,
    borderRadius: radius,
    border: Border.all(color: const Color(0x2EB2A4A1)),
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
  colors: <Color>[kPaper, kPaper, kOrange],
  stops: <double>[0, 0.78, 1],
);

const LinearGradient kLilacGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: <Color>[kPaper, kEmber, kOrange],
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
      Color.lerp(kPaper, color, 0.35)!,
      color,
      Color.lerp(kInk, color, 0.08)!,
    ],
  );
}

ThemeData driftTheme() {
  const TextStyle reading = TextStyle(
    fontFamily: kFont,
    fontVariations: kReading,
    height: 1.35,
    color: kInk,
  );
  const TextStyle display = TextStyle(
    fontFamily: kFont,
    fontVariations: kReading,
    height: 1.15,
    color: kInk,
  );
  final ThemeData base = ThemeData(
    useMaterial3: true,
    fontFamily: kFont,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: kInk,
      onPrimary: kPaper,
      secondary: kMint,
      onSecondary: kPaper,
      tertiary: kGold,
      onTertiary: kInk,
      surface: kBg,
      onSurface: kInk,
      error: kEmber,
      onError: kPaper,
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
  final TextTheme applied = base.textTheme.apply(
    fontFamily: kFont,
    bodyColor: kInk,
    displayColor: kInk,
  );
  return base.copyWith(
    textTheme: applied.copyWith(
      displayLarge: display.copyWith(fontSize: 48),
      displayMedium: display.copyWith(fontSize: 40),
      displaySmall: display.copyWith(fontSize: 32),
      headlineMedium: display.copyWith(fontSize: 28),
      headlineSmall: display.copyWith(fontSize: 24),
      titleLarge: display.copyWith(fontSize: 22, letterSpacing: 0.6),
      bodyLarge: reading.copyWith(fontSize: 16),
      bodyMedium: reading.copyWith(fontSize: 15),
      bodySmall: reading.copyWith(fontSize: 13),
      labelLarge: reading.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
    ),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: kFont),
    appBarTheme: AppBarTheme(
      backgroundColor: kBg,
      foregroundColor: kInk,
      elevation: 0,
      titleTextStyle: display.copyWith(fontSize: 26, letterSpacing: 0.8),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: kInk,
      contentTextStyle: reading.copyWith(color: kPaper, fontSize: 15),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: kBg,
      titleTextStyle: display.copyWith(fontSize: 26),
      contentTextStyle: reading.copyWith(fontSize: 15),
    ),
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: reading.copyWith(fontSize: 14, color: kMute),
      hintStyle: reading.copyWith(color: kMute, fontSize: 15),
    ),
  );
}

class UnverifiedBadge extends StatelessWidget {
  const UnverifiedBadge({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Not confirmed',
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: kEmber,
          borderRadius: BorderRadius.circular(size * 0.32),
        ),
        child: Icon(
          Icons.priority_high_rounded,
          color: kPaper,
          size: size * 0.72,
        ),
      ),
    );
  }
}

class DriftlineMark extends StatelessWidget {
  const DriftlineMark({super.key, this.size = 42, this.showName = true});

  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final Widget logo = ClipOval(
      child: Image.asset(
        'assets/brand/driftline_logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
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
            fontFamily: kDisplay,
            fontVariations: kReading,
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
      ..color = const Color(0x3DB2A4A1);
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
              colors: <Color>[kInk, kNavy, kBlue],
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
