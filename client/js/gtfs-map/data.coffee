
mainRoadsUrl = 'data/geo/boston-main-roads.topojson'

exports.load = ->
    Q $.getJSON mainRoadsUrl
    .catch (err) -> console.error err
    .then (topo) ->
        console.log {topo}
        Q {mainRoads: topo}
