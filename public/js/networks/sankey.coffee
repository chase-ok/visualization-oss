
require './d3-sankey.js'

exports.create = (data) ->
    canvas = $ '#sankey-canvas'

    {nodes, links} = makeNodesAndLinks data
    sankey = d3.sankey().nodeWidth(15)
               .nodePadding(10)
               .size([canvas.width(), canvas.height()])
               .nodes(nodes)
               .links(links)
               .layout(32)

    drawLinks canvas, links, sankey.link()
    drawNodes canvas, nodes, sankey.nodeWidth()

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

    firstMajors = []
    for name, i in data.headers
        major = makeNode 'First Major', name
        major.index = i
        firstMajors.push major

    getLinkValue = (node, major) ->
        data.fields[node.group][node.name][major.index]

    for major in firstMajors
        for gender in genders
            makeLink gender, major, getLinkValue(gender, major)

    {nodes, links}

drawLinks = (canvas, links, path) ->
    link = d3.select(canvas.get(0)).append('g')
             .selectAll('.sankey-link')
             .data(links)
             .enter().append('path')
             .attr('class', 'sankey-link')
             .attr('d', path)
             .style('stroke-width', (d) -> Math.max 1, d.dy)
             .sort((a, b) -> b.dy - a.dy)

    link.append('title')
        .text((d) -> "#{d.source.name} → #{d.target.name}\n#{d.value}%")

drawNodes = (canvas, nodes, nodeWidth) ->


