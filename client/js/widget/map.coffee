define [
  'jquery'
  'utils/common'
  'widget/base'
  'widget/item'
],  ($, utils, Base) ->

  # Widget that displays maps of fields and items
  # It delegates rendering operations to a mapRenderer that you need to manually create and set.
  class Map extends Base

    # **private**
    # the layer container
    _container: null

    # **private**
    # clone used while loading field data to avoid filtering
    _cloneLayer: null

    # **private**
    # displayed map fields. 
    _fields: []

    # **private**
    # stores items rendering, organized by item id, for faster access
    _itemWidgets: {}

    # **private**
    # stores widget to be destroy when refreshing displayed items
    _oldWidgets: {}

    # **private**
    # Jumper to avoid refreshing too many times hovered tile.
    _moveJumper: 0

    # **private**
    # last cursor position
    _cursor: null

    # **private**
    # Array of loading images.
    _loadedImages : []

    # **private**
    # Number of pending loading items 
    _loading: 0

    # **private**
    # Number of loading images before removing the temporary field layer 
    _pendingImages: 0
  
    # Initialize widget rendering
    #
    # @element [Dom] element on which apply the widget
    # @param options [Object] the creation option, with model and map.
    constructor: (element, options)->
      super element, options
      @_create()
    
    # Method invoked when the widget options are set.
    #
    # @param key [String] the set option's key
    # @param value [Object] new value for this option    
    setOption: (key, value) ->
      o = @options
      old = o[key]
      o[key] = value
      switch key
        when 'renderer'
          if value?
            @_create()
          else
            # restore previous renderer
            o[key] = old
        when 'lowerCoord'
          # computes lower coordinates
          o.upperCoord = o.renderer.nextCorner o.lowerCoord
          # creates a clone layer while reloading
          @_cloneLayer = $("<canvas width=\"#{o.renderer.width*3}\" height=\"#{o.renderer.height*3}\"></canvas>")
          # empty datas
          @_fields = []
          @_oldWidgets = _.clone @_itemWidgets
          @$el.trigger 'coordChanged'
        when 'mapId'
          if old isnt value
            # reset all rendering: fields and items.
            canvas = @$el.find('.fields')[0]
            canvas.width = canvas.width
            @_fields = []
            widget?.$el.remove() for id, widget of @_itemWidgets
            @_itemWidgets = {}
        when 'displayGrid'
          @_drawGrid()
        when 'displayMarkers'
          @_drawMarkers()
        when 'displayHover'
          @_drawCursor()
 
    # Return the corresponding item widget if displayed.
    # 
    # @param item [Object] checked item
    # @return the corresponding mapItem widget or null
    getItem: (item) =>
      if @_itemWidgets[item?.id]? then @_itemWidgets[item.id] else null
  
    # Returns field corresponding to a given coordinate
    # 
    # @param coord [Object] checked coordinates
    # @return the corresponding field or null.
    getField: (coord) =>
      return field for field in @_fields when field.x is coord.x and field.y is coord.y
      null
      
    # Adds field to map. Will be effective only if the field is inside displayed bounds.
    # Works only on arrays of json field, not on Backbone.models (to reduce memory usage)
    #
    # @param added [Array<Object>] added data (JSON array). 
    addData: (added) =>
      o = @options
      
      # end of item loading: removes old items and reset layer position
      checkLoadingEnd = =>
        return unless @_loading is 0
        # removes previous widgets
        widget.remove() for id, widget of @_oldWidgets
        @_oldWidgets = {}
        # all widget are loaded: reset position
        @_itemLayer.css 
          top:0
          left: 0

      # separate fields from items
      fields = []
      for obj in added
        unless obj._className?
          obj = obj.toJSON()
          # check that field is in the right map and the right coordinate
          if o.mapId is obj.mapId and obj.x >= o.lowerCoord.x and obj.x <= o.upperCoord.x and obj.y >= o.lowerCoord.y and obj.y <= o.upperCoord.y
            fields.push obj
        else if obj._className is 'Item' and o.mapId is obj.map?.id
          # do not add items twice
          continue if @getItem(obj)?
          # for item of the displayed map
          @_loading++
          id = obj.id
          @_oldWidgets[id] = @_itemWidgets[id] if id of @_itemWidgets and !(id of @_oldWidgets)
          _.defer =>
            # creates widget for this item
            @_itemWidgets[id] = $('<div></div>').item(
              model: obj
              map: @
            ).on('loaded', =>
              @_loading--
              checkLoadingEnd()
            ).on('dispose', (event, widget) =>
              # when reloading, it's possible that widget have already be replaced
              return unless @_itemWidgets[id] is widget
              delete @_itemWidgets[id]
            ).appendTo(@_itemLayer
            ).data 'item'
        
      checkLoadingEnd()
      
      for field in fields
        @_fields.push field
        img = "/images/#{field.typeId}-#{field.num}.png"
        unless img in @_loadedImages
          @_loadedImages.push img
          @_pendingImages++
          # obj is inside displayed bounds: loads it
          app.router.trigger 'loadImage', img 

    # Removes field from map. Will be effective only if the field was displayed.
    # Works only on arrays of json field, not on Backbone.models (to reduce memory usage)
    #
    # @param removed [Field] removed data (JSON array). 
    removeData: (removed) =>
      o = @options     
      ctx = @$el.find('.fields')[0].getContext '2d'
      
      for obj in removed
        if obj._className is 'Item'
          # immediately removes corresponding widget
          @_itemWidgets[obj.id]?.$el.remove()
        else unless obj._className?
          obj = obj.toJSON()
          if @options.mapId is obj.mapId and obj.x >= o.lowerCoord.x and obj.x <= o.upperCoord.x and obj.y >= o.lowerCoord.y and obj.y <= o.upperCoord.y
            # draw white tile at removed field coordinate
            @_drawTile ctx, obj, 'white'
            # removes from local cache
            for field, i in @_fields when field._id is obj._id
              @_fields.splice i, 1
              break
              
    # Returns the css position (relative to document) of a given map coordinate
    # Internally use its renderer to performs computation
    #
    # @param coord [Object] map coordinates (x, y)
    # @return Absolute corresponding offset (top, left)
    coordOffset: (coord) =>
      return top:0, left: 0 unless @options.renderer?
      pos = @options.renderer.coordToPos coord
      absPos = @_container.offset()
      # apply back css transformation
      scale = @$el.css 'scale'
      {
        top: pos.top*scale+absPos.top
        left: pos.left*scale+absPos.left
      }
      
    # **private**
    # Widget creation method, to rebuild rendergin.
    _create: =>
      # Initialize internal state
      @_container = null
      @_start = null
      @_selectLayer = null
      @_cloneLayer = null
      @_dim = null
      @_offset = null
      @_moveJumper = 0
      @_cursor = null
      @_zoomTimer = null
      @_loadedImages  = []
      @_pendingImages = 0

      @$el.empty().removeClass().addClass 'map-widget'
      o = @options
      return unless o.renderer?
      o.renderer.init @

      @$el.css
        height: o.renderer.height
        width: o.renderer.width

      # creates the layer container, 3 times bigger to allow drag operations
      @_container = $('<div class="map-perspective"></div>').css(
        height: o.renderer.height*3
        width: o.renderer.width*3
        top: -o.renderer.height
        left: -o.renderer.width
      ).on('click', @_onClick
      ).on('mousemove', (event) => 
        return unless @_moveJumper++ % 3 is 0
        @_cursor = @options.renderer.posToCoord @_mousePos event
        @_drawCursor()
      ).on('mouseleave', (event) => 
        @_cursor = null
        @_drawCursor()
      ).appendTo @$el

      # creates the field canvas element      
      $("""<canvas class="fields movable" height="#{o.renderer.height*3}" width="#{o.renderer.width*3}"></canvas>""").appendTo @_container
      # creates the utilities canvas elements
      $("""<canvas class="grid" height="#{o.renderer.height*3}" width="#{o.renderer.width*3}"></canvas>""").appendTo @_container
      $("""<canvas class="markers" height="#{o.renderer.height*3}" width="#{o.renderer.width*3}"></canvas>""").appendTo @_container
      $("""<canvas class="hover" height="#{o.renderer.height*3}" width="#{o.renderer.width*3}"></canvas>""").appendTo @_container
      # adds the item layer.    
      @_itemLayer = $("<div class='items'></div>").appendTo @_container

      @_container.find('canvas, .items').css
        width: "#{o.renderer.width*3}px"
        height: "#{o.renderer.height*3}px"

      @_drawGrid()
      @_drawMarkers()

      # image loading loading handler
      @bindTo app.router, 'imageLoaded',@_onImageLoaded
  
      # gets first data
      _.defer =>  @setOption 'lowerCoord', o.lowerCoord
       
    # **private**
    # Extracts mouse position from DOM event, regarding the container.
    # @param event [Event] 
    # @return the mouse position
    # @option return x the abscissa position
    # @option return y the ordinate position
    _mousePos: (event) =>
      offset = @_container.offset()
      # apply back css transformation
      scale = @$el.css 'scale'
      {
        left: (event.pageX-offset.left)/scale
        top: (event.pageY-offset.top)/scale
      }

    # **private**
    # If no image loading remains, and if a clone layer exists, then its content is 
    # copied into the field layer
    _replaceFieldClone: =>
      o = @options
      # only if no image loading is pendinf
      return unless @_pendingImages is 0 and @_cloneLayer?
      # all images were rendered on clone layer: copy it on field layer.
      fieldLayer = @_container.find '.fields'
      fieldLayer.css top:0, left:0
      canvas = fieldLayer[0]
      canvas.width = canvas.width
      canvas.getContext('2d').putImageData @_cloneLayer[0].getContext('2d').getImageData(0, 0, o.renderer.width*3, o.renderer.height*3), 0, 0
      @_cloneLayer.remove()
      @_cloneLayer = null

    # **private**
    # Redraws the grid wireframe.
    _drawGrid: =>
      canvas = @$el.find('.grid')[0]
      ctx = canvas.getContext '2d'
      canvas.width = canvas.width
      o = @options
      return unless o.displayGrid

      ctx.strokeStyle = o.colors.grid 
      o.renderer.drawGrid ctx

    # **private**
    # Redraws the grid markers.
    _drawMarkers: =>
      canvas = @$el.find('.markers')[0]
      ctx = canvas.getContext '2d'
      canvas.width = canvas.width
      o = @options
      return unless o.displayMarkers

      ctx.font = "#{15*o.zoom}px sans-serif"
      ctx.fillStyle = o.colors.markers
      ctx.textAlign = 'center'
      ctx.textBaseline  = 'middle'
      o.renderer.drawMarkers ctx

    # **private**
    # Redraws cursor on stored position (@_cursor)
    _drawCursor: =>
      canvas = @$el.find('.hover')[0]
      canvas.width = canvas.width
      return unless @_cursor and @options.displayHover
      @options.renderer.drawTile canvas.getContext('2d'), @_cursor, @options.colors.hover

    # **private**
    # Image loading end handler. Draws it on the field layer, and if it's the last awaited image, 
    # remove field clone layer.
    #
    # @param success [Boolean] true if image was successfully loaded
    # @param src [String] the loaded image url
    # @param img [Image] an Image object, null in case of failure
    _onImageLoaded: (success, src, img) => 
      o = @options
      # do nothing if loading failed.
      return unless src in @_loadedImages
      @_loadedImages.splice @_loadedImages.indexOf(src), 1
      src = src.slice src.lastIndexOf('/')+1
      @_pendingImages--
        
      return @_replaceFieldClone() unless success
        
      ctx = @$el.find('.fields')[0].getContext '2d'
      # write on field layer, unless a clone layer exists
      ctx = @_cloneLayer[0].getContext '2d' if @_cloneLayer?

      # looks for data corresponding to this image
      for field in @_fields
        if "#{field.typeId}-#{field.num}.png" is src
          {left, top} = o.renderer.coordToPos field
          ctx.drawImage img, left, top, o.renderer.tileW+1, o.renderer.tileH+1
      # all images was loaded: remove temporary field layer
      @_replaceFieldClone()
      
    # **private**
    # Click handler that triggers the 'click' handler with relevant field and items.
    #
    # @param event [Event] cancelled click event
    _onClick: (event) =>
      coord = @options.renderer.posToCoord @_mousePos event

      details = 
        items: []
        field: null
      for id, widget of @_itemWidgets
        if widget.options.coordinates.x is coord.x and widget.options.coordinates.y is coord.y
          details.items.push widget.options.model
      for field in @_fields
        if field.x is coord.x and field.y is coord.y
          details.field = field
          break
      # trigger event
      @$el.trigger 'mapClicked', details
      
  # widget declaration
  Map._declareWidget 'mapWidget', 
  
    # map id, to ignore items and fields that do not belongs to the displayed map
    mapId: null

    # lower coordinates of the displayed map. Modification triggers the 'coordChanged' event, and reset map content.
    # Read-only, use `setOption('lowerCoord', ...)` to modify.
    lowerCoord: {x:0, y:0}

    # upper coordinates of the displayed map. Automatically updates when upper coordinates changes.
    # Read-only, do not modify manually.
    upperCoord: {x:0, y:0}

    # Awaited with and height for individual tiles, with normal zoom.
    tileDim: 100

    # Number of vertical displayed tiles 
    verticalTileNum: 10

    # Number of horizontal displayed tiles.
    horizontalTileNum: 10

    # Flag that indicates wether or not display the tile grid.
    # Read-only, use `setOption('displayGrid', ...)` to modify.
    displayGrid: true

    # Flag that indicates wether or not display the tile coordinates (every 5 tiles).
    # Read-only, use `setOption('displayMarkers', ...)` to modify.
    displayMarkers: true
    
    # Flag that indicates wether or not display the tile hovered
    # Read-only, use `setOption('displayHover', ...)` to modify.
    displayHover: true

    # angle use to simulate perspective. 60 means view from above. 45 means iso perspective
    angle: 45
    
    # **private**
    # color used for markers, grid, and so on.
    colors:
      markers: 'red'
      grid: '#888'
      hover: '#ccc'
    
    # Delegate renderer, see MapRenderer class. Mandatory! set with 'setOption'
    renderer: null
      
  # The map renderer is used to render tiles on the map
  # Extending this class allows to have different tiles type: hexagonal, diamond...
  class MapRenderer

    # associated map widget
    map: null

    # map coordinate of the lower-left hidden corner
    origin: {x:0, y:0}

    # Map displayed width, without zoom taken in account
    width: null

    # Map displayed height, without zoom taken in account
    height: null

    # Individual tile width, taking zoom into account
    tileW: null

    # Individual tile height, taking zoom into account
    tileH: null
    
    # **private**
    # Returns the number of tile within the map total height.
    # Used to reverse the ordinate axis.
    #
    # @return number of tile in total map height
    _verticalTotalNum: () -> 
      (-1 + Math.floor @height*3/@tileH)*3

    # Initiate the renderer with map inner state. 
    # Initiate `tileW` and `tileH`.
    #
    # @param map [Object] the associated map widget
    # 
    init: (map) => throw new Error 'the `init` method must be implemented'

    # Compute the map coordinates of the other corner of displayed rectangle
    #
    # @param coord [Object] map coordinates of the upper/lower corner used as reference
    # @param upper [Boolean] indicate the the reference coordinate are the upper-right corner. 
    # False to indicate its the bottom-left corner
    # @return map coordinates of the other corner
    nextCorner: (coord, upper=true) => throw new Error 'the `nextCorner` method must be implemented'

    # Translate map coordinates to css position (relative to the map origin)
    #
    # @param coord [Object] object containing x and y coordinates
    # @option coord x [Number] object abscissa
    # @option coord y [Number] object ordinates
    # @return an object containing:
    # @option return left [Number] the object's left offset, relative to the map origin
    # @option return top [Number] the object's top offset, relative to the map origin
    coordToPos: (coord) => throw new Error 'the `coordToPos` method must be implemented'

    # Translate css position (relative to the map origin) to map coordinates to css position
    #
    # @param coord [Object] object containing top and left position relative to the map origin
    # @option coord left [Number] the object's left offset
    # @option coord top [Number] the object's top offset
    # @return an object containing:
    # @option return x [Number] object abscissa
    # @option return y [Number] object ordinates
    # @option return z-index [Number] the object's z-index
    posToCoord: (pos) => throw new Error 'the `posToCoord` method must be implemented'

    # Draws the grid wireframe on a given context.
    #
    # @param ctx [Object] the canvas context on which drawing
    drawGrid: (ctx) => throw new Error 'the `drawGrid` method must be implemented'

    # Draws the markers on a given context.
    #
    # @param ctx [Object] the canvas context on which drawing
    drawMarkers: (ctx) => throw new Error 'the `drawMarkers` method must be implemented'

    # Draw a single selected tile in selection or to highlight hover
    #
    # @param ctx [Canvas] the canvas context.
    # @param pos [Object] coordinate of the drew tile
    # @param color [String] the color used to fill the tile
    drawTile: (ctx, pos, color) => throw new Error 'the `drawTile` method must be implemented'
    
  {
    Widget: Map
    Renderer: MapRenderer
  }