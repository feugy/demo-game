'use strict'

define [
  'underscore'
  'jquery'
  'backbone'
  'i18n!nls/common'
  'model/Map'
  'model/Field'
  'model/Item'
  'widget/mapRenderers'
], (_, $, Backbone, i18n, Map, Field, Item, Renderers) ->

  # defaults rendering dimensions
  renderDefaults = 
    hexagon:
      tileDim: 75
      verticalTileNum: 14
      horizontalTileNum: 8
      angle: 45
    diamond:
      tileDim: 75
      verticalTileNum: 11
      horizontalTileNum: 8
      angle: 45
    square:
      tileDim: 75
      verticalTileNum: 8
      horizontalTileNum: 8
      angle: 0
      
  # Display the player's map 
  class MapView extends Backbone.View
  
    # currently displayed map
    map: null
    
    # **private**
    # widget that displays current map
    _mapWidget: null
    
    # The view constructor.
    #
    # @param form [Object] login form already present inside DOM to attach inside template
    constructor: (@_form) ->
      super tagName: 'div', className:'map-view'
      
      # register on fields and items to update map
      @bindTo Field.collection, 'add', (added) =>
        @_mapWidget?.addData unless Array.isArray added then [added] else added
      @bindTo Field.collection, 'remove', (removed) =>
        @_mapWidget?.removeData unless Array.isArray removed then [removed] else removed
        
      @bindTo Item.collection, 'add', (added) =>
        @_mapWidget?.addData unless Array.isArray added then [added] else added
      #TODO @bindTo Item.collection, 'update', @_onUpdateItem
      @bindTo Item.collection, 'remove', (removed) =>
        @_mapWidget?.removeData unless Array.isArray removed then [removed] else removed
      
      @bindTo app.router, 'rulesResolved', (args, rules) =>
        targetIds = _.keys rules
        console.dir rules
        return unless targetIds.length > 0
        app.router.trigger 'executeRule', rules[targetIds[0]][0].name, @character.id, targetIds[0], {angle: 80}

    # the render method, which use the specified template
    render: =>
      super()
      @_mapWidget = $('<div></div>').mapDisplay(
        displayGrid: false
        displayMarkers: false
        displayHover: false
        click: (event, details) =>
          return unless @character
          # trigger rule resolution
          app.router.trigger 'resolveRules', @character.id, details.field.x, details.field.y if details.field?
        coordChanged: =>
          # reload map content
          @map?.consult @_mapWidget.options.lowerCoord, @_mapWidget.options.upperCoord
      ).appendTo(@$el).data 'mapDisplay'
      # initialize current map to player's map
      @character = app.player?.get('characters')?[0]
      @map = @character?.get 'map'
      return unless @map?
      
      if @map.get('kind') of Renderers
        renderer =  new Renderers[@map.get 'kind']() 
        @_mapWidget.options[key] = val for key, val of renderDefaults[@map.get 'kind']
        @_mapWidget.setOption 'renderer', renderer
      else 
        console.error "unsupported map kind: #{@map.get 'kind'}"
      @_mapWidget.setOption 'mapId', @map.id
      
      # for chaining purposes
      @
      