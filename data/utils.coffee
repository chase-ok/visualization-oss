
{mongoose} = db = require './db'
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

exports.memoizeUnary = (func, hash=(x)->"#{x}") ->
    cache = {}
    (x) ->
        key = hash x
        if key of cache then cache[key] 
        else cache[key] = func x