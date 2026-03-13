import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

/*
颜色使用规范：
1. 全局背景色：surfaceContainerLowest
2. 边框都用outlineVariant颜色
3. 一般的块状都使用surfaceContainerLow 颜色（比背景深一点）
4. 需要突出的选中状态的高亮色都用primary颜色，比如按钮、tab、菜单等
*/

ThemeData defaultTheme(String theme) {
  final baseTextTheme = theme == "dark" ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
  final textTheme = GoogleFonts.notoSansScTextTheme(baseTextTheme);
  final primaryTextTheme = GoogleFonts.notoSansScTextTheme(baseTextTheme);

  return ThemeData(
    useMaterial3: true,
    fontFamily: GoogleFonts.notoSansSc().fontFamily,
    colorScheme: theme == "dark" ? MaterialTheme.darkScheme() : MaterialTheme.lightScheme(),
    dividerColor: theme == "dark" ? MaterialTheme.darkScheme().outlineVariant : const Color(0xffD3D9DF),
    iconTheme: IconThemeData(
      color: theme == "dark" ? MaterialTheme.darkScheme().onSurface : MaterialTheme.lightScheme().onSurface,
    ),
    textTheme: textTheme,
    primaryTextTheme: primaryTextTheme,
  );
}

class MaterialTheme {
  final TextTheme textTheme;

