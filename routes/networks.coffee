
exports.create = (app) ->
    app.get '/networks', (req, res) -> res.render 'networks'