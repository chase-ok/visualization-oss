
$ ->
    console.log 'hello world'
    require('./data.coffee').loadTrips()
    .then (trips) ->
        require('./map.js').show trips, '#route-8-map'
        require('./trip-plot.coffee').show trips
        require('./point-model.coffee').show trips