  const MaterialTheme(this.textTheme);

  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xff35618e),
      surfaceTint: Color(0xff35618e),
      onPrimary: Color(0xffffffff),
      primaryContainer: Color(0xffd1e4ff),
      onPrimaryContainer: Color(0xff184974),
      secondary: Color(0xff535f70),
      onSecondary: Color(0xffffffff),
      secondaryContainer: Color(0xffd6e4f7),
      onSecondaryContainer: Color(0xff3b4858),
      tertiary: Color(0xff6a5778),
      onTertiary: Color(0xffffffff),
      tertiaryContainer: Color(0xfff2daff),
      onTertiaryContainer: Color(0xff524060),
      error: Color(0xffba1a1a),
      onError: Color(0xffffffff),
      errorContainer: Color(0xffffdad6),
      onErrorContainer: Color(0xff93000a),
      surface: Color(0xfff8f9ff),
      onSurface: Color(0xff191c20),
      onSurfaceVariant: Color.fromARGB(255, 74, 78, 83),
      outline: Color(0xff73777f),
      outlineVariant: Color(0xffe1e2e8),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xff2e3135),
      inversePrimary: Color(0xff9fcafd),
      primaryFixed: Color(0xffd1e4ff),
      onPrimaryFixed: Color(0xff001d35),
      primaryFixedDim: Color(0xff9fcafd),
      onPrimaryFixedVariant: Color(0xff184974),
      secondaryFixed: Color(0xffd6e4f7),
      onSecondaryFixed: Color(0xff0f1c2b),
      secondaryFixedDim: Color(0xffbac8db),
      onSecondaryFixedVariant: Color(0xff3b4858),
      tertiaryFixed: Color(0xfff2daff),
      onTertiaryFixed: Color(0xff251432),
      tertiaryFixedDim: Color(0xffd6bee5),
      onTertiaryFixedVariant: Color(0xff524060),
      surfaceDim: Color(0xffd8dae0),
      surfaceBright: Color(0xfff8f9ff),
      surfaceContainerLowest: Color(0xffffffff),
      surfaceContainerLow: Color(0xffF6F8FA),
      surfaceContainer: Color(0xffECEEF0),
      surfaceContainerHigh: Color(0xffe6e8ee),
      surfaceContainerHighest: Color(0xffe1e2e8),
    );
  }

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xff56a0d6),
      surfaceTint: Color(0xff56a0d6),
      onPrimary: Color(0xff0b2233),
      primaryContainer: Color(0xff15354a),
      onPrimaryContainer: Color(0xffb3cfe4),
      secondary: Color(0xffa6b1be),
      onSecondary: Color(0xff1c2732),
      secondaryContainer: Color(0xff2a3540),
      onSecondaryContainer: Color(0xffb7c2ce),
      tertiary: Color(0xffb8a9c8),
      onTertiary: Color(0xff2f243a),
      tertiaryContainer: Color(0xff43364e),
      onTertiaryContainer: Color(0xffc7b9d5),
      error: Color(0xffffb4ab),
      onError: Color(0xff690005),
      errorContainer: Color(0xff93000a),
      onErrorContainer: Color(0xffffdad6),
      surface: Color(0xff20232a),
      onSurface: Color(0xffb2b6bc),
      onSurfaceVariant: Color(0xff878e98),
      outline: Color(0xff4b535e),
      outlineVariant: Color(0xff3a414b),
      shadow: Color(0xff000000),
      scrim: Color(0xff000000),
      inverseSurface: Color(0xffe1e2e8),
      inversePrimary: Color(0xff285f84),
      primaryFixed: Color(0xffd1e4ff),
      onPrimaryFixed: Color(0xff001d35),
      primaryFixedDim: Color(0xff9fcafd),
      onPrimaryFixedVariant: Color(0xff184974),
      secondaryFixed: Color(0xffd6e4f7),
      onSecondaryFixed: Color(0xff0f1c2b),
      secondaryFixedDim: Color(0xffbac8db),
      onSecondaryFixedVariant: Color(0xff3b4858),
      tertiaryFixed: Color(0xfff2daff),
      onTertiaryFixed: Color(0xff251432),
      tertiaryFixedDim: Color(0xffd6bee5),
      onTertiaryFixedVariant: Color(0xff524060),
      surfaceDim: Color(0xff1b1e24),
      surfaceBright: Color(0xff3f4651),
      surfaceContainerLowest: Color(0xff1a1d22),
      surfaceContainerLow: Color(0xff232830),
      surfaceContainer: Color(0xff282d36),
      surfaceContainerHigh: Color(0xff303640),
      surfaceContainerHighest: Color(0xff39414c),
    );
  }

  /// Custom Color 1
  static const customColor1 = ExtendedColor(
    seed: Color(0xff166ea6),
    value: Color(0xff166ea6),
    light: ColorFamily(
      color: Color(0xff2e628c),
      onColor: Color(0xffffffff),
      colorContainer: Color(0xffcde5ff),
      onColorContainer: Color(0xff0b4a72),
    ),
    lightMediumContrast: ColorFamily(
      color: Color(0xff2e628c),
      onColor: Color(0xffffffff),
      colorContainer: Color(0xffcde5ff),
      onColorContainer: Color(0xff0b4a72),
    ),
    lightHighContrast: ColorFamily(
      color: Color(0xff2e628c),
      onColor: Color(0xffffffff),
      colorContainer: Color(0xffcde5ff),
      onColorContainer: Color(0xff0b4a72),
    ),
    dark: ColorFamily(
      color: Color(0xff9acbfa),
      onColor: Color(0xff003352),
      colorContainer: Color(0xff0b4a72),
      onColorContainer: Color(0xffcde5ff),
    ),
    darkMediumContrast: ColorFamily(
      color: Color(0xff9acbfa),
      onColor: Color(0xff003352),
      colorContainer: Color(0xff0b4a72),
      onColorContainer: Color(0xffcde5ff),
    ),
    darkHighContrast: ColorFamily(
      color: Color(0xff9acbfa),
      onColor: Color(0xff003352),
      colorContainer: Color(0xff0b4a72),
      onColorContainer: Color(0xffcde5ff),
    ),
  );

  List<ExtendedColor> get extendedColors => [
    customColor1,
  ];
}

class ExtendedColor {
  final Color seed, value;
  final ColorFamily light;
  final ColorFamily lightHighContrast;
  final ColorFamily lightMediumContrast;
  final ColorFamily dark;
  final ColorFamily darkHighContrast;
  final ColorFamily darkMediumContrast;

  const ExtendedColor({
    required this.seed,
    required this.value,
    required this.light,
    required this.lightHighContrast,
    required this.lightMediumContrast,
    required this.dark,
    required this.darkHighContrast,
    required this.darkMediumContrast,
  });
}

class ColorFamily {
  const ColorFamily({
    required this.color,
    required this.onColor,
    required this.colorContainer,
    required this.onColorContainer,
  });

  final Color color;
  final Color onColor;
  final Color colorContainer;
  final Color onColorContainer;
}
