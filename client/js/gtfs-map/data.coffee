
mainRoadsUrl = 'data/geo/boston-main-roads.topojson'
delaysUrl = 'data/gtfs/analysis/mbta-stop-delays-1700-180.json'

exports.load = ->
    Q $.getJSON delaysUrl
    .catch (err) -> console.error err
    .then ({delays}) ->
        console.log {delays}
        Q {delays}
