package com.ss.ugc.android.alpha_player.player

import android.content.Context
import android.media.MediaMetadataRetriever
import android.media.MediaPlayer
import android.net.Uri
import android.text.TextUtils
import android.view.Surface
import com.ss.ugc.android.alpha_player.model.VideoInfo
import java.lang.Exception

/**
 * created by dengzhuoyao on 2020/07/07
 */
class DefaultSystemPlayer(private val context: Context) : AbsPlayer(context) {

    lateinit var mediaPlayer : MediaPlayer

    override fun initMediaPlayer() {
        mediaPlayer = MediaPlayer()

        mediaPlayer.setOnCompletionListener(MediaPlayer.OnCompletionListener { mediaPlayer ->
            completionListener?.onCompletion()
        })

        mediaPlayer.setOnPreparedListener(MediaPlayer.OnPreparedListener { mediaPlayer ->
            preparedListener?.onPrepared()
        })

        mediaPlayer.setOnErrorListener(MediaPlayer.OnErrorListener { mp, what, extra ->
            errorListener?.onError(what, extra, "")
            false
        })

        mediaPlayer.setOnInfoListener { mp, what, extra ->
            if (what == MediaPlayer.MEDIA_INFO_VIDEO_RENDERING_START) {
                firstFrameListener?.onFirstFrame()
            }
            false
        }
    }

    override fun setSurface(surface: Surface) {
        mediaPlayer.setSurface(surface)
    }

    override fun setDataSource(dataPath: String) {
        mediaPlayer.setDataSource(context, Uri.parse(dataPath))
    }

    override fun prepareAsync() {
        mediaPlayer.prepareAsync()
    }

    override fun start() {
        mediaPlayer.start()
    }

    override fun pause() {
        mediaPlayer.pause()
    }

    override fun stop() {
        mediaPlayer.stop()
    }

    override fun reset() {
        mediaPlayer.reset()
    }

    override fun release() {
        mediaPlayer.release()
    }

    override fun setLooping(looping: Boolean) {
        mediaPlayer.isLooping = looping
    }

    override fun setScreenOnWhilePlaying(onWhilePlaying: Boolean) {
        mediaPlayer.setScreenOnWhilePlaying(onWhilePlaying)
    }

    override fun getVideoInfo(): VideoInfo {
        return VideoInfo(mediaPlayer.videoWidth, mediaPlayer.videoHeight)
    }

    override fun getPlayerType(): String {
        return "DefaultSystemPlayer"
    }
}