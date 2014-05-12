

exports.show = (trips) ->
    fillTripSelect trips, showTrip

margin =
    top: 20
    right: 20
    bottom: 40
    left: 50

showTrip = (trip) ->
    path = new Path trip.path
    truePath = new Path trip.true_path

    showPaths path, truePath
    showSpeeds trip, path

pathCanvas = null
showPaths = (path, truePath) ->
    width = $('#trip-plot-canvas').width() - margin.left - margin.right
    height = $('#trip-plot-canvas').height() - margin.top - margin.bottom

    xScale = d3.scale.linear()
        .range [0, width]
        .domain d3.extent (p[0] for p in path.points.concat truePath.points)
    yScale = d3.scale.linear()
        .range [height, 0]
        .domain d3.extent (p[1] for p in path.points.concat truePath.points)

    if not pathCanvas?
        pathCanvas = d3.select '#trip-plot-canvas'
            .append 'g'
            .attr 'transform', "translate(#{margin.left}, #{margin.right})"

        legend = pathCanvas.append 'g'
            .attr 'transform', "translate(0, #{height})"
        legend.append 'rect'
            .attr 'class', 'scale-indicator'
            .attr 'x', 0
            .attr 'y', 0
            .attr 'width', xScale(1) - xScale(0)
            .attr 'height', 2
        legend.append 'text'
            .attr 'class', 'scale-indicator'
            .attr 'x', 0
            .attr 'y', 0
            .attr 'dy', 12
            .text '1 km'

    line = d3.svg.line()
        .x ([x, y]) -> xScale x
        .y ([x, y]) -> yScale y

    trueSvg = pathCanvas.selectAll '.route-path'
        .data [truePath.points]
    trueSvg.exit().remove()
    trueSvg.enter()
        .append 'path'
        .attr 'class', 'route-path'
    trueSvg.attr 'd', line

    realSvg = pathCanvas.selectAll '.route-path-real-data'
        .data [path.points]
    realSvg.exit().remove()
    realSvg.enter()
        .append 'path'
        .attr 'class', 'route-path-real-data'
    realSvg.attr 'd', line

    circles = pathCanvas.selectAll '.real-data-point'
        .data path.points
    circles.exit().remove()
    circles.enter()
        .append 'circle'
        .attr 'class', 'real-data-point'
        .attr 'r', 3
    circles
        .attr 'cx', ([x, y]) -> xScale x
        .attr 'cy', ([x, y]) -> yScale y

showSpeeds = ({times}, path) ->
    width = $('#trip-plot-speed-canvas').width() - margin.left - margin.right
    height = $('#trip-plot-speed-canvas').height() - margin.top - margin.bottom

    speeds = path.speeds times
    data = ([times[i], speeds[i]] for i in [0...speeds.length])

    xScale = d3.scale.linear()
        .range [0, width]
        .domain d3.extent times
    yScale = d3.scale.linear()
        .range [height, 0]
        .domain [0, d3.max speeds]

    xAxis = d3.svg.axis()
        .scale xScale
        .orient 'bottom'
    yAxis = d3.svg.axis()
        .scale yScale
        .orient 'left'

    speedCanvas = d3.select '#trip-plot-speed-canvas'
    speedCanvas.selectAll('g').remove()

    speedCanvas = speedCanvas
        .append 'g'
        .attr 'transform', "translate(#{margin.left}, #{margin.right})"

    speedCanvas.append 'g'
        .attr 'class', 'x axis'
        .attr 'transform', "translate(0, #{height})"
        .call xAxis
        .append 'text'
            .attr 'y', 24
            .attr 'dy', '0.71em'
            .attr 'x', width/2
            .style 'text-anchor', 'middle'
            .text 'Time [s]'

    speedCanvas.append 'g'
        .attr 'class', 'y axis'
        .call yAxis
        .append 'text'
            .attr 'transform', 'rotate(-90)'
            .attr 'y', -24
            .attr 'dy', '-0.71em'
            .attr 'x', -height/2
            .style 'text-anchor', 'middle'
            .text 'Speed [kph]'

    line = d3.svg.line()
        .x ([x, y]) -> xScale x
        .y ([x, y]) -> yScale y
    
    path = speedCanvas.selectAll '.speed-path'
        .data [data]
    path.exit().remove()
    path.enter()
        .append 'path'
        .attr 'class', 'speed-path'
    path.attr 'd', line

fillTripSelect = (trips, onSelect) ->
    select = $ '#trip-select'
    select.empty()
    for i in [0...trips.length]
        select.append "<option value=\"#{i}\">#{i}</option>"
    select.change -> onSelect trips[+select.val()]
    onSelect trips[0]

EARTH_RADIUS = 6378 # km

class Path
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



