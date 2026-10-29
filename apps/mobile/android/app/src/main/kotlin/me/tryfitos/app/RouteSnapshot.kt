package me.tryfitos.app

import android.content.Context
import android.graphics.Bitmap
import io.flutter.plugin.common.MethodChannel
import org.maplibre.android.MapLibre
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.maps.Style
import org.maplibre.android.snapshotter.MapSnapshot
import org.maplibre.android.snapshotter.MapSnapshotter
import org.maplibre.android.style.layers.CircleLayer
import org.maplibre.android.style.layers.LineLayer
import org.maplibre.android.style.layers.Property
import org.maplibre.android.style.layers.PropertyFactory
import org.maplibre.android.style.sources.GeoJsonSource
import org.maplibre.geojson.Feature
import org.maplibre.geojson.FeatureCollection
import org.maplibre.geojson.LineString
import org.maplibre.geojson.Point
import java.io.ByteArrayOutputStream

/**
 * Beta 4.1.1 (owner: "the path covered is disappointing on sharing"): the
 * share picture's map, with the route drawn by MapLibre itself.
 *
 * maplibre_gl's takeSnapshot renders the bare style (the route is a layer
 * added at run time, so it was missing) at the map's camera but a different
 * size (so it came out zoomed out). Here the route is part of the style the
 * snapshot is made from, and the snapshot is framed on the route.
 */
object RouteSnapshot {
    // Kept until its callback: a snapshotter that is collected never answers.
    private var active: MapSnapshotter? = null

    @Suppress("UNCHECKED_CAST")
    fun take(context: Context, args: Map<String, Any?>, result: MethodChannel.Result) {
        val style = args["style"] as? String
        val segments = (args["segments"] as? List<List<List<Double>>>)
            ?.map { s -> s.map { LatLng(it[0], it[1]) } }
            ?.filter { it.size >= 2 }
        val size = (args["size"] as? Number)?.toInt() ?: 360
        val ratio = (args["pixelRatio"] as? Number)?.toFloat() ?: 3f
        val colour = args["colour"] as? String ?: "#C6F432"
        val ring = args["ring"] as? String ?: "#0A0D0B"
        if (style == null || segments.isNullOrEmpty()) {
            result.error("bad-route", "No style or no route to draw", null)
            return
        }
        MapLibre.getInstance(context.applicationContext)

        val lines = FeatureCollection.fromFeatures(
            segments.map { s ->
                Feature.fromGeometry(
                    LineString.fromLngLats(s.map { Point.fromLngLat(it.longitude, it.latitude) }),
                )
            },
        )
        val end = segments.last().last()
        val styled = Style.Builder().fromUri(style)
            .withSource(GeoJsonSource("fitos-route", lines))
            .withSource(GeoJsonSource("fitos-end", Point.fromLngLat(end.longitude, end.latitude)))
            .withLayer(
                LineLayer("fitos-route-line", "fitos-route").withProperties(
                    PropertyFactory.lineColor(colour),
                    PropertyFactory.lineWidth(5f),
                    PropertyFactory.lineCap(Property.LINE_CAP_ROUND),
                    PropertyFactory.lineJoin(Property.LINE_JOIN_ROUND),
                ),
            )
            .withLayer(
                CircleLayer("fitos-end-dot", "fitos-end").withProperties(
                    PropertyFactory.circleRadius(7f),
                    PropertyFactory.circleColor(colour),
                    PropertyFactory.circleStrokeColor(ring),
                    PropertyFactory.circleStrokeWidth(2f),
                ),
            )

        val options = MapSnapshotter.Options(size, size)
            .withPixelRatio(ratio)
            .withRegion(framed(segments.flatten()))
            .withStyleBuilder(styled)
            .withLogo(false)

        active?.cancel()
        val snapshotter = MapSnapshotter(context, options)
        active = snapshotter
        snapshotter.start(
            { snapshot: MapSnapshot ->
                active = null
                val out = ByteArrayOutputStream()
                snapshot.bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                result.success(out.toByteArray())
            },
            { error: String ->
                active = null
                result.error("snapshot", error, null)
            },
        )
    }

    /**
     * The route's bounds with a margin, so the line never touches the edge
     * and the stats at the bottom of the card do not cover its end. At least
     * about 300 m across, so a short run is not drawn at street-sign zoom.
     */
    private fun framed(points: List<LatLng>): LatLngBounds {
        var south = points.minOf { it.latitude }
        var north = points.maxOf { it.latitude }
        var west = points.minOf { it.longitude }
        var east = points.maxOf { it.longitude }
        val minSpan = 0.003
        if (north - south < minSpan) {
            val mid = (north + south) / 2
            south = mid - minSpan / 2
            north = mid + minSpan / 2
        }
        if (east - west < minSpan) {
            val mid = (east + west) / 2
            west = mid - minSpan / 2
            east = mid + minSpan / 2
        }
        val lat = north - south
        val lon = east - west
        // More room below: the card's name and figures sit over the bottom.
        return LatLngBounds.Builder()
            .include(LatLng(north + lat * 0.15, west - lon * 0.15))
            .include(LatLng(south - lat * 0.45, east + lon * 0.15))
            .build()
    }
}
