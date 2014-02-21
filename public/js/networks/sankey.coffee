
require './d3-sankey.js'

# based on http://bost.ocks.org/mike/sankey/

property = (self, {get, set}) -> (x) ->
    return get() unless arguments.length
    throw 'read-only' unless set
    set x
    return self

exports.majorProgression = (canvas, data) ->
    sankey = {}

    # Properties
    canvas = d3.select canvas
    $canvas = $ canvas.node()
    sankey.canvas = property sankey,
        get: -> canvas

    {genderToFirst, firstToThird, thirdToFinal} = data
    sankey.data = property sankey,
        get: -> data

    curvature = 0.4
    sankey.curvature = property sankey,
        get: -> curvature
        set: (x) -> curvature = x; redrawLinks()

    nodeColor = d3.scale.category20()
    sankey.nodeColor = property sankey,
        get: -> nodeColor
        set: (x) -> nodeColor = x; redrawNodes()

    nodeWidth = 15
    sankey.nodeWidth = property sankey,
        get: -> nodeWidth
        set: (x) -> nodeWidth = x; relayout()

    nodePadding = 0
    sankey.nodePadding = property sankey,
        get: -> nodePadding
        set: (x) -> nodePadding = x; relayout()

    showLabels = yes
    sankey.showLabels = property sankey,
        get: -> showLabels
        set: (x) -> showLabels = x; redrawNodes()

    {nodes, links, groups} = do ->
        nodes = []
        makeNode = (group, name, year) -> 
            node = {group, name, year}
            nodes.push node
            node

        toNodes = (mapping, year) ->
            makeNode mapping.name, cat, year for cat in mapping.categories
        genders = toNodes genderToFirst.from, 0
        firstMajors = toNodes genderToFirst.to, 1
        thirdMajors = toNodes firstToThird.to, 3
        finalMajors = toNodes thirdToFinal.to, 5
        groups = 
            'Incoming Students': genders
            'First-Year Major': firstMajors
            'Third-Year Major': thirdMajors
            'Final Major': finalMajors

        links = []
        link = (source, target, value) -> 
            links.push {source, target, value}

        mappingToLinks = (mapping, fromNodes, toNodes) ->
            for to in toNodes
                size = mapping.to.sizes[to.name]
                for from in fromNodes
                    link from, to, size*mapping.values[to.name][from.name]
        mappingToLinks genderToFirst, genders, firstMajors
        mappingToLinks firstToThird, firstMajors, thirdMajors
        mappingToLinks thirdToFinal, thirdMajors, finalMajors
        {nodes, links, groups} 

    titleHeight = 40

    layout = null
    relayout = (shouldRedraw=yes)->
        layout = d3.sankey()
            .nodeWidth nodeWidth
            .nodePadding nodePadding
            .size [$canvas.width(), 
                   $canvas.height() - titleHeight]
            .xScale d3.scale.pow().exponent(1)
            .nodes nodes
            .links links
            .layout 64
        sankey.redraw() if shouldRedraw
    relayout(no)

    sankey.layout = property sankey,
        get: -> layout

    linkOpacity = d3.scale.pow()
        .exponent 0.8
        .clamp yes
        .domain [d3.min(links, (d) -> d.dy), 20]
        .range [0.02, 0.3]
    sankey.linkOpacity = property sankey,
        get: -> linkOpacity
        set: (x) -> linkOpacity = x; redrawLinks()

    highlightedLinkOpacity = 0.7
    sankey.highlightedLinkOpacity = property sankey,
        get: -> highlightedLinkOpacity
        set: (x) -> highlightedLinkOpacity = x; redrawLinks()

    linkSameColor = "#000000"
    sankey.linkSameColor = property sankey,
        get: -> linkSameColor
        set: (x) -> linkSameColor = x; redrawLinks()

    linkDifferentColor = "#990000"
    sankey.linkDifferentColor = property sankey,
        get: -> linkDifferentColor
        set: (x) -> linkDifferentColor = x; redrawLinks()

    curvature = 0.5
    sankey.curvature = property sankey,
        get: -> curvature
        set: (x) -> curvature = x; redrawLinks()

    linkSvg = do ->
        svg = canvas
            .append 'g'
            .attr 'id', 'link-group'
            .selectAll '.sankey-link'
            .data links
            .enter()
                .append 'path'
                .attr 'class', 'sankey-link'
                .style 'stroke-width', ({dy}) -> Math.max 1, dy
                .sort (a, b) -> b.dy - a.dy
        svg
            .append 'title'
            .text (d) -> "#{d.source.name} → #{d.target.name}\n#{d.value}%"
        svg

    redrawLinks = ->
        linkSvg
            .attr 'd', layout.link().curvature curvature
            .style 'stroke-opacity', ({dy}) -> linkOpacity dy
            .style 'stroke', (d) -> 
                if d.source.group is 'Gender' or d.source.name is d.target.name
                    linkSameColor
                else 
                    linkDifferentColor
            .on 'mouseover', -> 
                d3.select(this).style 'stroke-opacity', highlightedLinkOpacity
            .on 'mouseout', (d) -> 
                d3.select(this).style 'stroke-opacity', linkOpacity d.dy

    doNodeDrag = null

    nodeSvg = do ->
        group = canvas
            .append 'g'
            .selectAll '.sankey-node'
            .data nodes 
            .enter()
                .append 'g'
                .attr 'class', 'sankey-node'
                .call(d3.behavior.drag()
                    .origin (d) -> d
                    .on 'dragstart', -> @parentNode.appendChild this
                    .on 'drag', (d) -> doNodeDrag d3.select(this), d)

        rect = group.append 'rect'
        rect.append 'title'
            .text ({name, value}) -> "#{name}\n#{value}%"

        text = group
            .append 'text'
            .attr 'dy', '.35em'
            .text ({name}) -> name

        linkMatches = (node, link) -> 
            link.target is node or link.source is node
        group 
            .on 'mouseover', (d) ->
                linkSvg.filter (link) -> linkMatches d, link
                    .style 'stroke-opacity', highlightedLinkOpacity
            .on 'mouseout', (d) ->
                linkSvg.filter (link) -> linkMatches d, link
                    .style 'stroke-opacity', (link) -> linkOpacity link.dy
        {group, rect, text}

    redrawNodes = ->
        doNodeDrag = (obj, d) ->
            d.y = Math.max 0, Math.min($canvas.height() - d.dy, d3.event.y)
            obj.attr 'transform', "translate(#{d.x},#{d.y})"
            sankey.redraw()

        nodeSvg.group
            .attr 'transform', (d) -> "translate(#{d.x},#{d.y})"
        nodeSvg.rect
            .attr 'height', ({dy}) -> dy
            .attr 'width', nodeWidth
            .attr 'fill', (d) -> d.color = nodeColor(d.name)
        nodeSvg.text
            .attr 'x', -6
            .attr 'y', (d) -> d.dy/2
            .attr 'text-anchor', 'end'
            .text ({name}) -> name
            .filter ({x}) -> x < $canvas.width()/2
                .attr 'x', 6 + nodeWidth
                .attr 'text-anchor', 'start'

    titlesSvg = do ->
        svg = canvas
            .append 'g'
            .attr 'transform', "translate(0,#{$canvas.height()})"
            .selectAll '.sankey-title'
            .data d3.entries groups
            .enter()
                .append 'text'
                .attr 'class', 'sankey-title'
                .text ({key}) -> key
                .attr 'dy', '-0.3em'
                .attr 'x', ({value}) -> value[0].x
                .attr 'text-anchor', 'middle'
        svg
            .filter ({value}) -> value[0].x > 0.75*$canvas.width()
                .attr 'x', ({value}) -> value[0].x + nodeWidth
                .attr 'text-anchor', 'end'
        svg
            .filter ({value}) -> value[0].x < 0.25*$canvas.width()
                .attr 'x', ({value}) -> value[0].x
                .attr 'text-anchor', 'start'
        svg


    sankey.redraw = ->
        redrawLinks()
        redrawNodes()

    # Events
    $canvas.resize ->
        layout.size [canvas.width(), canvas.height()]
        sankey.redraw()

    sankey.redraw()
    return sankey

redraw = null

exports.create = (data) ->
    sankey = exports.majorProgression '#sankey-canvas', data