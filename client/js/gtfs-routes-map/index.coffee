
canvasSelector = '#map-canvas'

getDimensions = ->
    width: $(canvasSelector).width()
    height: $(canvasSelector).height()

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

showRoutes = (projection, routes) ->
    path = d3.geo.path().projection projection

    routePaths = d3.select(canvasSelector)
        .selectAll('.route')
        .data topojson.feature(routes, routes.objects.shapes).features

    routePaths.enter().append 'path'
        .attr 'class', 'route'

    routePaths
        .style 'stroke', ({properties}) -> (properties.color or 0).toString 16 
        .attr 'd', path

$ ->
    {width, height} = getDimensions()
    projection = d3.geo.mercator()
        .center [ -71.060464, 42.359297]
        .scale (1 << 21)/(2*2*Math.PI)
        .translate [width/2, height/2]

    showOpenStreetMap projection

    require('./data.coffee').load()
    .then (routes) ->
        showRoutes projection, routes
