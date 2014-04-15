
shapesUrl = 'data/geo/mbta-shapes.topojson'

exports.load = ->
    Q $.getJSON shapesUrl
    .catch (err) -> console.error err
