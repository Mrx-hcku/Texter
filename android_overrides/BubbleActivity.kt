package com.texter.texter

/**
 * Hosts the app inside an Android notification bubble. Same app, same code —
 * it just opens straight into the chat from the bubble's intent.
 */
class BubbleActivity : MainActivity() {
    override fun isBubbleActivity(): Boolean = true
}
