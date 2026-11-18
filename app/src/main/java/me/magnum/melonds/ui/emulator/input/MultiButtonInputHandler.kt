package me.magnum.melonds.ui.emulator.input

import android.view.MotionEvent
import android.view.View
import me.magnum.melonds.common.vibration.TouchVibrator
import me.magnum.melonds.domain.model.Input
import me.magnum.melonds.ui.common.HandheldControlsView

abstract class MultiButtonInputHandler(inputListener: IInputListener, enableHapticFeedback: Boolean, touchVibrator: TouchVibrator) : FeedbackInputHandler(inputListener, enableHapticFeedback, touchVibrator) {
    protected open val isDirectionPad = false
    private val pressedInputs = mutableListOf<Input>()
    private val newPressedInputs = mutableListOf<Input>()
    // Reusable input list to avoid memory allocations
    private val tempInputList = mutableListOf<Input>()

    override fun onTouch(v: View, event: MotionEvent): Boolean {
        newPressedInputs.clear()
        var mask = 0
        var thumbIndex = -1

        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_MOVE,
            MotionEvent.ACTION_POINTER_DOWN, MotionEvent.ACTION_POINTER_UP -> {
                val releasedPointerIndex = if (event.actionMasked == MotionEvent.ACTION_POINTER_UP) event.actionIndex else -1
                for (pointerIndex in 0 until event.pointerCount) {
                    if (pointerIndex == releasedPointerIndex) continue
                    if (thumbIndex < 0) thumbIndex = pointerIndex
                    val x = event.getX(pointerIndex); val y = event.getY(pointerIndex)
                    mask = mask or if (isDirectionPad)
                        TouchControlGeometry.dpad(x,y,v.width.toFloat(),v.height.toFloat())
                    else TouchControlGeometry.buttons(x,y,v.width.toFloat(),v.height.toFloat())
                }
            }
        }

        if (mask and TouchControlGeometry.TOP != 0) newPressedInputs.add(getTopInput())
        if (mask and TouchControlGeometry.RIGHT != 0) newPressedInputs.add(getRightInput())
        if (mask and TouchControlGeometry.BOTTOM != 0) newPressedInputs.add(getBottomInput())
        if (mask and TouchControlGeometry.LEFT != 0) newPressedInputs.add(getLeftInput())
        (v as? HandheldControlsView)?.updateFeedback(mask,
            if (thumbIndex >= 0) event.getX(thumbIndex) else null,
            if (thumbIndex >= 0) event.getY(thumbIndex) else null)

        tempInputList.clear()
        pressedInputs.filterNotTo(tempInputList) {
            it in newPressedInputs
        }.forEach {
            inputListener.onKeyReleased(it)
        }

        val released = tempInputList.isNotEmpty()

        tempInputList.clear()
        newPressedInputs.filterNotTo(tempInputList) {
            it in pressedInputs
        }.forEach {
            inputListener.onKeyPress(it)
        }

        if (tempInputList.isNotEmpty()) {
            performHapticFeedback(v, HapticFeedbackType.KEY_PRESS)
        } else if (released) {
            performHapticFeedback(v, HapticFeedbackType.KEY_RELEASE)
        }

        pressedInputs.clear()
        pressedInputs.addAll(newPressedInputs)

        return true
    }

    abstract fun getTopInput(): Input
    abstract fun getLeftInput(): Input
    abstract fun getBottomInput(): Input
    abstract fun getRightInput(): Input
}
