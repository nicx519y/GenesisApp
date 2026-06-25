package com.worldo.ai

import android.app.Application
import com.alibabacloud.rum.AlibabaCloudRum

class GenesisApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        AlibabaCloudRum.withServiceId(AlibabaRumConfig.serviceId)
            .withWorkspace(AlibabaRumConfig.workspace)
            .withEndpoint(AlibabaRumConfig.endpoint)
            .start(applicationContext)
    }
}

private object AlibabaRumConfig {
    const val serviceId = "bui9rvr4ow@ee4a8ef0e23567a0da8a4"
    const val workspace = "default-cms-1203224652491648-us-west-1"
    const val endpoint =
        "https://proj-xtrace-787e287963ab8594ca6655fb346740-us-west-1.us-west-1.log.aliyuncs.com"
}
