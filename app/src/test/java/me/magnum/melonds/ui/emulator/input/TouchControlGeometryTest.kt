package me.magnum.melonds.ui.emulator.input

import org.junit.Assert.assertEquals
import org.junit.Test

class TouchControlGeometryTest {
    private val g = TouchControlGeometry

    @Test fun dpadHasNeutralCardinalsAndDiagonals() {
        assertEquals(0,g.dpad(128f,128f,256f,256f))
        assertEquals(g.RIGHT,g.dpad(220f,128f,256f,256f))
        assertEquals(g.LEFT,g.dpad(30f,128f,256f,256f))
        assertEquals(g.TOP,g.dpad(128f,30f,256f,256f))
        assertEquals(g.BOTTOM,g.dpad(128f,220f,256f,256f))
        assertEquals(g.TOP or g.RIGHT,g.dpad(220f,30f,256f,256f))
        assertEquals(g.BOTTOM or g.LEFT,g.dpad(30f,220f,256f,256f))
    }

    @Test fun slidingOutsidePadKeepsDirectionAndResizeKeepsGeometry() {
        assertEquals(g.RIGHT,g.dpad(500f,128f,256f,256f))
        assertEquals(g.TOP or g.RIGHT,g.dpad(440f,60f,512f,512f))
        assertEquals(0,g.dpad(Float.NaN,0f,256f,256f))
    }

    @Test fun faceButtonsHaveTwoButtonRollZonesAndMultiFingerUnion() {
        assertEquals(g.RIGHT,g.buttons(210f,128f,256f,256f))
        assertEquals(g.BOTTOM,g.buttons(128f,210f,256f,256f))
        assertEquals(g.RIGHT or g.BOTTOM,g.buttons(170f,170f,256f,256f))
        assertEquals(g.TOP or g.LEFT,g.buttons(86f,86f,256f,256f))
        assertEquals(0,g.buttons(128f,128f,256f,256f))
        val held = g.buttons(210f,128f,256f,256f) or g.buttons(128f,210f,256f,256f)
        assertEquals(g.RIGHT or g.BOTTOM,held)
        // Releasing one pointer leaves the other button held.
        assertEquals(g.BOTTOM,g.buttons(128f,210f,256f,256f))
    }
}
