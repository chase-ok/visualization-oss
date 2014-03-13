
exports.create = (app) ->
    app.get '/gtfs', (req, res) -> res.render 'gtfs'