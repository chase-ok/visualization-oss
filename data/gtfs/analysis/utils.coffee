
{mongoose} = db = require '../../db'
Q = require 'q'

exports.makeRef = (collectionName) ->
    type: mongoose.Schema.Types.ObjectId
    ref: collectionName

exports.defer = (block) ->
    deferred = Q.defer()
    try 
        block deferred
    catch error
        deferred.reject error
    deferred.promise
