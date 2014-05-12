{Path} = require './path.coffee'

margin =
    top: 20
    right: 20
    bottom: 40
    left: 50

gpsStd = 20 # meters

exports.show = ([{true_path}]) ->
    gpsInput = $ '#gps-std'
    gpsInput.val gpsStd
    update = ->
        newVal = +gpsInput.val()
        if not isNaN(newVal) and newVal > 0
            gpsStd = +gpsInput.val()
    gpsInput.change update
    gpsInput.keyup update

    path = new Path true_path

    width = $('#point-model-canvas').width() - margin.left - margin.right
    height = $('#point-model-canvas').height() - margin.top - margin.bottom

    xScale = d3.scale.linear()
        .range [0, width]
        .domain d3.extent (p[0] for p in path.points.concat path.points)
    yScale = d3.scale.linear()
        .range [height, 0]
        .domain d3.extent (p[1] for p in path.points.concat path.points)

    canvas = d3.select '#point-model-canvas'
        .append 'g'
        .attr 'transform', "translate(#{margin.left}, #{margin.right})"

    # catch mouse events
    canvas.append 'rect'
        .attr 'width', width
        .attr 'height', height
        .style 'fill', '#FFFFFF'

    line = d3.svg.line()
        .x ([x, y]) -> xScale x
        .y ([x, y]) -> yScale y

    pathParts = []
    ds = 0.05
    remaining = path.points.slice 0
    current = remaining.shift()
    while remaining.length > 1
        next = remaining[0]
        delta = (next[i] - current[i] for i in [0, 1])
        deltaLength = length = Math.sqrt(delta[0]**2 + delta[1]**2)
        while length < ds and remaining.length > 1
            current = remaining.shift()
            next = remaining[0]
            delta = (next[i] - current[i] for i in [0, 1])
            deltaLength = Math.sqrt(delta[0]**2 + delta[1]**2)
            length += deltaLength
        
        p = (ds - (length - deltaLength))/deltaLength
        current = [current[0]+p*delta[0], current[1]+p*delta[1]]
        pathParts.push current

    pathParts = for i in [0...pathParts.length-1]
        [pathParts[i], pathParts[i+1]]

    paths = canvas.selectAll '.route-path model'
        .data pathParts
    paths.exit().remove()
    paths.enter()
        .append 'path'
        .attr 'class', 'route-path model'
    paths.attr 'd', line

    colorScale = d3.scale.linear()
        .clamp yes
        .domain [-80, 0]
        .range [d3.rgb(0, 0, 0), d3.rgb(0xFF, 0, 0)]

    onMouse = ->
        [x, y] = d3.mouse this
        x = xScale.invert x
        y = yScale.invert y

        gpsSquared = (gpsStd/1000)**2

        max = -1e50
        paths.each ([[px, py]]) ->
            distSquared = (x-px)**2 + (y-py)**2
            logLike = -0.5*distSquared/gpsSquared
            if logLike > max then max = logLike
        paths.each ([[px, py]]) ->
            distSquared = (x-px)**2 + (y-py)**2
            logLike = -0.5*distSquared/gpsSquared - max
            d3.select(this).style 'stroke', colorScale logLike

    canvas.on 'mousemove', _.throttle onMouse, 50,
        leading: yes
        trailing: no
