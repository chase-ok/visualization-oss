
require './d3-sankey.js'

# based on http://bost.ocks.org/mike/sankey/

redraw = null

exports.create = (data) ->
    canvas = $ '#sankey-canvas'

    {nodes, links} = makeNodesAndLinks data
    sankey = d3.sankey()
        .nodeWidth 15
        .nodePadding 10
        .size [canvas.width(), canvas.height()]
        .nodes nodes
        .links links
        .layout 32

    link = drawLinks canvas, links, sankey.link()
    node = drawNodes canvas, nodes, sankey.nodeWidth()

    redraw = ->
        sankey.relayout()
        link.attr 'd', sankey.link()

makeNodesAndLinks = (data) ->
    nodes = []
    links = []

    makeNode = (group, name) -> 
        node = {group, name}
        node.id = nodes.push(node) - 1
        node
    makeLink = (source, target, value) -> 
        links.push {source: source.id, target: target.id, value}

    genders = (makeNode('Gender', name) for name, x of data.fields.Gender)

    makeMajors = (group) ->
        majors = []
        for name, i in data.headers
            major = makeNode group, name
            major.index = i
            majors.push major
        majors

    firstMajors = makeMajors 'Major during first year'
    thirdMajors = makeMajors 'Major when last enrolled 1998 (12 cat)'

    getLinkValue = (node, major) ->
        data.fields[node.group][node.name][major.index]

    genderPercents = {Male: 0.449, Female: 0.550}
    for major in firstMajors
        for gender in genders
            scale = genderPercents[gender.name]
            makeLink gender, major, scale*getLinkValue(gender, major)
    
    thirdPercents = [
        0.037368837, 0.083650861, 0.084378345, 0.041777747, 0.009191817, 
        0.007284032, 0.033729875, 0.056891516, 0.06413647, 0.138084745, 
        0.081307772, 0.042285704, 0.095574191]

    for first in firstMajors
        for third in thirdMajors
            #scale = data.totals[first.index]/100
            scale = thirdPercents[third.index]
            makeLink first, third, scale*getLinkValue(third, first)

    {nodes, links}

drawLinks = (canvas, links, path) ->
    opacity = d3.scale.pow()
        .exponent 0.8
        .clamp yes
        .domain [d3.min(links, (d) -> d.dy), 20]
        .range [0.02, 0.4]

    link = d3.select canvas.get 0
        .append 'g'
        .selectAll '.sankey-link'
        .data links
        .enter()
            .append 'path'
            .attr 'class', 'sankey-link'
            .attr 'd', path
            .style 'stroke-width', (d) -> Math.max 1, d.dy
            .style 'stroke-opacity', (d) -> opacity d.dy
            .sort (a, b) -> b.dy - a.dy
            .on 'mouseover', -> d3.select(this).style 'stroke-opacity', 0.6
            .on 'mouseout', (d) -> d3.select(this).style 'stroke-opacity', opacity d.dy 

    link
      .append 'title'
      .text (d) -> "#{d.source.name} → #{d.target.name}\n#{d.value}%"

    link

drawNodes = (canvas, nodes, nodeWidth) ->
    colors = d3.scale.category20()

    doDrag = (d) ->
        d.y = Math.max 0, Math.min(canvas.height() - d.dy, d3.event.y)
        d3.select(this).attr 'transform', "translate(#{d.x},#{d.y})"
        redraw()

    node = d3.select canvas.get 0
        .append 'g'
        .selectAll '.sankey-node'
        .data nodes 
        .enter()
            .append 'g'
            .attr 'class', 'sankey-node'
            .attr 'transform', (d) -> "translate(#{d.x},#{d.y})"
            .call(d3.behavior.drag()
                .origin (d) -> d
                .on 'dragstart', -> @parentNode.appendChild this
                .on 'drag', doDrag)

    node
        .append 'rect'
        .attr 'height', (d) -> d.dy
        .attr 'width', nodeWidth
        .attr 'fill', (d) -> d.color = colors d.name
        .style 'stroke', (d) -> d3.rgb(d.color).darker(2)
        .append 'title'
            .text (d) -> "#{d.name}\n#{d.value}%"

    node
        .append 'text'
        .attr 'x', -6
        .attr 'y', (d) -> d.dy/2
        .attr 'dy', '.35em'
        .attr 'text-anchor', 'end'
        .attr 'transform', null # do we need this?
        .text (d) -> d.name
        .filter (d) -> d.x < canvas.width()/2
            .attr 'x', 6 + nodeWidth
            .attr 'text-anchor', 'start'

    node


