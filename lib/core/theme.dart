import 'package:flutter/material.dart';

const kNavy = Color(0xFF1B3A5C);
const kGold = Color(0xFFC9A24B);

ThemeData buildTheme(Brightness b, String lang) {
  final dark = b == Brightness.dark;
  final scheme = dark
      ? ColorScheme.fromSeed(seedColor: kNavy, brightness: b).copyWith(
          primary: kGold,
          onPrimary: const Color(0xFF14202F),
          secondary: const Color(0xFF8FB0D6),
          surface: const Color(0xFF0F1722),
          onSurface: const Color(0xFFE6EBF2),
          surfaceContainerHighest: const Color(0xFF1B2838),
          primaryContainer: const Color(0xFF3A3220),
          onPrimaryContainer: kGold,
        )
      : ColorScheme.fromSeed(seedColor: kNavy, brightness: b).copyWith(
          primary: kNavy,
          onPrimary: Colors.white,
          secondary: kGold,
          surface: const Color(0xFFF6F7FA),
          onSurface: const Color(0xFF14202F),
          primaryContainer: const Color(0xFFE3EAF3),
          onPrimaryContainer: kNavy,
        );
  final family = lang == 'ur' ? 'NotoNastaliqUrdu' : 'Inter';
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b);
  var tt = base.textTheme.apply(fontFamily: family, bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  if (lang == 'ur') tt = tt.apply(heightFactor: 1.35);
  return base.copyWith(
    textTheme: tt,
    primaryTextTheme: tt,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF111C2B) : kNavy,
      foregroundColor: dark ? kGold : Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: tt.titleLarge?.copyWith(
          color: dark ? kGold : Colors.white, fontWeight: FontWeight.w600),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? const Color(0xFF111C2B) : Colors.white,
      indicatorColor: dark ? const Color(0xFF3A3220) : const Color(0xFFE3EAF3),
      labelTextStyle: WidgetStatePropertyAll(tt.labelMedium),
    ),
    dividerTheme: DividerThemeData(color: scheme.onSurface.withOpacity(0.08), thickness: 1, space: 1),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: kGold,
      foregroundColor: const Color(0xFF14202F),
      shape: const CircleBorder(),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// Rounded surface used for cards everywhere (avoids Card theme API churn).
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = color ?? (dark ? const Color(0xFF172233) : Colors.white);
    return Material(
      color: bg,
      elevation: dark ? 0 : 1.5,
      shadowColor: Colors.black.withOpacity(0.12),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

InputDecoration dec(BuildContext context, String label, {String? hint, Widget? suffix, Widget? prefix}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.18)),
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffixIcon: suffix,
    prefixIcon: prefix,
    filled: true,
    fillColor: dark ? const Color(0xFF172233) : Colors.white,
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.6),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}
