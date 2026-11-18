package me.magnum.melonds.ui.common

import android.content.Context
import android.graphics.Camera
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.CornerPathEffect
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Shader
import android.graphics.Typeface
import android.os.SystemClock
import android.view.View
import me.magnum.melonds.ui.emulator.input.TouchControlGeometry
import kotlin.math.abs
import kotlin.math.exp
import kotlin.math.hypot
import kotlin.math.min

/** Original DS-style artwork drawn at display resolution, with thumb-driven tilt. */
class HandheldControlsView(context: Context, private val dpad: Boolean) : View(context) {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val camera = Camera()
    private val matrix = Matrix()
    private val cross = Path().apply {
        moveTo(94f, 18f); lineTo(162f, 18f); lineTo(162f, 94f)
        lineTo(238f, 94f); lineTo(238f, 162f); lineTo(162f, 162f)
        lineTo(162f, 238f); lineTo(94f, 238f); lineTo(94f, 162f)
        lineTo(18f, 162f); lineTo(18f, 94f); lineTo(94f, 94f); close()
    }
    private val face = LinearGradient(0f, 18f, 0f, 238f,
        intArrayOf(Color.rgb(83,85,93), Color.rgb(48,49,55), Color.rgb(33,34,39)),
        floatArrayOf(0f,.5f,1f), Shader.TileMode.CLAMP)
    private val buttonFace = LinearGradient(0f, -32f, 0f, 32f,
        Color.rgb(97,99,109), Color.rgb(35,36,42), Shader.TileMode.CLAMP)
    private var mask = 0
    private var targetX = 0f
    private var targetY = 0f
    private var poseX = 0f
    private var poseY = 0f
    private var touching = false
    private var previousDraw = 0L

    init { importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO }

    fun updateFeedback(pressedMask: Int, thumbX: Float?, thumbY: Float?) {
        mask = pressedMask
        touching = thumbX != null && thumbY != null
        val half = min(width, height).coerceAtLeast(1) * .48f
        targetX = if (touching) ((thumbX!! - width / 2f) / half).coerceIn(-1f, 1f) else 0f
        targetY = if (touching) ((thumbY!! - height / 2f) / half).coerceIn(-1f, 1f) else 0f
        invalidate()
    }

    override fun onWindowVisibilityChanged(visibility: Int) {
        super.onWindowVisibilityChanged(visibility)
        if (visibility != VISIBLE) { mask = 0; touching = false; targetX = 0f; targetY = 0f; poseX = 0f; poseY = 0f }
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val now = SystemClock.uptimeMillis()
        val dt = if (previousDraw == 0L) 16f else (now - previousDraw).coerceIn(1L, 50L).toFloat()
        previousDraw = now
        val blend = 1f - exp(-dt / if (touching) 38f else 115f)
        poseX += (targetX - poseX) * blend; poseY += (targetY - poseY) * blend
        val unit = min(width, height) / 256f
        canvas.save()
        canvas.translate((width - 256f * unit) / 2f, (height - 256f * unit) / 2f)
        canvas.scale(unit, unit)
        if (dpad) drawPad(canvas) else drawButtons(canvas)
        canvas.restore()
        if (abs(targetX - poseX) + abs(targetY - poseY) > .001f) postInvalidateOnAnimation()
    }

    private fun drawPad(canvas: Canvas) {
        val distance = hypot(poseX, poseY).coerceAtMost(1f)
        val response = distance * distance * (3f - 2f * distance)
        val length = hypot(poseX, poseY).coerceAtLeast(.0001f)
        val ux = poseX / length; val uy = poseY / length
        camera.save(); camera.rotateX(-uy * 8.5f * response); camera.rotateY(ux * 8.5f * response)
        camera.getMatrix(matrix); camera.restore()
        matrix.preTranslate(-128f, -128f); matrix.postTranslate(128f,128f)
        canvas.save(); canvas.concat(matrix)
        paint.pathEffect = CornerPathEffect(5f); paint.style = Paint.Style.FILL; paint.shader = null
        paint.color = Color.argb(95,0,0,0)
        canvas.save(); canvas.translate(-ux * 4f * response, 8f - uy * 4f * response); canvas.drawPath(cross,paint); canvas.restore()
        paint.color = Color.rgb(15,16,19)
        canvas.save(); canvas.translate(0f,5f - 3.5f * response); canvas.drawPath(cross,paint); canvas.restore()
        paint.shader = face; canvas.drawPath(cross,paint); paint.shader = null
        paint.style = Paint.Style.STROKE; paint.strokeWidth = 2.2f; paint.color = Color.rgb(111,113,123); canvas.drawPath(cross,paint)
        paint.pathEffect = null; paint.strokeCap = Paint.Cap.ROUND; paint.strokeWidth = 4.5f
        val marks = arrayOf(floatArrayOf(128f,48f,128f,72f),floatArrayOf(184f,128f,208f,128f),
            floatArrayOf(128f,184f,128f,208f),floatArrayOf(48f,128f,72f,128f))
        for (i in marks.indices) {
            val active = mask and (1 shl i) != 0
            paint.color = if (active) Color.rgb(208,0,0) else Color.rgb(210,211,220)
            if (active) {
                paint.strokeWidth = 9f; paint.color = Color.argb(65,208,0,0)
                canvas.drawLine(marks[i][0],marks[i][1],marks[i][2],marks[i][3],paint)
                paint.strokeWidth = 4.5f; paint.color = Color.rgb(238,31,35)
            }
            canvas.drawLine(marks[i][0],marks[i][1],marks[i][2],marks[i][3],paint)
        }
        canvas.restore()
    }

    private fun drawButtons(canvas: Canvas) {
        paint.pathEffect = null; paint.strokeCap = Paint.Cap.ROUND
        val centers = arrayOf(128f to 58f,198f to 128f,128f to 198f,58f to 128f)
        val labels = arrayOf("X","A","B","Y")
        for (i in centers.indices) {
            val pressed = mask and (1 shl i) != 0
            canvas.save(); canvas.translate(centers[i].first,centers[i].second)
            paint.style = Paint.Style.FILL; paint.shader = null; paint.color = Color.argb(105,0,0,0)
            canvas.drawCircle(0f,5f,43f,paint)
            if (pressed) canvas.translate(0f,2f)
            paint.shader = buttonFace; canvas.drawCircle(0f,0f,42f,paint); paint.shader = null
            paint.style = Paint.Style.STROKE; paint.strokeWidth = if (pressed) 3.5f else 1.8f
            paint.color = if (pressed) Color.rgb(238,31,35) else Color.rgb(130,132,144)
            canvas.drawCircle(0f,0f,42f,paint)
            paint.style = Paint.Style.FILL; paint.color = Color.WHITE; paint.textSize = 34f
            paint.textAlign = Paint.Align.CENTER; paint.typeface = Typeface.create(Typeface.SANS_SERIF,Typeface.BOLD)
            canvas.drawText(labels[i],0f,-(paint.ascent()+paint.descent())/2f,paint)
            canvas.restore()
        }
    }
}
