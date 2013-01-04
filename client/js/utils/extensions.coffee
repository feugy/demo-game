define [
  'underscore'
  'underscore.string'
  'backbone'
  'hogan'
], (_, _string, Backbone, Hogan) ->

  # mix in non-conflict functions to Underscore namespace if you want
  _.mixin _string.exports()
  _.mixin
    includeStr: _string.include
    reverseStr: _string.reverse

  # enhance Backbone views with close() mechanism
  _.extend Backbone.View.prototype, 

    # **protected**
    # For views that wants templating, put their the string version of a mustache template,
    # that will be compiled with Hogan
    _template: null

    # **private**
    # Array of bounds between targets and the view, that are unbound by `destroy`
    _bounds: []

    # overload the initialize method to bind `destroy()`
    initialize: ->
      # initialize to avoid static behaviour
      @_bounds = []
      # auto dispose when removing
      @$el.on 'remove', @dispose

    # Allows to bound a callback of this view to the specified emitter
    # bounds are keept and automatically unbound by the `destroy` method.
    #
    # @param emitter [Backbone.Event] the emitter on which callback is bound
    # @param events [String] events on which the callback is bound (space delimitted)
    # @parma callback [Function] the bound callback
    bindTo: (emitter, events, callback) ->
      evts = events.split ' '
      for evt in evts
        emitter.on evt, callback
        @_bounds.push [emitter, evt, callback]
      
    # Unbounds a callback of this view from the specified emitter
    #
    # @param emitter [Backbone.Event] the emitter on which callback is unbound
    # @param events [String] event on which the callback is unbound
    unboundFrom: (emitter, event) ->
      for spec, i in @_bounds when spec[0] is emitter and spec[1] is event
        spec[0].off spec[1], spec[2]
        @_bounds.splice i, 1
        break

    # The destroy method correctly free DOM  and event handlers
    # It must be overloaded by subclasses to unsubsribe events.
    dispose: ->
      # automatically remove bound callback
      spec[0].off spec[1], spec[2] for spec in @_bounds
      # unbind DOM callback
      @$el.unbind()
      # superclass behaviour
      Backbone.View.prototype.dispose.apply @, arguments
      # trigger dispose event
      @trigger 'dispose', @

    # The `render()` method is invoked by backbone to display view content at screen.
    # if a template is defined, use it
    render: () ->
      # template rendering
      @$el.empty()
      if @_template? 
        # first compilation if necessary  
        @_template = Hogan.compile @_template if _.isString @_template
        # then rendering
        @$el.append @_template.render @_getRenderData()
      # for chaining purposes
      @

    # **protected**
    # This method is intended to by overloaded by subclass to provide template data for rendering
    #
    # @return an object used as template data (this by default)
    _getRenderData: -> @

  # getter for document visibility
  prefix = if $.browser.webkit or $.browser.chrome then 'webkit' else 'moz'

  # define a getter for page visibility
  Object.defineProperty document, 'hidden', 
    get: () ->
      document[prefix+'Hidden']

  # use same name for animation frames facilities
  window.requestAnimationFrame = window[prefix+'RequestAnimationFrame']
  window.cancelAnimationFrame = window[prefix+'CancelAnimationFrame']