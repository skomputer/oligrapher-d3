# requires D3!

class LittlesisApi

  constructor: (key) ->
    @key = key
    @base_url = "http://api.littlesis.org/"

  entities_and_rels_url: (entity_ids) ->
    @base_url + "map/entities.json?entity_ids=" + entity_ids.join(",") + "&_key=" + @key

  entities_and_rels: (entity_ids, callback) ->
    $.ajax({
      url: @entities_and_rels_url(entity_ids),
      success: callback,
      error: -> alert("There was an error retrieving data from the API")
      dataType: "json"
    });  

  get_add_entity_data: (entity_id, entity_ids, callback) ->
    $.ajax({
      url: @base_url + "map/addEntityData.json",
      data: { "entity_id": entity_id, "entity_ids": entity_ids },
      success: callback,
      error: -> alert("There was an error retrieving data from the API"),
      type: "GET",
      dataType: "json"
    })    

  get_add_related_entities_data: (entity_id, num, entity_ids, rel_ids, include_cats = [], callback) ->
    $.ajax({
      url: @base_url + "map/addRelatedEntitiesData.json",
      data: { "entity_id": entity_id, "num": num, "entity_ids": entity_ids, "rel_ids": rel_ids, "include_cat_ids": include_cats },
      success: callback,
      error: -> alert("There was an error retrieving data from the API"),
      type: "GET",
      dataType: "json"
    })   

  search_entities: (q, callback) ->
    $.ajax({
      url: @base_url + "map/searchEntities.json",
      data: { "q": q },
      success: callback,
      error: -> alert("There was an error retrieving data from the API"),
      type: "GET",
      dataType: "json"
    })

  create_map: (width, height, user_id, out_data, callback) ->
    $.ajax({
      url: @base_url + "map.json",
      data: { "width": width, "height": height, "user_id": user_id, "data" : JSON.stringify(out_data) },
      success: callback,
      error: -> alert("There was an error sending data to the API"),
      type: "POST",
      dataType: "json"
    })
    
  get_map: (id, callback) ->
    $.ajax({
      url: @base_url + "map/#{id}.json",
      success: callback,
      error: -> alert("There was an error retrieving data from the API"),
      dataType: "json"
    })

  update_map: (id, width, height, out_data, callback) ->
    $.ajax({
      url: @base_url + "map/#{id}/update.json",
      data: { "width": width, "height": height, "data" : JSON.stringify(out_data) },
      success: callback,
      error: -> alert("There was an error sending data to the API"),
      type: "POST",
      dataType: "json"
    })

    
