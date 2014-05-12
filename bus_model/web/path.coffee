
EARTH_RADIUS = 6378 # km

class exports.Path
    constructor: (points) ->
        lons = (p[0] for p in points)
        lats = (p[1] for p in points)
        minLon = 0#Math.min.apply null, lons
        minLat = 0#Math.min.apply null, lats

        lonScale = EARTH_RADIUS*2*Math.PI/360*Math.cos(minLat*Math.PI/180)
        latScale = EARTH_RADIUS*2*Math.PI/360

        @points = ([(lons[i] - minLon)*lonScale,
                    (lats[i] - minLat)*latScale] for i in [0...points.length])

    speeds: (times) ->
        for i in [0...times.length-1]
            [x0, y0] = @points[i]
            [x1, y1] = @points[i+1]
            dist = Math.sqrt((x1-x0)**2 + (y1-y0)**2)

            dt = (times[i+1] - times[i])/(60*60) # in hours
            dist/dt



