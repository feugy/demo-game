define [
  'jquery'
  'utils/common'
], ($, utils) ->
    
  # replace jQuery's cleanData which is the best place to triger an event when a node is destroyed, 
  _cleanData = $.cleanData
  $.cleanData = (elems) ->
    for elem in elems
      try
        $(elem).triggerHandler 'remove' if elem?
      catch e
        # http://bugs.jquery.com/ticket/8235
    _cleanData elems

  class Base

    # **private**
    # internal use only: declare jQuery widget and initialize defaults
    #
    # @param name [String] name of the created widget
    # @param defaults [Object] the default values of widget options
    # @return the class
    @_declareWidget: (name, defaults) ->
      Clazz = @

      # Plugin definition
      $.fn[name] = (arg1) ->
        args = Array::slice.call arguments
        method = args[0]
        @each ->
          @$ = $(@)
          data = @$.data name
          options = $.extend true, {}, $.fn[name].defaults, if 'object' is utils.type method then method
          
          unless data? 
            data = new Clazz @, options
            @$.data name, data

          if 'string' is utils.type method
            if 'function' is utils.type data[method]
              data[method].apply data, args.slice 1
            else 
              throw new Error "unsupported method #{method} on widget #{name}"

      $.fn[name].Constructor = Clazz

      # plugin defaults
      $.fn[name].defaults = defaults

      # Returns class for modularity
      @

    # widget options (i.i. public state)
    options: {}
    
    # widget jQuery enhanced element.
    $el: null

    # **private**
    # Array of bounds between targets and the view, that are unbound by `dispose`
    # Stores an array for each bond: frist the emitter, then the event and at last the callback
    _bounds: []

    # Initialize bound array
    constructor: (element, @options) ->
      @_bounds = []
      @$el = $(element)
      @$el.on 'remove', @dispose

    # Allows to bound a callback of this widget to the specified emitter
    # bounds are keept and automatically unbound by the `dispose` method.
    #
    # @param emitter [Backbone.Event] the emitter on which callback is bound
    # @param events [String] events on which the callback is bound
    # @parma callback [Function] the bound callback
    bindTo: (emitter, events, callback) =>
      emitter.on events, callback
      @_bounds.push [emitter, events, callback]
      
    # Unbounds a callback of this widget from the specified emitter
    #
    # @param emitter [Backbone.Event] the emitter on which callback is unbound
    # @param events [String] event on which the callback is unbound
    unboundFrom: (emitter, event) =>
      for spec, i in @_bounds when spec[0] is emitter and spec[1] is event
        spec[0].off spec[1], spec[2]
        @_bounds.splice i, 1
        break

    # Frees registered handlers
    dispose: =>
      # automatically remove bound callback
      spec[0].off spec[1], spec[2] for spec in @_bounds
      @$el.trigger 'dispose', @
      @$el.off()