class Netmap

  constructor: (width, height, parent_selector, key, clean_mode = true, zoom_enabled = true) ->
    @width = width
    @height = height
    @min_zoom = 0.1
    @max_zoom = 2
    @parent_selector = parent_selector
    @clean_mode = clean_mode
    @zoom_enabled = zoom_enabled
    @init_svg()
    @force_enabled = false
    @entity_background_opacity = 0.6
    @entity_background_color = "#fff"
    @entity_background_corner_radius = 5
    @distance = 600
    @api = new LittlesisApi(key)
    @init_callbacks()
    @current_only = false
    @default_rels = false
    @straight_rels = false
    @current_rels = false
    @hide_images = false
    @mode = 'default'
    @gravity = 0.3
    @charge = -5000
    @entity_links = true
    @bg_color = null

  init_svg: ->
    @svg = d3.select(@parent_selector)
      .append("svg")
      .attr("version", "1.1")
      .attr("xmlns", "http://www.w3.org/2000/svg")
      .attr("xmlns:xmlns:xlink", "http://www.w3.org/1999/xlink")
      .attr("id", "svg")
      .attr("width", if @width? then @width else "100%")
      .attr("height", if @height? then @height else "100%")

    zoom = @svg.append('g')
      .attr("id", "zoom")

    unless @clean_mode
      zoom.append('line')
        .attr('x1', -8)
        .attr('y1', 0)
        .attr('x2', 8)
        .attr('y2', 0)
        .attr('stroke', '#ccc')
      zoom.append('line')
        .attr('x1', 0)
        .attr('y1', -8)
        .attr('x2', 0)
        .attr('y2', 8)
        .attr('stroke', '#ccc')

    marker1 = @svg.append("marker")
      .attr("id", "marker1")
      .attr("viewBox", "0 -5 10 10")
      .attr("refX", 8)
      .attr("refY", 0)
      .attr("markerWidth", 6)
      .attr("markerHeight", 6)
      .attr("orient", "auto")
      .append("path")
      .attr("d", "M0,-5L10,0L0,5")

    marker2 = @svg.append("marker")
      .attr("id", "marker2")
      .attr("viewBox", "-10 -5 10 10")
      .attr("refX", -8)
      .attr("refY", 0)
      .attr("markerWidth", 6)
      .attr("markerHeight", 6)
      .attr("orient", "auto")
      .append("path")
      .attr("d", "M0,-5L-10,0L0,5")

    @init_gradients()

    @zoom = d3.behavior.zoom()
    @zoom.scaleExtent([@min_zoom, @max_zoom])
    t = this
    zoom_func = ->
      t.update_zoom()
      trans = d3.event.translate
      scale = d3.event.scale
      zoom.attr("transform", "translate(" + trans + ")" + " scale(" + scale + ")")

    if @zoom_enabled
      @svg.call(@zoom.on("zoom", zoom_func))

  init_gradients: ->
    defs = @svg.append("defs")

    grad = defs.append("radialGradient")
      .attr("id", "gradient-left")
      .attr("cx", 1)
      .attr("cy", 0.5)
    grad.append("stop")
      .attr("offset", "0%")
      .attr("stop-color", "rgba(0, 0, 0, 0)")
    grad.append("stop")
      .attr("offset", "80%")
      .attr("stop-color", "rgba(255, 0, 255, 0.1)")
    grad.append("stop")
      .attr("offset", "100%")
      .attr("stop-color", "rgba(255, 0, 255, 0.2)")

    grad = defs.append("radialGradient")
      .attr("id", "gradient-right")
      .attr("cx", 0)
      .attr("cy", 0.5)
    grad.append("stop")
      .attr("offset", "0%")
      .attr("stop-color", "rgba(0, 0, 0, 0)")
    grad.append("stop")
      .attr("offset", "80%")
      .attr("stop-color", "rgba(255, 0, 255, 0.1)")
    grad.append("stop")
      .attr("offset", "100%")
      .attr("stop-color", "rgba(255, 0, 255, 0.2)")

    grad = defs.append("linearGradient")
      .attr("id", "gradient-middle-magenta")
    grad.append("stop")
      .attr("offset", "0%")
      .attr("stop-color", "rgba(0, 0, 0, 0)")
    grad.append("stop")
      .attr("offset", "50%")
      .attr("stop-color", "rgba(255, 0, 255, 0.3)")
    grad.append("stop")
      .attr("offset", "100%")
      .attr("stop-color", "rgba(0, 0, 0, 0)")

    grad = defs.append("linearGradient")
      .attr("id", "gradient-middle-green")
    grad.append("stop")
      .attr("offset", "0%")
      .attr("stop-color", "rgba(0, 0, 0, 0)")
    grad.append("stop")
      .attr("offset", "50%")
      .attr("stop-color", "rgba(0, 255, 0, 0.3)")
    grad.append("stop")
      .attr("offset", "100%")
      .attr("stop-color", "rgba(0, 0, 0, 0)")    

  compute_graph_center: ->
    entities = @entities()

    xs = entities.map((e) -> if e.x then e.x else 0)
    ys = entities.map((e) -> if e.y then e.y else 0)   

    {
      x: (Math.min.apply(null, xs) + Math.max.apply(null, xs)) / 2
      y: (Math.min.apply(null, ys) + Math.max.apply(null, ys)) / 2
    }

  svg_size: ->
    { x: $('#svg').width(), y: $('#svg').height() }

  svg_center: ->
    size = @svg_size()
    { x: Math.floor(size.x/2), y: Math.floor(size.y/2) }

  auto_center: (x = true, y = true) ->
    if @centered_coordinates()
      center = @svg_center()
      @zoom.translate([center.x, center.y])
    else
      graph_center = @compute_graph_center()
      svg_center = @svg_center()
      shift = @zoom.translate()

      dx = if x then svg_center.x - graph_center.x - shift[0] else 0
      dy = if y then svg_center.y - graph_center.y - shift[1] else 0

      @shift_map(dx, dy)

  recenter: ->
    shift = @compute_graph_center()
    @_data.entities = @_data.entities.map((e) ->
      e.x += -shift.x
      e.y += -shift.y
      e
    )
    @_data.texts = @_data.texts.map((t) ->
      t.x += -shift.x
      t.y += -shift.y
      t
    )
    @build()

  shift_map: (dx, dy) ->
    dx ?= 0
    dy ?= 0
    @zoom.translate([@zoom.translate()[0] + dx, @zoom.translate()[1] + dy])
    @update_zoom()

  zoom_by: (scale) ->
    centered = @centered_coordinates()
    svg_size = @svg_size()
    new_scale = @zoom.scale() * scale
    new_scale = @min_zoom if new_scale < @min_zoom
    new_scale = @max_zoom if new_scale > @max_zoom
    x_diff = (if centered then 0 else (new_scale - @zoom.scale()) * svg_size.x)
    y_diff = (if centered then 0 else (new_scale - @zoom.scale()) * svg_size.y)
    @zoom.scale(new_scale)
    @zoom.translate([@zoom.translate()[0]-x_diff/2, @zoom.translate()[1]-y_diff/2])
    @update_zoom()

  round_scale: ->
    @zoom.scale(Math.round(@zoom.scale() * 1000) / 1000)

  update_zoom: ->
    @round_scale()
    d3.select("#zoom").attr("transform", "translate(" + @zoom.translate() + ") scale(" + @zoom.scale() + ")")
  
  reset_zoom: ->
    @zoom.scale(1)
    @auto_center()
    @update_zoom()

  set_translate: (x, y) ->
    @zoom.translate([x, y])
    @update_zoom()

  set_translate_x: (x) ->
    @zoom.translate([x, @zoom.translate()[1]])
    @update_zoom()

  set_translate_y: (y) ->
    @zoom.translate([@zoom.translate()[0], y])
    @update_zoom()

  get_scale: ->
    @zoom.scale()

  get_translate: ->
    @zoom.translate()

  set_default_rels: (val = true) ->
    @default_rels = val
    # @rels().forEach((rel) ->
    #     rel.x1 = null
    #     rel.y1 = null
    #   )
    @update_positions()

  set_all_rels_to_current: ->
    @rels().forEach((rel) ->
        rel.is_current = 1
      )
    @update_positions()

  init_callbacks: ->
    t = this

    # so we know where the mouse is on keydown
    $(window).on("mousemove", (e) ->
      t.mouse_x = e.pageX
      t.mouse_y = e.pageY
    )

    @keymap = {}

    $(document).on("keyup", (e) ->
      t.keymap[e.keyCode] = false
    )

    $(document).on("keydown", (e) ->
      t.keymap[e.keyCode] = true

      unless t.clean_mode
        if e.ctrlKey or e.altKey
          # backspace, delete, "D", or "d"
          if t.keymap[8] or t.keymap[46] or t.keymap[68] or t.keymap[100]
            rebuild = false
            selected = $(".selected").length > 0
            for d in d3.selectAll($(".rel.selected")).data()
              t.remove_rel(d.id)      
              rebuild = true
            for d in d3.selectAll($(".entity.selected")).data()
              t.remove_entity(d.id)
              rebuild = true
            for d in d3.selectAll($(".text.selected")).data()
              t.remove_text(d.id)
              rebuild = true
            t.build() if rebuild
            $(window).trigger('selection') if selected
            e.preventDefault() if selected
          # "N" or "n"
          if t.keymap[78] or t.keymap[110]
            if $(t.parent_selector + ":hover").length > 0
              $(window).trigger('toggle_add_node_form') 
          # "E" or "e"
          if t.keymap[69] or t.keymap[101]
            if $(t.parent_selector + ':hover').length > 0
              data = d3.selectAll('.entity.selected').data()
              if data.length > 0
                $(window).trigger('toggle_add_edge_form', data[0])
          # "R" or "r"
          if t.keymap[82] or t.keymap[114]
            if $(t.parent_selector + ':hover').length > 0
              data = d3.selectAll('.entity.selected').data()
              if data.length > 0
                t.toggle_add_related_entities_form(data[0].id)
          # "T" or "t"
          if t.keymap[84] or t.keymap[116]
            if $(t.parent_selector + ":hover").length > 0
              $(window).trigger('toggle_add_text_form')
          # "="
          if t.keymap[61] or t.keymap[187]
            t.zoom_by(1.2)
          # "-"
          if t.keymap[173] or t.keymap[189]
            t.zoom_by(0.83333333333333)
          # "0"
          if t.keymap[48]
            t.reset_zoom()
          # "S" or "s"
          if t.keymap[83] or t.keymap[115]
            t.deselect_all()
            e = $('.entity')[0]
            $(window).trigger('selection', e) if e
    )
    
  toggle_add_entity_form: ->
    form = $("#netmap_add_entity")
    $(@parent_selector).append(form)
    form.css("left", @mouse_x - $(@parent_selector).offset().left - 30 + "px")
    form.css("top", @mouse_y - $(@parent_selector).offset().top - 60 + "px")
    form.css("display", if form.css("display") == "none" then "block" else "none")

  toggle_add_related_entities_form: (entity_id) ->
    entity = @entity_by_id(entity_id)
    form = $("#netmap_add_related_entities")
    $(@parent_selector).append(form)
    $("#netmap_add_related_entities_entity_id").val(entity_id)
    form.css("left", entity.x + @zoom.translate()[0] + 40 + "px")
    form.css("top", (entity.y + @zoom.translate()[1] - 30) | 0 + "px")
    form.css("display", if form.css("display") == "none" then "block" else "none")
                    
  set_data: (data, center_entity_id = null) ->
    @_original_data = {}
    for key, value of data
      @_original_data[key] = value.slice(0)
    @_data = data    
    @set_center_entity_id(center_entity_id) if center_entity_id?

    @prepare_entities_and_rels()

    @_data['texts'] = [] unless @_data.texts
    @ensure_text_ids()

  prepare_entities_and_rels: ->
    entity_index = []
    for e, i in @_data.entities
      entity_index[e.id] = i
      e.hide_image = false unless e.hide_image
      e.scale = 1 unless e.scale

    @rel_groups = {}
    for r in @_data.rels
      if typeof r.x1 == "undefined"
        r.x1 = null
        r.y1 = null
      r.source = @_data.entities[entity_index[r.entity1_id]]
      r.target = @_data.entities[entity_index[r.entity2_id]]
      r.scale = 1 unless r.scale

      sorted = [r.entity1_id, r.entity2_id].sort()
      min = sorted[0]
      max = sorted[1]

      if @rel_groups[min]
        if @rel_groups[min][max]
          @rel_groups[min][max].push(r.id)
        else
          @rel_groups[min][max] = [r.id]
      else
        obj = {}
        obj[max] = [r.id]
        @rel_groups[min] = obj


  data: ->
    @_data

  entity_ids: ->
    @_data.entities.map((e) -> e.id)

  entities: ->
    @_data.entities

  littlesis_entity_ids: ->
    @entity_ids().filter((id) -> id.toString().indexOf('x') == -1)

  rel_ids: ->
    @_data.rels.map((r) -> r.id)

  rels: ->
    @_data.rels

  littlesis_rel_ids: ->
    @rel_ids().filter((id) -> id.toString().indexOf('x') == -1)    

  set_user_id: (user_id) ->
    @user_id = user_id

  set_network_map_id: (id) ->
    @network_map_id = id

  get_network_map_id: ->
    @network_map_id

  save_map: (callback = null) ->
    @remove_hidden_rels()
    if @network_map_id?
      @update_map(callback)
    else
      @create_map(callback)

  api_data_callback: (callback = null, redirect = false) ->
    t = this  
    (data) ->
      t.network_map_id = data.id
      t.set_data(data.data)
      t.build()
      callback.call(t, data.id) if callback?
      window.location.href = "http://littlesis.org/map/" + t.network_map_id if redirect
      
  create_map: (callback = null) ->
    t = this
    @api.create_map(@width, @height, @user_id, @_data, @api_data_callback(callback, true))

  load_map: (id, callback = null) ->
    @network_map_id = id
    t = this
    @api.get_map(id, @api_data_callback(callback))

  reload_map: ->
    if @network_map_id?
      @load_map(@network_map_id) 
    else
      @set_data(@_original_data)
      @build()
      @wheel()
    
  update_map: (callback = null) ->
    return unless @network_map_id?
    t = this
    @api.update_map(@network_map_id, @width, @height, @_data, @api_data_callback(callback))

  data_for_save: ->
    { "width": @width, "height": @height, "zoom": @zoom.scale(), "user_id": @user_id, "data": JSON.stringify(@_data) }  

  search_entities: (q, callback = null) ->
    @api.search_entities(q, callback)
    
  add_entity: (id, position = null) ->
    return false if @entity_ids().indexOf(parseInt(id)) > -1
    t = this
    @api.get_add_entity_data(id, @littlesis_entity_ids(), (data) ->
      data.entities = data.entities.map((e) ->
        e.x = if position? then position[0] - t.get_translate()[0] else t.width/2 + 200 * (0.5 - Math.random())
        e.y = if position? then position[1] - t.get_translate()[1] else t.height/2 + 200 * (0.5 - Math.random())
        e
      )
      new_data = {
        "entities": t.data().entities.concat(data.entities),
        "rels": t.data().rels.concat(data.rels),
        "texts": (if t.data().texts then t.data().texts else [])
      };
      t.set_data(new_data)
      t.build()
      t.limit_to_current() if t.current_only
    )

  add_related_entities: (entity_id, num = 10, include_cats = []) ->
    entity = @entity_by_id(entity_id)
    return false unless entity?
    t = this
    @api.get_add_related_entities_data(entity_id, num, @littlesis_entity_ids(), @littlesis_rel_ids(), include_cats, (data) ->
      data.entities = t.circle_entities_around_point(data.entities, [entity.x, entity.y])
      t.set_data({
        "entities": t.data().entities.concat(data.entities),
        "rels": t.data().rels.concat(data.rels),
        "texts": (if t.data().texts then t.data().texts else [])   
      })
      t.build()
      t.limit_to_current() if t.current_only
    )
    true

  move_entities_inbounds: ->
    for e in @_data.entities
      e.x = 70 if e.x < 70
      e.x = @width if e.x > @width
      e.y = 50 if e.y < 50
      e.y = @height if e.y > @height

  circle_entities_around_point: (entities, position, radius = 150) ->
    for e, i in entities
      angle = i * ((2 * Math.PI) / entities.length)
      e.x = position[0] + radius * Math.cos(angle)
      e.y = position[1] + radius * Math.sin(angle)
    entities
      
  prune: ->
    @remove_hidden_rels()
    for e in @unconnected_entities()
      @remove_entity(e.id)
    @build()

  show_all_rels: ->
    for rel in @_data.rels
      delete rel["hidden"]
    @current_only = false
    @build()

  limit_to_cats: (cat_ids) ->
    for rel in @_data.rels
      if rel.category_ids?
        if rel.category_ids.filter((id) -> cat_ids.indexOf(id) > -1).length > 0
          rel.hidden = false
        else
          rel.hidden = true      
      else
        rel.hidden = cat_ids.indexOf(rel.category_id) == -1
    @build()

  limit_to_current: ->
    for rel in @_data.rels
      if rel.is_current == 1
        rel.hidden = false
      else
        rel.hidden = true
    @current_only = true
    @build()

  remove_hidden_rels: ->
    @_data.rels = @_data.rels.filter((r) -> !r.hidden)    
    @build()
    
  unconnected_entities: ->
    connected_ids = []
    for r in @_data.rels
      connected_ids.push(parseInt(r.entity1_id))
      connected_ids.push(parseInt(r.entity2_id))
    @_data.entities.filter((e) ->
      connected_ids.indexOf(parseInt(e.id)) == -1
    )
    
  rel_index: (id) ->
    for r, i in @_data.rels
      return i if r.id.toString() == id.toString()

  rel_by_id: (id) ->
    for r, i in @_data.rels
      return r if r.id.toString() == id.toString()

  remove_rel: (id) ->
    @_data.rels.splice(@rel_index(id), 1)

  entity_index: (id) ->
    for e, i in @_data.entities
      return i if e.id.toString() == id.toString()

  entity_by_id: (id) ->
    for e, i in @_data.entities
      return e if e.id.toString() == id.toString()
    return null

  remove_entity: (id) ->
    @_data.entities.splice(@entity_index(id), 1)
    @remove_orphaned_rels()
    
  rels_by_entity: (id) ->
    @_data.rels.filter((r) -> 
      r.entity1_id.toString() == id.toString() || r.entity2_id.toString() == id.toString()
    )

  rel_curve_ratio: (rel) ->
    sorted = [rel.entity1_id, rel.entity2_id].sort()
    min = sorted[0]
    max = sorted[1]

    rels = @rel_groups[min][max]
    n = rels.length
    if n == 1
      return 0.5
    else
      i = rels.indexOf(rel.id)
      return 0.7 * (i+1)/n

  set_center_entity_id: (id) ->
    @center_entity_id = id
    for entity in @_data["entities"]
      if entity.id == @center_entity_id
        entity.fixed = true
        entity.x = @width / 2
        entity.y = @height / 2

  wheel: (center_entity_id = null) ->
    center_entity_id = @center_entity_id if @center_entity_id?
    return @halfwheel(center_entity_id) if center_entity_id?
    count = 0
    center_x = 0
    center_y = 0
    for entity, i in @_data["entities"]
      angle = Math.PI + (2 * Math.PI / (@_data["entities"].length - (if center_entity_id? then 1 else 0))) * count
      @_data["entities"][i].x = center_x + @distance * Math.cos(angle)
      @_data["entities"][i].y = center_y + @distance * Math.sin(angle)
      count++
    @update_positions()

  halfwheel: (center_entity_id = null) ->
    center_entity_id = @center_entity_id if @center_entity_id?
    return unless center_entity_id?    
    return @one_time_force() if @_data["entities"].length < 3
    count = 0
    for entity, i in @_data["entities"]
      if parseInt(entity.id) == center_entity_id
        @_data["entities"][i].x = @width/2
        @_data["entities"][i].y = 80
      else        
        range = Math.PI * 2/3
        angle = Math.PI + (Math.PI / (@_data["entities"].length-2)) * count
        @_data["entities"][i].x = 70 + (@width-140)/2 + ((@width-140)/2) * Math.cos(angle)
        @_data["entities"][i].y = 80 - ((@width-140)/2) * Math.sin(angle)  
        count++
    @update_positions()

  grid: ->
    num = @_data.entities.length
    area = @width * @height
    per = (area / num) * 0.7
    radius = Math.floor(Math.sqrt(per))
    x_num = Math.ceil(@width / (radius * 1.25))
    y_num = Math.ceil(@height / (radius * 1.25))
    for i in [0..x_num-1]
      for j in [0..y_num-1]
        k = x_num * j + i
        if @_data.entities[k]?
          @_data.entities[k].x = i * radius + 70 + (50 - 50 * Math.random())
          @_data.entities[k].y = j * radius + 30 + (50 - 50 * Math.random())
    @update_positions()

  interlocks: (degree0_id, degree1_ids, degree2_ids) ->
    d0 = @entity_by_id(degree0_id)
    d0.x = @width/2
    d0.y = 30
    for id, i in degree1_ids
      range = Math.PI * 1/2

      if degree1_ids.length > 1
        angle = (Math.PI * 3/2) + i * (range / (degree1_ids.length-1)) - range/2
      else
        angle = 0

      radius = (@width-100)/2
      d1 = @entity_by_id(id)

      if degree1_ids.length > 1
        d1.x = 70 + i * (@width-140)/(degree1_ids.length-1)
        d1.y = @height/2 + 250 + (radius) * Math.sin(angle)
      else 
        d1.x = 70 + (@width-140)/2
        d1.y = @height/2 - 50

    for id, i in degree2_ids
      range = Math.PI * 1/3
      angle = (Math.PI * 3/2) + i * (range / (degree2_ids.length-1)) - range/2
      radius = (@width-100)/2
      d2 = @entity_by_id(id)
      d2.x = 70 + i * (@width-140)/(degree2_ids.length-1)
      d2.y = @height - 480 - radius * Math.sin(angle)
    @update_positions()    

  circle: (distance = 1000, random_offset = false) ->
    @svg.attr('class', 'circle')

    @distance = distance
    @mode = 'circle'
    @wheel(null, random_offset)

  vertical: (spacing = 100) ->
    @svg.attr('class', 'vertical axis')
    @mode = 'vertical'
    y = @entities().length * spacing
    @entities().forEach((e, i) ->
      e.x = 0
      e.y = -y/2 + (i * spacing)
    )
    @update_positions()

  vertical_cats: (layout_cats, spacing = 100, width = 2000) ->
    @svg.attr('class', 'vertical axis')
    @mode = 'vertical_cats'

    @layout_cats = layout_cats
    all_ids = []

    for cat, i in @layout_cats
      col_x = i * width/(@layout_cats.length - 1)
      col_ids = []

      for subcat in cat
        col_ids = col_ids.concat(subcat)
        all_ids = all_ids.concat(subcat)
        col_ids.push(false)
      col_ids.pop()
      col_height = col_ids.length * spacing

      for id, j in col_ids
        if id
          e = @entity_by_id(id)
          e.x = col_x
          e.y = -col_height/2 + (j * spacing)
          e.cat = i

    # limit to entities in cats
    ids_to_remove = @entity_ids().filter((id) -> all_ids.indexOf(id) == -1)

    for eid in ids_to_remove
      @remove_entity(eid)
    @remove_orphaned_rels()

    @build()
   
  horizontal: (spacing = 100) ->
    @svg.attr('class', 'horizontal axis')
    @mode = 'horizontal'
    x = @entities().length * spacing
    @entities().forEach((e, i) ->
      e.y = 0
      e.x = -x/2 + (i * spacing)
    )
    @update_positions()

  shuffle_array: (array) ->
    counter = array.length
    # While there are elements in the array
    while counter--
      # Pick a random index
      index = (Math.random() * counter) | 0

      # And swap the last element with it
      temp = array[counter]
      array[counter] = array[index]
      array[index] = temp
    array

  shuffle: ->
    positions = @entities().map((e) -> return [e.x, e.y])
    positions = @shuffle_array(positions)
    for p, i in positions
      @entities()[i].x = p[0]
      @entities()[i].y = p[1]
    @update_positions()

  has_positions: ->
    for e in @_data.entities
      return false unless e.x? and e.y?
    for r in @_data.rels
      return false unless r.source? and r.target?
      return false unless r.source.x? and r.source.y? and r.target.x? and r.target.y?
    true

  update_positions: ->
    t = this

    d3.selectAll(".entity").attr("transform", (d) -> "translate(" + d.x + "," + d.y + ")")
    d3.selectAll(".rel").attr("transform", (d) -> "translate(" + (d.source.x + d.target.x)/2 + "," + (d.source.y + d.target.y)/2 + ")")

    d3.selectAll(".line")
      .attr("d", (d) ->        
        dx = d.target.x - d.source.x
        dy = d.target.y - d.source.y 
        dr = Math.sqrt(dx * dx + dy * dy)

        ax = (d.source.x + d.target.x) / 2
        ay = (d.source.y + d.target.y) / 2

        if (d.source.x < d.target.x)
          xa = d.source.x - ax
          ya = d.source.y - ay
        else
          xa = d.target.x - ax
          ya = d.target.y - ay

        xb = -xa
        yb = -ya

        x1 = d.x1
        y1 = d.y1

        if t.default_rels or d.x1 == null or d.y1 == null
          if t.straight_rels
            x1 = 0
            y1 = 0
          else            
            if t.mode == 'circle'
              # CIRCLE WITH CURVES
              center = t.svg_center()
              n = 10/Math.sqrt(dr)
              xdir = Math.abs(ax - center.x) / (ax - center.x)
              ydir = Math.abs(ay - center.y) / (ay - center.y)
              x1 = -Math.abs(dy) * xdir * n
              y1 = -Math.abs(dx) * ydir * n
            else if t.mode == 'vertical'
              # VERTICAL WITH CURVES
              dir = if d.category_id == 1 then 1 else -1
              x1 = xa + dir * Math.abs(dy) * 0.67 # * (1 + Math.random()/2)
              y1 = ya
              x2 = xa + dir * Math.abs(dy) * 0.67 # * (1 + Math.random()/2)
              y2 = yb
            else if t.mode == 'vertical_cats'
              e1 = t.entity_by_id(d.entity1_id)
              e2 = t.entity_by_id(d.entity2_id)

              cats = [e1.cat, e2.cat].sort()

              if e1.cat == e2.cat
                dir = if d.category_id == 1 and e1.cat != 0 then 1 else -1
                x1 = xa + dir * Math.abs(dy) * 0.67 # * (1 + Math.random()/2)
                y1 = ya
                x2 = xb + dir * Math.abs(dy) * 0.67 # * (1 + Math.random()/2)
                y2 = yb
              else
                dir = if xb - xa > 0 then 1 else -1
                x1 = xa + dir * Math.abs(dx) * 0.5 # * (1 + Math.random()/2)
                y1 = ya
                x2 = xb - dir * Math.abs(dx) * 0.5 # * (1 + Math.random()/2)
                y2 = yb                

            else if t.mode == 'horizontal'
              # HORIZONTAL WITH CURVES
              dir = if d.category_id == 1 then -1 else 1
              y1 = ya + dir * Math.abs(dx) * 0.67 # * (1 + Math.random()/2)
              x1 = xa
              y2 = ya + dir * Math.abs(dx) * 0.67 # * (1 + Math.random()/2)
              x2 = xb
            else
              n = t.rel_curve_ratio(d)
              x1 = -ya * n
              y1 = xa * n

        spacing = 5
        node_radius1 = (25 * (if d.source.x >= d.target.x then d.target.scale else d.source.scale)) + spacing
        node_radius2 = (25 * (if d.source.x < d.target.x then d.target.scale else d.source.scale)) + spacing

        # offsets for markers
        dxm1 = xa - x1
        dym1 = ya - y1
        rm1 = Math.sqrt(dxm1 * dxm1 + dym1 * dym1)
        dxm2 = xb - x1
        dym2 = yb - y1
        rm2 = Math.sqrt(dxm2 * dxm2 + dym2 * dym2)
        xm1 = node_radius1 * dxm1 / rm1
        ym1 = node_radius1 * dym1 / rm1
        xm2 = node_radius2 * dxm2 / rm2
        ym2 = node_radius2 * dym2 / rm2

        if t.mode == 'vertical'
          # VERTICAL
          m = "M" + (xa + dir * node_radius1) + "," + ya
          c = "C" + (x1 + dir * node_radius1) + " " + y1 + "," + (x2 + dir * node_radius1) + " " + y2 + "," + (xb + dir * node_radius2) + "," + yb
          m + c        
        else if t.mode == 'vertical_cats'
          # VERTICAL CATS
          if e1.cat == e2.cat
            m = "M" + (xa + dir * node_radius1) + "," + ya
            c = "C" + (x1 + dir * node_radius1) + " " + y1 + "," + (x2 + dir * node_radius1) + " " + y2 + "," + (xb + dir * node_radius2) + "," + yb
            m + c            
          else
            m = "M" + (xa + dir * node_radius1) + "," + ya
            c = "C" + (x1 + dir * node_radius1) + " " + y1 + "," + (x2 - dir * node_radius1) + " " + y2 + "," + (xb - dir * node_radius2) + "," + yb
            m + c                      
        else if t.mode == 'horizontal'
          # HORIZONTAL
          m = "M" + xa + "," + (ya + dir * node_radius1)
          c = "C" + x1 + " " + (y1 + dir * node_radius1) + "," + x2 + " " + (y2 + dir * node_radius1) + "," + xb + "," + (yb + dir * node_radius2)
          m + c            
        else
          # NORMAL
          m = "M" + (xa - xm1) + "," + (ya - ym1)
          q = "Q" + x1 + "," + y1 + "," + (xb - xm2) + "," + (yb - ym2)
          m + q
      )

    d3.selectAll('.text text')
      .attr('x', (d) -> d.x)
      .attr('y', (d) -> d.y)

    @update_rel_is_directionals()

  use_force: ->
    for e, i in @_data.entities
      delete @_data.entities[i]["fixed"]
    for r, j in @_data.rels
      @_data.rels[j]["x1"] = null
      @_data.rels[j]["y1"] = null
    @force_enabled = true
    @force = d3.layout.force()
      .gravity(@gravity)
      .distance(@distance)
      .charge(@charge)
      .friction(0.7)
      .size([0, 0])
      .nodes(@_data.entities, (d) -> return d.id)
      .links(@_data.rels, (d) -> return d.id)
      .start()
    t = this
    @force.on("tick", () ->
      t.update_positions()
    )
    @force.alpha(@alpha) if @alpha? && @alpha > 0

  one_time_force: ->
    @deny_force() if @force_enabled
    @use_force()
    @force.alpha(0.3)
    t = this
    @force.on("end", -> t.force_enabled = false)

  deny_force: ->
    @force_enabled = false
    @alpha = @force.alpha()
    @force.stop()

  n_force_ticks: (n) ->
    @use_force()
    for [1..n]
      @force.tick()
    @deny_force()

  build: ->
    @build_rels()
    @build_entities()
    @build_texts()
    @entities_on_top()
    @update_positions() if @has_positions()

  remove_orphaned_rels: ->
    entity_ids = @_data.entities.map((e) -> e.id)
    rel_ids = (rel.id for rel, i in @_data.rels when entity_ids.indexOf(rel.entity1_id) == -1 or entity_ids.indexOf(rel.entity2_id) == -1)
    for id in rel_ids
      @remove_rel(id)
        
  build_rels: ->
    t = this
    zoom = d3.select("#zoom")

    # rels are made of groups of parts...
    rels = zoom.selectAll(".rel")
      .data(@_data["rels"], (d) -> return d.id)

    rel_drag = d3.behavior.drag()
      .on("dragstart", (d, i) ->
        t.alpha = t.force.alpha() if t.force_enabled
        t.force.stop() if t.force_enabled
        t.drag = false
        d3.event.sourceEvent.preventDefault()
        d3.event.sourceEvent.stopPropagation()
      )
      .on("drag", (d, i) -> 
        d.x1 += d3.event.dx
        d.y1 += d3.event.dy
        t.update_positions()
        t.drag = true
      )
      .on("dragend", (d, i) ->
        d.fixed = true
        t.force.alpha(t.alpha) if t.force_enabled
      )

    groups = rels.enter().append("g")
      .attr("class", "rel")
      .attr("id", (d) -> "rel-" + d.id)
      .call(rel_drag)

    rels.exit().remove()

    @build_rel_paths()
    @update_rel_is_currents()

    # hide hidden rels
    rels.style("display", (d) -> if d.hidden == true then "none" else null)

    # ensure lines and anchors and text also receive new data
    @svg.selectAll(".rel .line")
      .data(@_data["rels"], (d) -> return d.id)
    @svg.selectAll(".rel a")
      .data(@_data["rels"], (d) -> return d.id)
    @svg.selectAll(".rel text")
      .data(@_data["rels"], (d) -> return d.id)
    @svg.selectAll(".rel textpath")
      .data(@_data["rels"], (d) -> return d.id)
    
    @svg.selectAll(".rel").on("click", (d, i) ->
      $(this).insertAfter($('.rel').last())
      t.toggle_selected_rel(d.id) unless t.drag
      $(window).trigger('selection', this)
    )

  build_rel_paths: ->
    t = this
    groups = @svg.selectAll('g.rel')

    # remove existing paths, links, etc
    $('.rel path.line').remove()
    $('.rel a').remove()
    $('.rel text.label').remove()
    $('.rel .labelpath').remove()

    # transparent thick path for dragging
    groups.append("path")
      .attr("id", (d) -> "path-bg-" + d.id)
      .attr("class", "line bg")
      .attr("opacity", 0)
      .attr("stroke", "white")
      .attr("stroke-width", 20)

    # yellow path for highlighting
    groups.append("path")
      .attr("id", (d) -> "path-highlight-" + d.id)
      .attr("class", "line highlight")
      .attr("opacity", 0.6)
      .attr("fill", "none")
      .attr("stroke", (d) -> if d.color then d.color else '#ffff80')
      .style("stroke-width", (d) -> 4 * d.scale)

    # main path
    paths = groups.append("path")
      .attr("id", (d) -> "path-" + d.id)
      .attr("class", "line")
      .attr("opacity", (d) -> if d.opacity then d.opacity else 0.6)
      .attr("fill", "none")
      .attr("fill", (d) -> if d.fill_color then d.fill_color else "none")
      .attr("fill-opacity", (d) -> if d.fill_opacity then d.fill_opacity else 0)
      .attr("stroke", (d) -> if d.color then d.color else '#000')
      .style("stroke-width", (d) -> d.scale)

    # anchor tags around category labels
    groups.append("a")
      .attr("xlink:href", (d) -> d.url)
      .append("text")
      .attr("class", "label")
      .attr("dy", (d) -> -6 * Math.sqrt(d.scale))
      .attr("text-anchor", "middle")
      .append("textPath")
      .attr("class", "labelpath")
      .attr("startOffset", "50%")
      .attr("xlink:href", (d) -> 
        "#path-" + d.id
      )
      .attr("font-size", (d) -> 10 * Math.sqrt(d.scale))
      .text((d) -> d.label)

  toggle_selected_rel: (id, value = null, deselect_all = true) ->
    t = this
    rel = d3.select("#rel-" + id + ".rel")

    rel.classed("selected", (d, i) ->
      if value == true or value == false
        t.deselect_all() if deselect_all
        return value
      else
        value = !rel.classed("selected")
        t.deselect_all() if deselect_all
        return value
    )

  toggle_hovered_rel: (id, value = null) ->
    rel = d3.select("#rel-" + id + ".rel")
    rel.classed("hovered", value)

  has_image: (d) -> 
    !d.hide_image and d.image and d.image.indexOf("netmap") == -1

  build_entities: ->
    t = this
    zoom = d3.selectAll("#zoom")

    entity_drag = d3.behavior.drag()
      .on("dragstart", (d, i) ->
        t.alpha = t.force.alpha() if t.force_enabled
        t.force.stop() if t.force_enabled
        t.drag = false
        d3.event.sourceEvent.preventDefault()
        d3.event.sourceEvent.stopPropagation()
      )
      .on("drag", (d, i) ->
        d.x += d3.event.dx
        d.y += d3.event.dy

        t.update_positions()
        t.drag = true
      )
      .on("dragend", (d, i) -> 
        t.update_positions() if t.is_ie()
        d.fixed = true
        t.force.alpha(t.alpha) if t.force_enabled
      )

    # entities are made of groups of parts...
    entities = zoom.selectAll(".entity")
      .data(@_data["entities"], (d) -> return d.id)
    
    groups = entities.enter().append("g")
      .attr("class", "entity")
      .attr("id", (d) -> 'entity-' + d.id)
      .call(entity_drag)
      .on("mouseover", (d) ->
        t.toggle_selected_entity(d.id, true) unless t.mode == 'default'

        for r in t.rels_by_entity(d.id)
          if t.mode == 'default'
            t.toggle_hovered_rel(r.id, true)
          else
            # t.toggle_selected_rel(r.id, true, false)
      )
      .on("mouseout", (d) ->
        t.toggle_selected_entity(d.id, true) unless t.mode == 'default'

        for r in t.rels_by_entity(d.id)
          if t.mode == 'default'
            t.toggle_hovered_rel(r.id, false)
          else
            # t.toggle_selected_rel(r.id, false, false)
      )

    # background for add related entities button
    # unless @clean_mode
    #   groups.append("rect")
    #     .attr("class", "add_button_rect")
    #     .attr("fill", "#fff")
    #     .attr("opacity", 0.5)
    #     .attr("width", 18)
    #     .attr("height", 18)
    #     .attr("x", (d) -> 15 * d.scale)
    #     .attr("y", (d) -> -28 * d.scale)
    #     .attr("rx", 5)
    #     .attr("ry", 5)    

    # add related entities button and background squares
    # unless @clean_mode
    #   buttons = groups.append("a")
    #     .attr("class", "add_button")
    #   buttons.append("text")
    #     .attr("dx", (d) -> 20 * d.scale)
    #     .attr("dy", (d) -> -15 * d.scale)
    #     .text("+")
    #     .on("click", (d) ->
    #       t.toggle_add_related_entities_form(d.id)
    #     )      

    entities.exit().remove()

    @build_entity_images()
    @build_entity_labels()

    @svg.selectAll(".entity").on("click", (d, i) ->
      # bring entity to top
      $('#zoom').append(this)      

      t.toggle_selected_entity(d.id) unless t.drag or t.mode != 'default'
      $(window).trigger('selection', this) unless t.drag or t.mode != 'default'

      # bring connected rels to top
      for r in t.rels_by_entity(d.id)
        $("#rel-" + r.id).insertAfter($('.rel').last())
    )

    @svg.selectAll(".entity a").on("click", (d, i) ->
      d3.event.stopPropagation()
    )

  build_entity_images: ->
    t = this
    groups = @svg.selectAll('g.entity')

    # remove existing links, texts, rects
    $('.entity circle.image-bg').remove()
    $('.entity .image-clippath').remove()
    $('.entity image.image').remove()

    # circle for background and highlighting
    bgs = groups.append("circle")
      .attr("class", (d) -> if (d.image and !t.hide_images) then "image-bg" else "image-bg custom")
      .attr("opacity", 1)
      .attr("r", (d) -> 25 * d.scale)
      .attr("x", (d) -> -29 * d.scale)
      .attr("y", (d) -> -29 * d.scale)
      .attr("stroke", "white")
      .attr("stroke-width", (d) -> 7 * d.scale)
      .attr("stroke-opacity", 0)

    if t.hide_images
      bgs.style("fill", (d, i) -> 
        if d.color?
          d.color
        else
          '#444'
      )

    # circle for clipping image
    groups.append("clipPath")
      .attr("id", (d) -> "image-clip-" + d.id)
      .attr("class", "image-clippath")
      .append("circle")
      .attr("class", "image-clip")
      .attr("opacity", 1)
      .attr("r", (d) -> 25 * d.scale)
      .attr("x", (d) -> -29 * d.scale)
      .attr("y", (d) -> -29 * d.scale)

    # profile image or default silhouette
    groups.filter((d) -> d.image)
      .append("image")
      .attr("class", "image")
      .attr("xlink:href", (d) -> t.image_for_entity(d))
      .attr("x", (d) -> if t.has_image(d) then -40 * d.scale else -25 * d.scale)
      .attr("y", (d) -> if t.has_image(d) then -40 * d.scale else -25 * d.scale)
      .attr("width", (d) -> if t.has_image(d) then (80 * d.scale) else (50 * d.scale))
      .attr("height", (d) -> if t.has_image(d) then (80 * d.scale) else (50 * d.scale))
      .attr("clip-path", (d) -> "url(#image-clip-" + d.id + ")" )    

  build_entity_labels: ->
    t = this
    groups = @svg.selectAll('g.entity')

    # remove existing links, texts, rects
    $('.entity a.entity_link').remove()
    $('.entity rect.text_rect').remove()

    # anchor tags around entity name
    if t.entity_links
      links = groups.append("a")
        .attr("class", "entity_link")
        .attr("xlink:href", (d) -> d.url)
        .attr("title", (d) -> d.description)
      text = links.append("text")
    else
      text = groups.append("text")


    text.attr("class", "entitylabel1")
        .attr("dx", 0)
        .attr("text-anchor", "middle")

    if t.hide_images
      text.attr("dy", (d) -> if t.split_name(d.name, 12)[1].length == 0 then (3 * d.scale) else 0)
          .attr("font-size", (d) -> 8 * d.scale)      
          .text((d) -> t.split_name(d.name, 12)[0])
    else
      text.attr("dy", (d) -> 42 * d.scale) # (d) -> if t.has_image(d) then 40 else 25)
          .attr("font-size", (d) -> 12 * d.scale)
          .text((d) -> t.split_name(d.name)[0])

    if t.entity_links
      text = links.append("text")
    else
      text = groups.append("text")

    text.attr("class", "entitylabel2")
      .attr("dx", 0)
      .attr("text-anchor", "middle")

    if t.hide_images
      text.attr("dy", (d) -> 9 * d.scale)
          .attr("font-size", (d) -> 8 * d.scale)
          .text((d) -> t.split_name(d.name, 12)[1])
    else
      text.attr("dy", (d) -> 59 * d.scale) # (d) -> if t.has_image(d) then 55 else 40)
          .attr("font-size", (d) -> 12 * d.scale)
          .text((d) -> t.split_name(d.name)[1])

    # one or two rectangles behind the entity name
    unless t.hide_images
      groups.filter((d) -> t.split_name(d.name)[0] != d.name)
        .insert("rect", ":first-child")
        .attr("class", "text_rect")
        .attr("fill", @entity_background_color)
        .attr("opacity", @entity_background_opacity)
        .attr("rx", @entity_background_corner_radius)
        .attr("ry", @entity_background_corner_radius)
        .attr("x", (d) -> 
          -$(this.parentNode).find(".entity_link text:nth-child(2)")[0].getBBox().width/2 - 3
        )
        .attr("y", (d) ->
          image_offset = 28
          text_offset = $(this.parentNode).find(".entity_link text")[0].getBBox().height
          extra_offset = 5 # if t.has_image(d) then 2 else -5
          (image_offset + extra_offset) * d.scale + text_offset
        )
        .attr("width", (d) -> $(this.parentNode).find(".entity_link text:nth-child(2)")[0].getBBox().width + 6)
        .attr("height", (d) -> $(this.parentNode).find(".entity_link text:nth-child(2)")[0].getBBox().height + 4)

      groups.insert("rect", ":first-child")
        .attr("class", "text_rect")
        .attr("fill", @entity_background_color)
        .attr("opacity", @entity_background_opacity)
        .attr("rx", @entity_background_corner_radius)
        .attr("ry", @entity_background_corner_radius)
        .attr("x", (d) ->
          -$(this.parentNode).find(".entity_link text")[0].getBBox().width/2 - 3
        )
        .attr("y", (d) ->
          image_offset = 28
          extra_offset = 1 # if t.has_image(d) then 1 else -6
          (image_offset + extra_offset) * d.scale
        )
        .attr("width", (d) -> $(this.parentNode).find(".entity_link text")[0].getBBox().width + 6)
        .attr("height", (d) -> $(this.parentNode).find(".entity_link text")[0].getBBox().height + 4)    

  last_entity_id: ->
    elems = document.querySelectorAll('#zoom g.entity')
    elem = elems[elems.length - 1]
    return null unless elem
    elem.id

  toggle_selected_entity: (id, toggle_connected_entities = false) ->
    g = $("#entity-" + id + ".entity")
    klass = if g.attr("class") == "entity" then "entity selected" else "entity"
    @deselect_all()
    g.attr("class", klass)
    
    # toggle selection for entity's relationships
    selected = (g.attr("class") == "entity selected")
    for r in @rels_by_entity(id)
      @toggle_selected_rel(r.id, selected, false)
      if toggle_connected_entities
        c = $("#entity-" + @other_entity_id(r, id) + ".entity")
        # klass = if c.attr("class") == "entity" then "entity selected" else "entity"
        # c.attr("class", klass)

  entities_on_top: ->
    zoom = $("#zoom")
    $("g.rel").each((i, g) -> $(g).prependTo(zoom))
    $("#bg").prependTo(zoom);

  split_name: (name, min_length = 16) ->
    return ["", ""] unless name?

    name = name.trim()

    # return whole name if name too short
    return [name, ""] if name.length < min_length

    # look for space between 1/2 - 2/3 of string
    i = name.indexOf(" ", Math.floor(name.length * 1/2))
    if i > -1 && i <= Math.floor(name.length * 2/3)
      return [name.substring(0, i), name.substring(i+1)]
    else
      # look for space between 1/3 - 1/2 of string
      i = name.lastIndexOf(" ", Math.ceil(name.length/2))
      if i >= Math.floor(name.lenth * 1/3)
        return [name.substring(0, i), name.substring(i+1)]                

    # split on the middle space
    parts = name.split(/\s+/)
    half = Math.ceil(parts.length / 2)
    [parts.slice(0, half).join(" "), parts.slice(half).join(" ")]

  rel_is_directional: (r) ->
    return true if r.is_directional == true
    return true if r.is_directional == 1
    return false if r.is_directional == false
    return false if r.is_directional == 0
    r.category_ids.map((cat_id) ->
      [1, 2, 3, 5, 10].indexOf(cat_id)
    ).indexOf(-1) == -1

  centered_coordinates: ->
    return true if @entities().length == 0
    center = @compute_graph_center()
    center.x < 200 and center.y < 200

  update_rel_labels: ->
    @svg.selectAll(".labelpath")
      .text((d) -> d.label)

  update_rel_is_currents: ->
    t = this
    d3.selectAll(".line:not(.highlight):not(.bg)")
      .style("stroke-dasharray", (d) ->
        return if (!t.current_rels and (d.is_current == 0 || d.is_current == null || d.end_date)) then "5,2" else ""
      )

  update_rel_is_directionals: ->
    t = this

    # SAVES IE FROM BREAKING?
    if @is_ie()
      d3.selectAll(".line:not(.highlight)").each(-> this.parentNode.insertBefore(this, this))

    unless t.mode == 'vertical_cats'
      d3.selectAll(".line:not(.highlight)")
        .attr("marker-end", (d) -> 
          if (t.rel_is_directional(d) and d.source.x < d.target.x) then "url(#marker1)" else ""
        )
        .attr("marker-start", (d) -> 
          if (t.rel_is_directional(d) and d.source.x >= d.target.x) then "url(#marker2)" else ""
        )

  set_rel_label: (id, label) ->
    rel = @rel_by_id(id)

    if rel
      rel.label = label
      @update_rel_labels()
    else
      false

  set_rel_is_current: (id, value) ->
    rel = @rel_by_id(id)

    if rel
      rel.is_current = value
      @update_rel_is_currents()
    else
      false

  set_rel_is_directional: (id, value) ->
    rel = @rel_by_id(id)

    if rel
      rel.is_directional = value
      @update_rel_is_directionals()
    else
      false

  set_rel_scale: (id, value) ->
    rel = @rel_by_id(id)

    if rel
      rel.scale = value
      @build_rels()
      @update_positions()
    else
      false

  selected_rel_id: ->
    data = d3.selectAll($(".rel.selected")).data()
    return false if data.length != 1
    data[0].id

  get_selected_rel_label: ->
    @rel_by_id(@selected_rel_id()).label

  set_selected_rel_label: (label) ->
    @set_rel_label(@selected_rel_id(), label)

  selected_rel_is_current: ->
    !!@rel_by_id(@selected_rel_id()).is_current

  set_selected_rel_is_current: (value) ->
    @set_rel_is_current(@selected_rel_id(), value)

  selected_rel_is_directional: ->
    @rel_is_directional(@rel_by_id(@selected_rel_id()))

  set_selected_rel_is_directional: (value) ->
    @set_rel_is_directional(@selected_rel_id(), value)

  get_selected_rel_scale: ->
    @rel_by_id(@selected_rel_id()).scale

  set_selected_rel_scale: (value) ->
    @set_rel_scale(@selected_rel_id(), value)

  update_entity_labels: ->
    t = this
    @svg.selectAll(".entitylabel1")
      .text((d) -> t.split_name(d.name)[0])
    @svg.selectAll(".entitylabel2")
      .text((d) -> t.split_name(d.name)[1])

  update_entity_images: ->
    t = this
    @svg.selectAll('.image')
      .attr("xlink:href", (d) -> t.image_for_entity(d))
      .attr("x", (d) -> if t.has_image(d) then -40 * d.scale else -25 * d.scale)
      .attr("y", (d) -> if t.has_image(d) then -40 * d.scale else -25 * d.scale)
      .attr("width", (d) -> if t.has_image(d) then 80 * d.scale else 50 * d.scale)
      .attr("height", (d) -> if t.has_image(d) then 80 * d.scale else 50 * d.scale)

  set_entity_label: (id, label) ->
    entity = @entity_by_id(id)

    if entity?
      entity.name = label
      @build_entity_labels()
    else
      false

  set_entity_hide_image: (id, value) ->
    entity = @entity_by_id(id)

    if entity
      entity.hide_image = value
      @update_entity_images()
    else
      false

  set_entity_scale: (id, value) ->
    entity = @entity_by_id(id)

    if entity
      entity.scale = value
      @build()
      d3.selectAll(".entity image").each(-> this.parentNode.insertBefore(this, this))
    else
      false

  selected_entity_id: ->
    data = d3.selectAll($(".entity.selected")).data()
    return false if data.length != 1
    data[0].id

  get_selected_entity: ->
    @entity_by_id(@selected_entity_id())    

  get_selected_entity_label: ->
    @get_selected_entity().name

  get_selected_entity_scale: ->
    @get_selected_entity().scale

  set_selected_entity_label: (label) ->
    @set_entity_label(@selected_entity_id(), label)

  set_selected_entity_hide_image: (value) ->
    @set_entity_hide_image(@selected_entity_id(), value)

  set_selected_entity_scale: (value) ->
    @set_entity_scale(@selected_entity_id(), value)

  selected_text_id: ->
    data = d3.selectAll($(".text.selected")).data()
    return false if data.length != 1
    data[0].id

  get_selected_text_content: ->
    i = @selected_text_id()
    return false if i == false
    @text_by_id(i).text

  set_selected_text_content: (content) ->
    @set_text_content(@selected_text_id(), content)

  set_text_content: (id, content) ->
    text = @text_by_id(id)

    if text?
      text.text = content
      @update_text_contents()
    else
      false

  update_text_contents: ->
    @svg.selectAll(".text text")
      .text((d) -> d.text)

  deselect_all: ->
    @svg.selectAll('.selected').classed('selected', false)

  build_texts: ->
    t = this
    zoom = d3.selectAll("#zoom")

    # texts are made of groups of parts...
    texts = zoom.selectAll(".text")
      .data(@_data["texts"], (d) -> return d.id)

    text_drag = d3.behavior.drag()
      .on("dragstart", (d, i) ->
        t.drag = false
        d3.event.sourceEvent.preventDefault()
        d3.event.sourceEvent.stopPropagation()
      )
      .on("drag", (d, i) ->
        d.x += d3.event.dx
        d.y += d3.event.dy

        t.update_positions()
        t.drag = true
      )
    
    groups = texts.enter().append("g")
      .attr('id', (d, i) -> 'text-' + d.id)
      .attr("class", "text")
      .call(text_drag)

    groups.append("text")
      .attr('fill', '#888')
      .attr('x', (d) -> d.x)
      .attr('y', (d) -> d.y)
      .text((d) -> d.text)

    @svg.selectAll(".text").on("click", (d, i) ->
      t.toggle_selected_text(d.id) unless t.drag
      $(window).trigger('selection', this) unless t.drag
    )

    texts.exit().remove()

  add_text: (text, x, y) ->
    @_data["texts"].push({
      'text': text,
      'x': x,
      'y': y,
      id: @next_text_id()
    })
    @build_texts()

  next_text_id: ->
    ids = @data().texts.map((t) -> t.id)
    return 1 if ids.length == 0
    Math.max.apply(null, ids) + 1

  ensure_text_ids: ->
    t = this
    @data().texts.forEach((text) ->
      text.id = t.next_text_id() if text.id == null
    )

  toggle_selected_text: (id) ->
    g = $("#text-" + id)
    klass = if g.attr("class") == "text" then "text selected" else "text"
    @deselect_all()
    g.attr("class", klass)    

  text_index: (id) ->
    for t, i in @data().texts
      return i if parseInt(t.id) == parseInt(id)

  text_by_id: (id) ->
    for t, i in @data().texts
      return t if parseInt(t.id) == parseInt(id)

  remove_text: (id) ->
    @_data.texts.splice(@text_index(id), 1)

  image_for_entity: (e) ->
    if @hide_images
      null
    else if e.hide_image
      if e.type == 'Person'
        'http://littlesis.s3.amazonaws.com/images/system/netmap-person.png'
      else if e.type == 'Org'
        'http://littlesis.s3.amazonaws.com/images/system/netmap-org.png'
      else
        null
    else
      e.image

  next_custom_node_id: ->
    ids = @data().entities.map((e) -> e.id.toString()).filter((id) -> id.indexOf("x") == 0)
    return "x1" if ids.length == 0
    nums = ids.map((id) -> parseInt(id.slice(1)))
    max = Math.max.apply(null, nums)
    "x" + (max + 1)

  next_custom_rel_id: ->
    ids = @data().rels.map((r) -> r.id.toString()).filter((id) -> id.indexOf("x") == 0)
    return "x1" if ids.length == 0
    nums = ids.map((id) -> parseInt(id.slice(1)))
    max = Math.max.apply(null, nums)
    "x" + (max + 1)

  add_node: (name, x, y, type = null, url = null) ->
    @data().entities.push({ 
      id: @next_custom_node_id()
      name: name,
      x: x,
      y: y,
      type: type,
      url: url,
      image: null,
      hide_image: true,
      custom: true,
      scale: 1
    })
    @build()

  add_edge: (entity1_id, entity2_id, label, category_id = null, is_current = 1, is_directional = false, url = null) ->
    if entity1_id.toString().match(/^\d+$/)
      entity1_id = parseInt(entity1_id)

    if entity2_id.toString().match(/^\d+$/)
      entity2_id = parseInt(entity2_id)

    category_id = null unless category_id

    @data().rels.push({
      id: @next_custom_rel_id(),
      entity1_id: entity1_id,
      entity2_id, entity2_id,
      label: label,
      category_id: category_id,
      category_ids: (if category_id then [category_id] else []),
      is_current: parseInt(is_current),
      end_date: null,
      value: 1,
      url: url,
      custom: true,
      is_directional: is_directional
    })
    @prepare_entities_and_rels()
    @build()

  entity_options_for_select: ->
    @data().entities.map((e) -> [e.id, e.name])

  is_ie: ->
    window.navigator.userAgent.indexOf("MSIE") != -1 or window.navigator.userAgent.indexOf("Trident") != -1

  limit_entities: (num = 20) ->
    @_data.entities = data.entities.slice(0, num)
    @remove_orphaned_rels()

  shuffle_entities: ->
    @_data.entities = @shuffle_array(@_data.entities)

  random_color: ->
    letters = '0123456789ABCDEF'.split('')
    color = '#'
    for i in [0..5]
      color += letters[Math.floor(Math.random() * 16)]
    color

  other_entity_id: (r, id) ->
    if r.entity1_id.toString() == id.toString() then r.entity2_id else r.entity1_id

if typeof module != "undefined" && module.exports
  # on a server
  exports.Netmap = Netmap
else
  # on a client
  window.Netmap = Netmap
