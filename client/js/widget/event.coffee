'use strict'

define [
  'jquery'
  'underscore'
  'utils/common'
  'widget/base'
  'widget/item'
  'bootstrap'
], ($, _, utils, Base) ->
  
  # Event widget is responsible for displaying a event model.
  # It automatically updates when bound item is updated or removed.
  #
  # Display event content with a Bootstrap popover, and trigger event `executeRule`
  # when a rule trigger is clicked inside rendering
  class Event extends Base

    # **private**
    # Item widget to display event's from
    _from: null
    
    # **private**
    # Displayed event content.
    _content: null
    
    # **private**
    # Content shown status
    _shown: false
    
    # Construct view and performs immediate rendering.
    # Displayed image is event's from item
    #
    # @element [Dom] element on which apply the widget
    # @param options [Object] the creation option, with model and map.
    constructor: (element, options) ->
      super element, options
      @_shown = false
      @$el.addClass 'event-widget'

      # bind to model events
      @bindTo @options.model, 'update', @_onUpdate
      @bindTo @options.model, 'destroy', => @$el.remove()
      
      @$el.on 'click', '[data-rule] a', (event) =>
        event.preventDefault()
        trigger = $(event.target).closest '[data-rule]'
        params = {}
        trigger.find('[data-name]').each (i, param) =>
          param = $(param)
          params[param.data 'name'] = param.data('propertyEdit').options.value
        @$el.trigger 'executeRule', 
          rule: trigger.data 'rule'
          target: @options.model
          params: params
      # immediate render
      @_render()
      
    # allows external code to set rules that applies to this event.
    #
    # @param rules [Object] rules that apply to this event. 
    # An associated array with rule names id as key, and as value an array containing for each concerned target:
    # @options rules target [Object] the target
    # @options rules params [Object] the awaited parameters specification
    # @options rules category/rule [String/Object] the rule category, or the whole role (wholeRule is true)
    setRules: (rules) =>
      # replace placeholders by buttons
      for name, targets of rules
        for details in targets when @options.model.equals details.target
          placeholder = (@_content.find "[data-rule='#{name}']").empty()
          if details.params? and !_.isEmpty details.params
            for param in details.params
              $("<div class='controls' data-name='#{param.name}'></div>").propertyEdit(
                type: param.type.toLowerCase()
              ).appendTo placeholder
          placeholder.append "<a class='btn' href='#'>#{name}</a>"
      
    # **private**
    # Shows relevant sprite image regarding the current model animation and current timing
    _render: =>  
      # remove previous rule click handlers
      @$el.off '.rule'
      
      # do we have a from ?
      @_from.off().remove() if @_from?
      from = @options.model.from
      # Do not try to render object that are not yet Backbone models
      if from? and from._className is 'Item' and from.cid?
        @_from = $('<div></div>').item(model:from).appendTo @$el
      else 
        # no from to display
        @_from = $("<span class='no-from'>#{@options.noFromLabel or @options.model.type.name}</span>").appendTo @$el
      
      @_from.on 'click', @_onToggleContent
      @$el.on 'click', '.close', (event) =>
        event?.preventDefault()
        @_shown = false
        @_from.popover 'hide'
      
      # display content
      @_content?.remove()
      
      # Use type template to render
      @_content = $("<div>#{@options.model.type.template}</div>")
      # instanciate property display
      @_content.find('[data-property]').each (i, element) =>
        $(element).propertyDisplay
          model: @options.model
          type: $(element).data 'kind'
          path: $(element).data 'property'
          
      @_from.popover
        title: "#{@options.model.type.name}<button class='close'>&times;</button>"  
        trigger: 'manual'
        html: true
        content: @_content
      
    # **private**
    # Shows of hides the event content, triggering the rule resolution if shown
    _onToggleContent: (event) =>
      if @_shown
        @_from.popover 'hide'
      else
        @_from.popover 'show'
        # trigger rule resolution
        @$el.trigger 'resolveRules', @
      @_shown = !@_shown
    
    # **private**
    # Updates model inner values
    #
    # @param model [Object] new model values
    # @param changes [Object] fields that have changed
    _onUpdate: (model, changes) =>
      @options.model = model
      return @_render() if 'from' of changes

  # widget declaration
  Event._declareWidget 'event', 
  
    # displayed model
    model: null
    
    # label used when no from can be displayed
    noFromLabel: null