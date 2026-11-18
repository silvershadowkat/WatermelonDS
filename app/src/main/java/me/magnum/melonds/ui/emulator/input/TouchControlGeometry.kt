package me.magnum.melonds.ui.emulator.input

import kotlin.math.abs
import kotlin.math.min

/** Normalized, size-independent hit regions; bits are top/right/bottom/left. */
object TouchControlGeometry {
    const val TOP = 1
    const val RIGHT = 2
    const val BOTTOM = 4
    const val LEFT = 8

    fun dpad(x: Float, y: Float, width: Float, height: Float): Int {
        if (!x.isFinite() || !y.isFinite() || width <= 0f || height <= 0f) return 0
        val size = min(width, height)
        val dx = x - width / 2f
        val dy = y - height / 2f
        // The preferred pad's 16% neutral zone, measured on its 84% active
        // face. Eight-way sectors add platformer diagonals to the menu feel.
        val dead = size * .84f * .16f
        if (abs(dx) < dead && abs(dy) < dead) return 0
        val major = maxOf(abs(dx), abs(dy))
        val diagonalBoundary = major * .41421356f // tan(22.5 degrees)
        var mask = 0
        if (abs(dx) >= diagonalBoundary) mask = mask or if (dx < 0f) LEFT else RIGHT
        if (abs(dy) >= diagonalBoundary) mask = mask or if (dy < 0f) TOP else BOTTOM
        return mask
    }

    fun buttons(x: Float, y: Float, width: Float, height: Float): Int {
        if (!x.isFinite() || !y.isFinite() || width <= 0f || height <= 0f) return 0
        val nx = x / width - .5f
        val ny = y / height - .5f
        // Overlapping lobes leave deliberate two-button zones between the
        // visible buttons, so a thumb can roll from run into run+jump.
        val offset = 292f / 512f
        val radiusSquared = .25f
        var mask = 0
        if (nx * nx + (ny + offset) * (ny + offset) <= radiusSquared) mask = mask or TOP
        if ((nx - offset) * (nx - offset) + ny * ny <= radiusSquared) mask = mask or RIGHT
        if (nx * nx + (ny - offset) * (ny - offset) <= radiusSquared) mask = mask or BOTTOM
        if ((nx + offset) * (nx + offset) + ny * ny <= radiusSquared) mask = mask or LEFT
        return mask
    }
}
