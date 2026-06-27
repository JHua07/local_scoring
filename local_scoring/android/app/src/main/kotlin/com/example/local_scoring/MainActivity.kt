package com.example.local_scoring

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode

class MainActivity : FlutterActivity() {
    override fun getRenderMode(): RenderMode {
        // surface 模式比 texture 模式性能更好，无平台视图时推荐使用
        return RenderMode.surface
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 请求高刷新率以适配 90Hz/120Hz 屏幕
        requestHighFrameRate()
    }

    private fun requestHighFrameRate() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            val window = window ?: return
            val layoutParams = window.attributes
            // 获取设备支持的最高刷新率
            val display = windowManager.defaultDisplay
            val supportedModes = display?.supportedModes
            if (supportedModes != null && supportedModes.isNotEmpty()) {
                // 选择最高刷新率的显示模式
                var bestMode = supportedModes[0]
                for (mode in supportedModes) {
                    if (mode.refreshRate > bestMode.refreshRate) {
                        bestMode = mode
                    }
                }
                layoutParams.preferredDisplayModeId = bestMode.modeId
            }
            // Android 11+ 的帧率 API
            layoutParams.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            window.attributes = layoutParams
        }
    }
}
