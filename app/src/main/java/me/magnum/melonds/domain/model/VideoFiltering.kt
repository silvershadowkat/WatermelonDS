package me.magnum.melonds.domain.model

import androidx.annotation.Keep

@Keep
enum class VideoFiltering {
    NONE,
    LINEAR,
    XBR2,
    HQ2X,
    HQ4X,
    QUILEZ,
    LCD,
    SCANLINES,
    RETROARCH,
    XBR2D50PIXEL,
    XBR2D100PIXEL,
    XBR2D50,
    XBR2D100;

    fun isSupportedByVulkan(): Boolean {
        return true
    }

    fun isSupportedByOpenGlSurface(): Boolean {
        return this != SCANLINES && ordinal < XBR2D50PIXEL.ordinal
    }
}
