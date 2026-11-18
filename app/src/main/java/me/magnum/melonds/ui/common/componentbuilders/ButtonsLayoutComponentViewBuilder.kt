package me.magnum.melonds.ui.common.componentbuilders

import android.content.Context
import android.view.View
import me.magnum.melonds.ui.common.HandheldControlsView
import me.magnum.melonds.ui.common.LayoutComponentViewBuilder

class ButtonsLayoutComponentViewBuilder : LayoutComponentViewBuilder() {
    override fun build(context: Context): View {
        return HandheldControlsView(context, dpad = false)
    }

    override fun getAspectRatio() = 1f
}
