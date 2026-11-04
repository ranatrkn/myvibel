package com.myvibel.app

import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.view.LayoutInflater
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory

class GonderiReklamFactory(private val layoutInflater: LayoutInflater) : NativeAdFactory {
    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?,
    ): NativeAdView {
        val adView = layoutInflater.inflate(R.layout.gonderi_reklam, null) as NativeAdView
        val yazi = renk(customOptions, "yazi", Color.WHITE)
        val soluk = renk(customOptions, "soluk", Color.LTGRAY)
        val buton = renk(customOptions, "buton", Color.parseColor("#780000"))

        val headline = adView.findViewById<TextView>(R.id.ad_headline)
        headline.text = nativeAd.headline
        headline.setTextColor(yazi)
        adView.headlineView = headline

        val attribution = adView.findViewById<TextView>(R.id.ad_attribution)
        attribution.setTextColor(soluk)

        val body = adView.findViewById<TextView>(R.id.ad_body)
        body.text = nativeAd.body
        body.setTextColor(yazi)
        body.visibility = if (nativeAd.body.isNullOrEmpty()) TextView.GONE else TextView.VISIBLE
        adView.bodyView = body

        val icon = adView.findViewById<ImageView>(R.id.ad_app_icon)
        val drawable = nativeAd.icon?.drawable
        val yogunluk = icon.resources.displayMetrics.density
        if (drawable != null) {
            icon.setImageDrawable(drawable)
            icon.background = GradientDrawable().apply {
                cornerRadius = 14f * yogunluk
            }
            icon.clipToOutline = true
            icon.visibility = ImageView.VISIBLE
        } else {
            icon.visibility = ImageView.GONE
        }
        adView.iconView = icon

        val media = adView.findViewById<MediaView>(R.id.ad_media)
        media.background = GradientDrawable().apply {
            cornerRadius = 14f * media.resources.displayMetrics.density
        }
        media.clipToOutline = true
        media.visibility = if (nativeAd.mediaContent == null) MediaView.GONE else MediaView.VISIBLE
        adView.mediaView = media

        val cta = adView.findViewById<TextView>(R.id.ad_call_to_action)
        cta.text = nativeAd.callToAction
        cta.setTextColor(Color.WHITE)
        cta.background = GradientDrawable().apply {
            cornerRadius = 22f * cta.resources.displayMetrics.density
            setColor(buton)
        }
        cta.visibility = if (nativeAd.callToAction.isNullOrEmpty()) TextView.GONE else TextView.VISIBLE
        adView.callToActionView = cta

        adView.setNativeAd(nativeAd)
        return adView
    }

    private fun renk(options: MutableMap<String, Any>?, anahtar: String, varsayilan: Int): Int {
        val ham = options?.get(anahtar) ?: return varsayilan
        return when (ham) {
            is Int -> ham
            is Long -> ham.toInt()
            is Double -> ham.toInt()
            else -> varsayilan
        }
    }
}
