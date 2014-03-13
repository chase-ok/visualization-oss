
{mongoose} = db = require '../../db'

exports.makeRef = (collectionName) ->
    type: mongoose.Schema.Types.ObjectId
    ref: collectionName