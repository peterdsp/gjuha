package com.gjuha.app

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

/**
 * The Gjuha palette, taken from the values `Scripts/gen_colors.py` generates for
 * iOS so the two apps cannot drift to different reds.
 *
 * The same role split applies: a `Fill` carries [OnAccent] or [OnWarning], and a
 * `Strong` is for text or an icon drawn on a surface. Gold as text on a white
 * surface measures 1.76:1, which is why [XpStrong] exists at all.
 */
object GjuhaColors {
    // Generated from Gjuha/Resources/Palette.xcassets by
    // Scripts/sync_android_colors.py. Do not hand edit.
    //
    // Colour has one source, the iOS catalog, because that is where the
    // contrast of every rendered pair is measured. These were previously typed
    // in by hand, which is a second source waiting to drift with nothing to
    // report it.
    //
    // The role split carries over: a fill carries OnAccent or OnWarning, and a
    // *Strong member is for text or an icon drawn on a surface. Gold as text on
    // a white surface measures 1.76:1, which is why XPStrong exists at all.

    val Accent = Color(0xFFB4211A)
    val AccentDark = Color(0xFFBA261E)
    val AccentStrong = Color(0xFF9D1712)
    val AccentStrongDark = Color(0xFFFF7A6E)
    val Streak = Color(0xFFBE4E0F)
    val StreakDark = Color(0xFFBE4E0F)
    val StreakStrong = Color(0xFFA54706)
    val StreakStrongDark = Color(0xFFFFA253)
    val Xp = Color(0xFFFAB01A)
    val XpDark = Color(0xFFFFC02D)
    val XpStrong = Color(0xFF8C5D00)
    val XpStrongDark = Color(0xFFFFD066)
    val Success = Color(0xFF127048)
    val SuccessDark = Color(0xFF127048)
    val SuccessStrong = Color(0xFF0D6640)
    val SuccessStrongDark = Color(0xFF66D794)
    val Error = Color(0xFFD63A21)
    val ErrorDark = Color(0xFFD63A21)
    val Background = Color(0xFFF7F5F1)
    val BackgroundDark = Color(0xFF0F0E0D)
    val Surface = Color(0xFFFFFEFC)
    val SurfaceDark = Color(0xFF1C1A18)
    val TextPrimary = Color(0xFF171513)
    val TextPrimaryDark = Color(0xFFF5F3F0)
    val TextSecondary = Color(0xFF635F5A)
    val TextSecondaryDark = Color(0xFF98948F)
    val OnAccent = Color(0xFFFFFFFF)
    val OnAccentDark = Color(0xFFFFFFFF)
    val OnWarning = Color(0xFF171513)
    val OnWarningDark = Color(0xFF171513)
}

private val LightScheme = lightColorScheme(
    primary = GjuhaColors.Accent,
    onPrimary = GjuhaColors.OnAccent,
    background = GjuhaColors.Background,
    onBackground = GjuhaColors.TextPrimary,
    surface = GjuhaColors.Surface,
    onSurface = GjuhaColors.TextPrimary,
    onSurfaceVariant = GjuhaColors.TextSecondary,
    error = GjuhaColors.Error,
)

private val DarkScheme = darkColorScheme(
    primary = GjuhaColors.AccentDark,
    onPrimary = GjuhaColors.OnAccent,
    background = GjuhaColors.BackgroundDark,
    onBackground = GjuhaColors.TextPrimaryDark,
    surface = GjuhaColors.SurfaceDark,
    onSurface = GjuhaColors.TextPrimaryDark,
    onSurfaceVariant = GjuhaColors.TextSecondaryDark,
    error = GjuhaColors.Error,
)

/** Accent as text or an icon, which differs by appearance. */
@Composable
fun accentStrong(): Color =
    if (isSystemInDarkTheme()) GjuhaColors.AccentStrongDark else GjuhaColors.AccentStrong

@Composable
fun streakStrong(): Color =
    if (isSystemInDarkTheme()) GjuhaColors.StreakStrongDark else GjuhaColors.StreakStrong

@Composable
fun xpStrong(): Color =
    if (isSystemInDarkTheme()) GjuhaColors.XpStrongDark else GjuhaColors.XpStrong

@Composable
fun successStrong(): Color =
    if (isSystemInDarkTheme()) GjuhaColors.SuccessStrongDark else GjuhaColors.SuccessStrong

@Composable
fun GjuhaTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = if (isSystemInDarkTheme()) DarkScheme else LightScheme,
        content = content,
    )
}

/**
 * The type scale, matching iOS.
 *
 * The art direction is the alphabet: the marks Albanian adds to the Latin one
 * and the nine digraphs that are single letters. So display type is set large
 * enough for an e with a diaeresis to be a shape rather than a speck, and
 * tracking is pulled in on the big sizes only. Body text keeps its natural
 * tracking, because an Albanian word carrying two diacritics needs the room
 * and tightening it costs legibility for nothing.
 */
object GjuhaType {
    val displayHero = TextStyle(
        fontSize = 56.sp,
        lineHeight = 60.sp,
        fontWeight = FontWeight.Black,
        letterSpacing = (-1.5).sp,
    )
    val displayLarge = TextStyle(
        fontSize = 44.sp,
        lineHeight = 48.sp,
        fontWeight = FontWeight.Black,
        letterSpacing = (-1.2).sp,
    )
    val prompt = TextStyle(
        fontSize = 28.sp,
        lineHeight = 32.sp,
        fontWeight = FontWeight.SemiBold,
        letterSpacing = (-0.6).sp,
    )

    /** A vocabulary entry: the taught language, not its gloss. */
    val word = TextStyle(
        fontSize = 22.sp,
        lineHeight = 26.sp,
        fontWeight = FontWeight.SemiBold,
        letterSpacing = (-0.4).sp,
    )
}
