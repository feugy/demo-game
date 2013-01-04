define [
  'jquery'
  'underscore'
  'utils/common'
  'widget/base'
  'widget/item'
  'widget/event'
], ($, _, utils, Base) ->
  
  # PropertyDisplay widget show the content of a given model's property, adapting
  # the rendering to the property type.
  # It automatically updates when bound model is updated.
  class PropertyDisplay extends Base
  
    # current displayed value
    _value: undefined
    
    # previously bound objects
    _updatables: []
    
    # avoiding multiple simultaneous updates
    _inhibit: false
    
    # steps along the path
    _steps: []
  
    # Construct view and performs immediate rendering.
    # Image is computed from the model type image and instance number
    #
    # @element [Dom] element on which apply the widget
    # @param options [Object] the creation option, with model and map.
    constructor: (element, options) ->
      super element, options
      @_inhibit = false
      @_updatables = []
      @$el.addClass 'property-widget'
      
      @_steps = @options.path.split '.'
      @_steps = (step.replace /\[\d*\]/, '' for step in @_steps)
      @_onChainChanged @options.model
    
    # **private**
    # Refresh the value rendering
    _render: =>
      @$el.empty().removeClass('string text boolean integer float date object array').addClass @options.kind

      switch @options.kind
        when 'string', 'text', 'boolean', 'integer', 'float', 'date', 'time', 'datetime'
          unless @_value?
            def = ''
            if @options.kind in ['integer', 'float']
              def = 0
            else if @options.kind in ['date', 'time', 'datetime']
              def = new Date()
              
          displayed = if @_value? then @_value else def
          # round numerical values
          if @options.kind is 'integer'
            displayed = _.numberFormat displayed, 0
          else if @options.kind is 'float'
            displayed = _.numberFormat displayed, 2
          # simple text rendering
          @$el.append "<span class='value'>#{displayed}</span>"
        when 'object', 'array'
          # use item renderer for each objects
          objs = if @options.kind is 'object' then [@_value] else @_value
          for obj in objs when obj?
            if obj._className is 'Item'
              $('<div></div>').item(model: obj).appendTo @$el
            else if obj._className is 'Event' 
              $('<div></div>').event(model: obj).appendTo @$el
          @$el.toggleClass 'empty', @$el.children().length is 0
        else 
          console.warn "unsupported property kind '#{@options.kind}' for property #{@options.path} of model #{@options.model?.id}"
      
    # **private**
    # Handler that get the new value for this widget, and listen for changes of
    # all objects along the path
    #
    # @param model [Object] model updated or destroyed
    # @param changes [Object] in case of update, modified attributes
    _onChainChanged: (model, changes) =>
      return if @_inhibit

      # updates only if path changed
      pathChanged = !(changes?)
      if !pathChanged
        for name in _.keys changes
          pathChanged = name in @_steps
          break if pathChanged
      return unless pathChanged
      
      @_inhibit = true
      @unboundFrom updatable, 'update destroy' for updatable in @_updatables
      utils.getProp @options.model, @options.path, (err, value, updatables) =>
        return console.error "failed to display property #{@options.path} of model #{@options.model?.id}: #{err}" if err?
        @_value = value
        @_updatables = updatables
        # bind for update on object along the chain
        @bindTo updatable, 'update destroy', @_onChainChanged for updatable in @_updatables
        @_render()
        @_inhibit = false

  # widget declaration
  PropertyDisplay._declareWidget 'propertyDisplay', 

    # The bound model
    model: null

    # Path to the displayed property
    path: '' 
    
    # Property kind: string, text, boolean, integer, float, date, array or object
    kind: 'string'