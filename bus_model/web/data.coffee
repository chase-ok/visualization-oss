
exports.loadTrips = ->
    Q $.getJSON 'trips.json'
    .catch (err) -> console.error err
