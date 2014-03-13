
{mongoose} = db = require '../../db'

collectData = ->

if require.main is module
    db.connect()
    .then collectData
    .catch (err) -> console.log err
    .done()