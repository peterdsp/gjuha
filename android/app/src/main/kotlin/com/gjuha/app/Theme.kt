package com.gjuha.app

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

/**
 * The Gjuha palette, taken from the values `Scripts/gen_colors.py` generates for
 * iOS so the two apps cannot drift to different reds.
 *
 * The same role split applies: a `Fill` carries [OnAccent] or [OnWarning], and a
 * `Strong` is for text or an icon drawn on a surface. Gold as text on a white
 * surface measures 1.76:1, which is why [XpStrong] exists at all.
 */
object GjuhaColors {
    // Fills, each measured to carry white at 4.5:1 or better.
    val Accent = Color(0xFFD63129)
    val AccentDark = Color(0xFFD6322B)
    val Streak = Color(0xFFC44905)
    val Success = Color(0xFF16824A)
    val Error = Color(0xFFD12320)

    // On-surface members, for text and icons.
    val AccentStrong = Color(0xFFB8221C)
    val AccentStrongDark = Color(0xFFFF746B)
    val StreakStrong = Color(0xFFAA4300)
    val StreakStrongDark = Color(0xFFFFA654)
    val XpStrong = Color(0xFF926300)
    val XpStrongDark = Color(0xFFFFD666)
    val SuccessStrong = Color(0xFF0E7440)
    val SuccessStrongDark = Color(0xFF66DE99)

    // Surfaces.
    val Background = Color(0xFFF5F4F3)
    val BackgroundDark = Color(0xFF101012)
    val Surface = Color(0xFFFFFFFF)
    val SurfaceDark = Color(0xFF1E1E22)
    val TextPrimary = Color(0xFF1A1A1E)
    val TextPrimaryDark = Color(0xFFF3F3F5)
    val TextSecondary = Color(0xFF66666B)
    val TextSecondaryDark = Color(0xFF94949A)

    val OnAccent = Color(0xFFFFFFFF)
    val OnWarning = Color(0xFF1A1A1E)
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
