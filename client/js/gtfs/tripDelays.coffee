
loadSequences = (jsonUrl) ->
    Q $.getJSON jsonUrl
    .catch (err) -> console.error err
    .then ({sequences}) -> sequences

rescaleToMinutes = (sequences) ->
    for sequence in sequences
        for point in sequence
            point[1] /= 60

rescaleToTripPercent = (sequences) ->
    for sequence in sequences
        max = d3.max sequence, (p) -> p[0]
        for point in sequence
            point[0] /= max

partitionIntoRuns = (sequences) ->
    runs = []

    current = []
    current.direction = null
    endCurrent = ->
        runs.push current if current.length > 1
        current = []

    for sequence in sequences
        endCurrent()

        for point, i in sequence
            if current.length is 0
                current.push point
                continue

            direction = sign(point[1] - current[current.length-1][1])

            if current.length is 1
                current.push point
                current.direction = direction
            else if direction isnt current.direction
                endCurrent()
                current.push sequence[i-1]
                current.push point
                current.direction = direction
            else
                current.push point
    endCurrent()

    return runs

sign = (x) ->
    switch
        when _.isNaN x then x
        when x > 0 then 1
        when x < 0 then -1
        else 0

plotSequences = (sequences, canvasSelector='#trip-delay-sequences') ->
    margin =
        top: 5
        left: 30
        right: 5
        bottom: 30

    size = do ->
        $canvas = $ canvasSelector
        x: $canvas.width() - margin.left - margin.right
        y: $canvas.height() - margin.top - margin.bottom

    canvas = do -> 
        d3.select canvasSelector
            .append 'g'
            .attr 'transform', "translate(#{margin.left},#{margin.top})"

    scales = do ->
        allPoints = d3.merge sequences
        x: 
            d3.scale.linear()
                .domain d3.extent allPoints, (p) -> p[0]
                .range [0, size.x]
        y: 
            d3.scale.linear()
                .domain d3.extent allPoints, (p) -> p[1]
                .range [size.y, 0]

    axes = do ->
        axes =
            x: d3.svg.axis().scale(scales.x).orient('bottom')
            y: d3.svg.axis().scale(scales.y).orient('left')

        canvas.append 'g'
            .attr 'class', 'x axis'
            .attr 'transform', "translate(0, #{size.y})"
            .call axes.x
        canvas.append 'g'
            .attr 'class', 'y axis'
            .call axes.y
        axes

    axisLabels = 
        x: 'Stop No.'
        y: 'Delay in Minutes'

    labels = do ->
        fontHeight = 15
        rotated = canvas.append('g').attr('translate', 'rotate(-90)')
        x: 
            canvas.append 'text'
                .text axisLabels.x
                .attr 'x', size.x/2
                .attr 'y', size.y + margin.bottom - fontHeight*1.1
                .attr 'text-anchor', 'middle'
                .attr 'font-size', "#{fontHeight}px"
                .attr 'class', 'x axis label'
        y: 
            rotated.append 'text'
                .text axisLabels.y
                .attr 'x', -size.y/2
                .attr 'y', fontHeight*1.1 - margin.left
                .attr 'text-anchor', 'middle'
                .attr 'font-size', "#{fontHeight}px"
                .attr 'class', 'y axis label'

    lines = do ->
        svgLine = d3.svg.line()
            #.interpolate 'cardinal'
            .x (p) -> scales.x p[0]
            .y (p) -> scales.y p[1]

        lines = canvas.append 'g'
            .selectAll '.data-line'
            .data sequences
        
        lines.enter()
            .append 'path'
            .attr 'class', (sequence) ->
                'data-line ' + switch sequence.direction
                    when 1 then 'delay-increasing'
                    when 0 then 'delay-unchanging'
                    when -1 then 'delay-decreasing'
                    else ''
            .attr 'd', (sequence) -> svgLine sequence

        lines


exports.create = ->
    loadSequences '/data/gtfs/analysis/mbta-mean-trip-sequences.json'
    .done (sequences) -> 
        sequences = sequences
        rescaleToMinutes sequences
        #rescaleToTripPercent sequences
        runs = partitionIntoRuns sequences
        plotSequences runs

