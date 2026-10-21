package com.worldo.ai

import android.app.Activity
import com.google.android.play.core.review.ReviewManagerFactory
import io.flutter.plugin.common.MethodChannel

/** Completion means the API flow ended, never that a review was shown/submitted. */
internal object AppReviewChannel {
    private var inFlight = false

    fun request(activity: Activity, result: MethodChannel.Result) {
        if (inFlight) {
            result.error("review_busy", "Review already in progress", null)
            return
        }
        inFlight = true
        fun fail(code: String, message: String?) {
            inFlight = false
            result.error(code, message, null)
        }
        try {
            val manager = ReviewManagerFactory.create(activity)
            manager.requestReviewFlow().addOnCompleteListener { request ->
                if (!request.isSuccessful) {
                    fail("review_request_failed", request.exception?.message)
                } else if (activity.isFinishing || activity.isDestroyed) {
                    fail("review_activity_unavailable", "Activity is unavailable")
                } else {
                    try {
                        manager.launchReviewFlow(activity, request.result).addOnCompleteListener { flow ->
                            if (!flow.isSuccessful) {
                                fail("review_launch_failed", flow.exception?.message)
                            } else {
                                inFlight = false
                                result.success(null)
                            }
                        }
                    } catch (error: Exception) {
                        fail("review_launch_failed", error.message)
                    }
                }
            }
        } catch (error: Exception) {
            fail("review_request_failed", error.message)
        }
    }
}
