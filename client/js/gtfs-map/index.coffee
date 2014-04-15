
canvasSelector = '#map-canvas'

getDimensions = ->
    width: $(canvasSelector).width()
    height: $(canvasSelector).height()

###
showMainRoads = (projection, mainRoads) ->
    featureName = _.keys(mainRoads.objects)[0]
    feature = topojson.feature mainRoads, mainRoads.objects[featureName]

    path = d3.select(canvasSelector).append 'path'
        .datum feature
        .attr 'class', 'main-roads'
        .attr 'd', d3.geo.path().projection projection
###

showOpenStreetMap = (projection) ->
    {width, height} = getDimensions()
    tiler = d3.geo.tile().size [width, height]
        .scale projection.scale()*2*Math.PI
        .translate projection [0, 0]

    path = d3.geo.path().projection projection

    tileToUrl = (tile) ->
        "http://#{['a', 'b', 'c'][(tile[0]*31 + tile[1])%3]}.tile.openstreetmap.us/vectiles-highroad/#{tile[2]}/#{tile[0]}/#{tile[1]}.json"

    tiles = d3.select(canvasSelector).selectAll(".tile").data tiler

    tiles.enter().append 'g'
        .attr 'class', 'tile'

    tiles.each (tile) ->
        g = d3.select this
        d3.json tileToUrl(tile), (error, json) ->
            return console.log error if error

            features = json.features.sort (a, b) ->
                a.properties.sort_key - b.properties.sort_key

            g.selectAll('path').data features
                .enter().append 'path'
                .attr 'class', (d) -> d.properties.kind
                .attr 'd', path

showDelays = (projection, delays) ->
    radius = 10
    opacity = d3.scale.linear()
        .domain d3.extent delays, ({delay}) -> delay
        .range [0.01, 0.3]

    points = d3.select(canvasSelector)
        .append 'g'
        .selectAll '.delay'
        .data delays
    
    points.enter().append 'circle'
        .attr 'class', 'delay'
        .attr 'r', radius

    points
        .attr 'cx', ({lat, lon}) -> projection([lon, lat])[0]
        .attr 'cy', ({lat, lon}) -> projection([lon, lat])[1]
        .attr 'opacity', ({delay}) -> opacity delay

$ ->
    {width, height} = getDimensions()
    projection = d3.geo.mercator()
        .center [ -71.060464, 42.359297]
        .scale (1 << 21)/(2*2*Math.PI)
        .translate [width/2, height/2]

    showOpenStreetMap projection

    require('./data.coffee').load()
    .then ({delays}) ->
        showDelays projection, delays