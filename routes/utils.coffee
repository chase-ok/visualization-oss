
exports.fail = (res, error) -> res.json
    success: no
    error: error

exports.succeed = (res, result={}) ->
    result.success = yes
    res.json result 