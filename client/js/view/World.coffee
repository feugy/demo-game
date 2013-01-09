define [
  'underscore'
  'jquery'
  'backbone'
  'i18n!nls/common'
  'text!template/world.html'
  'utils/common'
  'model/Map'
  'model/Field'
  'model/Item'
  'model/Event'
  'widget/mapRenderers'
  'widget/propertyDisplay'
  'widget/propertyEdit'
], (_, $, Backbone, i18n, template, utils, Map, Field, Item, Event, Renderers) ->

  # defaults rendering dimensions
  renderDefaults = 
    hexagon:
      tileDim: 75
      verticalTileNum: 14
      horizontalTileNum: 12
      angle: 45
    diamond:
      tileDim: 75
      verticalTileNum: 13
      horizontalTileNum: 15
      angle: 45
    square:
      tileDim: 75
      verticalTileNum: 8
      horizontalTileNum: 11
      angle: 0
      
  # Display the player's map 
  class WorldView extends Backbone.View
  
    events:
      'click .rule-menu a': '_onTriggerRule'
          
    # used for rendering
    i18n: i18n
    
    # currently displayed map
    map: null
        
    # **private**
    # mustache template rendered
    _template: template
    
    # **private**
    # widget that displays current map
    _mapWidget: null
    
    # **private**
    # associative array of event widgets awaiting for rules resolution
    _pendingWidget: {}
    
    # The view constructor.
    #
    # @param form [Object] login form already present inside DOM to attach inside template
    constructor: (@_form) ->
      super tagName: 'div', className:'world view'
      @_pendingWidget = {}
      
      # register on fields and items to update map
      @bindTo Field.collection, 'add', (added) =>
        @_mapWidget?.addData unless Array.isArray added then [added] else added
      @bindTo Field.collection, 'remove', (removed) =>
        @_mapWidget?.removeData unless Array.isArray removed then [removed] else removed
      @bindTo Item.collection, 'add update', (added) =>
        @_mapWidget?.addData unless Array.isArray added then [added] else added
      @bindTo Item.collection, 'remove', (removed) =>
        @_mapWidget?.removeData unless Array.isArray removed then [removed] else removed
        
      @bindTo app.router, 'resize', @_onResize
      @bindTo app.router, 'rulesResolved', @_onRuleResolved
      @bindTo app.router, 'key', @_onKey
      
    # the render method, which use the specified template
    render: =>
      super()
      @_mapWidget = @$('.map').mapWidget(
        displayGrid: false
        displayMarkers: false
        displayHover: true
        lowerCoord: x:0, y: 0
      ).on('mapClicked', (event, details) =>
          return unless @character
          # trigger rule resolution
          app.router.trigger 'resolveRules', @character.id, details.field.x, details.field.y if details.field?
      ).on('coordChanged', =>
          # reload map content
          @map?.consult @_mapWidget.options.lowerCoord, @_mapWidget.options.upperCoord
      ).data 'mapWidget'
      
      # initialize current map to player's map
      @character = app.player?.characters?[0]
      @map = @character?.map
      return @ unless @map?
      
      # Display player name
      @$('.name').html @character.name
      
      if @map.get('kind') of Renderers
        renderer =  new Renderers[@map.kind]() 
        @_mapWidget.options[key] = val for key, val of renderDefaults[@map.kind]
        @_mapWidget.setOption 'renderer', renderer
      else 
        console.error "unsupported map kind: #{@map.kind}"
      @_mapWidget.setOption 'mapId', @map.id
      
      # adds a property to display message log
      @$('.events .list').propertyDisplay(
        model: @character
        path: 'messages'
        kind: 'array'
      ).on('executeRule', (event, details) =>
        # trigger rule execution
        app.router.trigger 'executeRule', details.rule, @character.id, details.target.id, details.params or {}
      ).on 'resolveRules', (event, widget) =>
        # trigger rule resolution
        @_pendingWidget[widget.options.model.id] = widget
        app.router.trigger 'resolveRules', @character.id, widget.options.model.id
      
      # adds a property to display player energy
      @$('.energy .value').propertyDisplay
        model: @character
        path: 'energy'
        kind: 'float'
        
      # focus on view to handle keys
      _.defer => 
        @_onResize()
        @$el.focus()
      
      # for chaining purposes
      @
      
    # **private**
    # Size the map to fit the displayable area
    _onResize: =>
      main = $('#main')
      viewPort = 
        w: main.innerWidth()
        h: main.innerHeight()
      
      dim =
        w: @_mapWidget.$el.outerWidth()
        h: @_mapWidget.$el.outerHeight()
        
      css = {}
      if viewPort.h/dim.h > viewPort.w/dim.w
        # center vertically and takes all width
        css.scale = viewPort.w/dim.w
        css.marginTop = (viewPort.h - dim.h*css.scale)/2
        css.marginLeft = 0
      else
        # center horizontally and takes all height
        css.scale = viewPort.h/dim.h
        css.marginLeft = (viewPort.w - dim.w*css.scale)/2
        css.marginTop = 0
        
      @_mapWidget.$el.transition css, 0
      
    # **private**
    # Rule resolution handler: display a dropdown menu with relevant targets and
    # action.
    #
    # @param args [Object] resolution arguments: playerId or actorId + targetId 
    # or actorId + x + y
    # @params rules [Object] applicable rules: an associated array with rule names id as key, and
    # as value an array containing for each concerned target:
    # @options rules target [Object] the target
    # @options rules params [Object] the awaited parameters specification
    # @options rules category/rule [String/Object] the rule category, or the whole role (wholeRule is true)
    _onRuleResolved: (args, rules) =>
      # remove previous menus
      @$('.rule-menu').remove()
      return if _.keys(rules).length is 0
      
      # handle event requests
      if args.targetId? and args.targetId of @_pendingWidget
        @_pendingWidget[args.targetId].setRules rules
        delete @_pendingWidget[args.targetId]
        return
      
      # display a dropdown menu
      menu = $('<ul class="dropdown-menu"></ul>')
      for name, applicables of rules
        targetMenu = $('<ul class="dropdown-menu"></ul>')
        $("<li class='dropdown-submenu'><a href='#'>#{name}</a></li>").append(targetMenu).appendTo menu
        for applicable in applicables
          # retrieve target model
          link = $("<a class='trigger' href='#'>#{utils.instanceName applicable.target}</a>").data
            target: applicable.target.id
            rule: name
            params: applicable.params
          $('<li></li>').append(link).appendTo targetMenu
      
      # get the target position
      position = null
      if args.targetId?
        # center menu above target widget
        targetWidget = @_mapWidget.getItem Item.collection.get args.targetId
        if targetWidget?
          position = targetWidget.$el.offset()
          position.top += targetWidget.$el.height()/2
          position.left += targetWidget.$el.width()/2
      else if args.x? and args.y?
        # get position of the corresponding map coordinates
        position = @_mapWidget.coordOffset args
        position.top += @_mapWidget.options.tileDim/2
        position.left += @_mapWidget.options.tileDim/2
          
      return unless position?
      
      absPos = @$el.offset()
      # positionnate menu above the actor widget
      $('<div class="open rule-menu"></div>').append(menu).appendTo(@$el).css 
        top: position.top - absPos.top
        left: position.left - absPos.left
      
    # **private**
    # Trigger the corresponding rule on given target when clicking inside the
    # rule menu.
    #
    # @param event [Event] cancelled click event
    _onTriggerRule: (event) =>
      event?.preventDefault()
      trigger = $(event?.target).closest('.trigger').data()
      return unless trigger? and !_.isEmpty trigger
      # remove previous menus
      @$('.rule-menu').remove()
      # if parameter found, display popup to get them
      if trigger.params? and trigger.params.length > 0
        popup = $("""<div class="modal hide fade">
            <div class="modal-header">
              <button type="button" data-dismiss="modal" class="close">&times;</button>
              <h3>#{trigger.rule}</h3>
            </div>
            <form class="modal-body form-horizontal"></form>
            <div class="modal-footer">
              <a href="#" class="btn btn-primary">#{i18n.buttons.ok}</a>
            </div>
          </div>""")
          
        container = popup.find '.modal-body'
        for param in trigger.params when param.name? and param.type?
          group = $("""<div class="control-group">
            <label class="control-label">#{param.label or param.name}</label>
          </div>""").appendTo(container)
          # creates a property widget per parameters
          $("<div class='controls' data-name='#{param.name}'></div>").propertyEdit(
            type: param.type.toLowerCase()
          ).appendTo group
          
        popup.modal().on('hidden', -> 
          popup.off().remove()
        ).on 'click', 'a', (event) =>
          event?.preventDefault()
          params = {}
          properties = popup.find '[data-name]'
          # extract values for each property
          for property in properties
            params[$(property).data 'name'] = $(property).data('propertyEdit').options.value
          # trigger rule execution with parameters
          app.router.trigger 'executeRule', trigger.rule, @character.id, trigger.target, params
          popup.modal 'hide'
      else
        # trigger rule execution without parameters
        app.router.trigger 'executeRule', trigger.rule, @character.id, trigger.target, {}
    
    # **private** **specific**
    # Bounds move action on keys
    #
    # @param event [Event] key event
    _onKey: (event) =>
      coord = null
      bash = false
      # take in account left, up, right and down arrows, as well as space bar
      switch event.keyCode
        when 37 then coord = x:@character.x-1, y:@character.y
        when 38 then coord = x:@character.x, y:@character.y+1
        when 39 then coord = x:@character.x+1, y:@character.y
        when 40 then coord = x:@character.x, y:@character.y-1
        when 32 then bash = $(event.target).closest('input, select, textarea, a, button').length is 0
      
      # try to bash nearest opponent
      if bash
        target = null
        # find first target near the actor, and not the actor
        for candidate in Item.collection.where map: @character.map when candidate.x in [@character.x-1..@character.x+1] and candidate.y in [@character.y-1..@character.y+1] and !@character.equals candidate
          target = candidate
          break
        app.router.trigger 'executeRule', 'Attaquer', @character.id, target.id, {} if target?
        return 
        
      # if we have coordinate, get the relevant target
      return unless coord?
      target = @_mapWidget.getField coord
      return unless target?
      # execute the action
      app.router.trigger 'executeRule', 'Déplacement', @character.id, target._id, {}