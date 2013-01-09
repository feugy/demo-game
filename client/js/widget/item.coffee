'use strict'

define [
  'jquery'
  'utils/common'
  'widget/base'
  'utils/extensions'
], ($, utils, Base) ->

  defaultHeight = 100;
  defaultWidth = 100;

  # List of executing animations
  _anims = {}

  # The unic animation loop
  _loop = (time) ->
    # request another animation frame for next rendering.
    window.requestAnimationFrame _loop 
    if document.hidden
      # if document is in background, animations will stop, so stop animations.
      time = null
    # trigger onFrame for each executing animations
    for key, anim of _anims
      anim._onFrame.call anim, time if anim isnt undefined

  # starts the loop at begining of the game
  window.requestAnimationFrame _loop 
  
  # Item widget is responsible for displaying a map item.
  # It automatically updates when bound item is updated or removed.
  # It can be associated with a Map widget: it will manage it's position on the map.
  class Item extends Base
  
    # **private**
    # Model images specification
    _imageSpec: null

    # **private**
    # Currently displayed sprite: name of one of the _imageSpec sprite
    _sprite: null

    # **private**
    # Current sprite image index
    _step: 0

    # **private**
    # Current sprite image offset
    _offset: {x:0, y:0}

    # **private**
    # Animation start timestamp
    _start:null

    # **private**
    # Stored coordinates applied at the end of the next animation
    _newCoordinates: null

    # **private**
    # Stored position applied at the end of the next animation
    _newPos: null
    
    # **private**
    # Dom node displaying the image
    _img: null

    # Construct view and performs immediate rendering.
    # Image is computed from the model type image and instance number
    #
    # @element [Dom] element on which apply the widget
    # @param options [Object] the creation option, with model and map.
    constructor: (element, options) ->
      super element, options
      @$el.addClass 'item-widget'
      @_img = $('<div></div>').appendTo @$el
      
      if app.player?.characters?
        for character in app.player.characters when character.equals @options.model
          @$el.addClass 'character'
          break
      
      @_sprite= null
      @_step= 0
      @_offset= x:0, y:0
      @_start= null
      @_newCoordinates= null
      @_newPos= null
      @_imageSpec = null

      # compute item image
      @_imageSpec = @options.model.type.images?[@options.model.imageNum]
      if @_imageSpec?.file
        @bindTo app.router, 'imageLoaded', @_onLoaded
        app.router.trigger 'loadImage', "/images/#{@_imageSpec.file}"

      # bind to model events
      @bindTo @options.model, 'update', @_onUpdate
      @bindTo @options.model, 'destroy', => @$el.remove()
      
      # immediate render
      @_positionnate()
      @_render()
    
    # **private**
    # Shows relevant sprite image regarding the current model animation and current timing
    _render: =>    
      # do we have a transition ?
      transition = @options.model.getTransition()
      transition = null unless @_imageSpec.sprites? and transition of @_imageSpec.sprites

      # gets the item sprite's details.
      if transition? and 'object' is utils.type @_imageSpec.sprites
        @_sprite = @_imageSpec.sprites[transition]
      else
        @_sprite = null
      @_step = 0
      # set the sprite row
      @_offset.x = 0
      @_offset.y = if @_sprite? then -@_sprite.rank * @_imageSpec.height else 0

      # no: just display the sprite image
      @$el.css {'background-position': "#{@_offset.x}px #{@_offset.y}px"}
      return unless transition? and @_sprite?
      # yes: let's start the animation !
      @_start = new Date().getTime()

      # if we moved, compute the steps
      if @_newPos?
        @_newPos.stepL = (@_newPos.left-parseInt @$el.css 'left')/@_sprite.number
        @_newPos.stepT = (@_newPos.top-parseInt @$el.css 'top')/@_sprite.number

      if document.hidden
        # document not visible: drop directly to last frame.
        @_onFrame @_start+@_sprite.duration
      else
        # adds it to current animations
        _anims[@options.model.id] = @
      
    # **private**
    # Compute and apply the position of the current widget inside its map widget.
    # In case of position deferal, the new position will be slighly applied during next animation
    #
    # @param defer [Boolean] allow to differ the application of new position. false by default
    _positionnate: (defer = false) =>
      return unless @options.map?
      coordinates = 
        x: @options.model.x
        y: @options.model.y

      o = @options.map.options

      # get the widget cell coordinates
      pos = o.renderer.coordToPos coordinates
      
      # center horizontally with tile, and make tile bottom and widget bottom equal
      pos.left += (o.renderer.tileW-@_imageSpec.width)/2 
      pos.top += o.renderer.tileH-@_imageSpec.height

      if defer 
        # do not apply immediately the new position
        @_newCoordinates = coordinates
        @_newPos = pos
      else
        @options.coordinates = coordinates
        @$el.css pos

    # **private**
    # frame animator: invokated by the animation loop. If it's time to draw another frame, to it.
    # Otherwise, does nothing
    #
    # @param current [Number] the current timestamp. Null to stop current animation.
    _onFrame: (current) =>
      # loop until the end of the animation
      if current? and current-@_start < @_sprite?.duration
        # only animate at needed frames
        if current-@_start >= (@_step+1)*@_sprite.duration/@_sprite.number
          # changes frame 
          if @_offset.x <= -(@_sprite.number*@_imageSpec.width) 
            @_offset.x = 0 
          else 
            @_offset.x -= @_imageSpec.width

          @_img.css 'background-position': "#{@_offset.x}px #{@_offset.y}px"
          @_step++
          # Slightly move during animation
          if @_newPos?
            @$el.css 
              left: @_newPos.left-@_newPos.stepL*(@_sprite.number-@_step)
              top: @_newPos.top-@_newPos.stepT*(@_sprite.number-@_step)
      else 
        # removes from executing animations first.
        delete _anims[@options.model.id]
        # end of the animation: displays first sprite
        @_offset.x = 0
        @_img.css 'background-position': "#{@_offset.x}px #{@_offset.y}px"
        
        # if necessary, apply new coordinates and position
        if @_newCoordinates?
          @options.coordinates = @_newCoordinates
          @_newCoordinates = null
        if @_newPos
          delete @_newPos.stepL
          delete @_newPos.stepT
          @$el.css @_newPos
          @_newPos = null

    # **private**
    # Image loading handler: positionnates the widget inside map
    #
    # @param success [Boolean] indicates wheiter or not loading succeeded
    # @param src [String] loaded image source
    # @param img [Image] if successful, loaded image DOM node
    _onLoaded: (success, src, img) =>
      return unless src is "/images/#{@_imageSpec.file}"
      @unboundFrom app.router, 'imageLoaded'
      @$el.css
        width: @_imageSpec.width
        height: @_imageSpec.height
      if success 
        # displays image (as it was loading, browser cache will be used)
        @_img.css 'background-image', "url(#{img})"
      # render again
      @_positionnate()
      @_render()
      # trigger loaded event
      @$el.trigger 'loaded', @

    # **private**
    # Updates model inner values
    #
    # @param model [Object] new model values
    # @param changes [Object] fields that have changed
    _onUpdate: (model, changes) =>
      @options.model = model
      # removes if map has changed
      return @$el.remove() if @options.map? and @options.model?.map?.id isnt @options.map.options.mapId

      if ('x' of changes or 'y' of changes) and @options.map?
        # positionnate with animation if transition changed
        @_positionnate 'transition' of changes and changes.transition?
      # render new animation if needed
      if 'transition' of changes and changes.transition? and @options.map?
        @_render()
      # refresh displayed image if needed
      if 'imageNum' of changes
        # compute new item image
        @_imageSpec = @options.model.type.images?[@options.model.imageNum]
        if @_imageSpec?.file
          @bindTo app.router, 'imageLoaded', @_onLoaded
          app.router.trigger 'loadImage', "/images/#{@_imageSpec.file}"
       

  # widget declaration
  Item._declareWidget 'item', 
  
    # displayed model
    model: null

    # The associated map
    map: null
    
    # Current position of the widget in map. Read-only: do not change externally
    coordinates: x:null, y:null