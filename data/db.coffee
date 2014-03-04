

exports.mongoose = mongoose = require('mongoose-q') require 'mongoose'
Q = require 'q'

uri = process.env.MONGOLAB_URI or 
      process.env.MONGOHQ_URL or
      'mongodb://localhost/visualization-oss'

exports.connect = -> Q.ninvoke mongoose, 'connect', uri

exports.dropModel = (model) ->
    deferred = Q.defer()
    mongoose.connection.db.dropCollection model.collection.name, (err) ->
        console.warn err if err # swallow errors here
        deferred.resolve()
    deferred.promise

exports.batchInsert = (model, docs, batchSize=2048) ->
    return Q() unless docs

    # make sure that the collection exists
    promise = model.createQ docs[0]
    for batchStart in [1...docs.length] by batchSize
        do (batchStart) -> promise = promise.then ->
            console.log "Batch start #{batchStart}/#{docs.length} for #{model.modelName}"
            batch = docs[batchStart...(batchStart+batchSize)]
            Q.ninvoke model.collection, 'insert', batch, {w: 1}
            .fail (err) -> console.log err
    promise
