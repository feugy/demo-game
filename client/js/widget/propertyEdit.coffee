define [
  'jquery'
  'moment'
  'i18n!nls/common'
  'widget/base'
], ($, moment, i18n, Base) ->

  # The propertyEdit widget allows to display and edit a dynamic property. 
  # It adapts to the property's own type.
  class PropertyEdit extends Base
    
    constructor: (element, options) ->
      super element, options
      @_create()

    # destructor: free DOM nodes and handles
    dispose: =>
      @$el.find('*').off()
      super()
    
    # Set the property type. Will refresh rendering.
    #
    # @param type [Object] new type
    setType: (type) =>
      @options.type = type
      @_create()
       
    # Set the property value. Will refresh rendering.
    #
    # @param value [Object] new value 
    setValue: (value) =>
      @options.value = value
      @_create()

    # build rendering
    _create: =>
      # remove previous
      @$el.find('*').unbind().remove()
      @$el.html ''
      
      @$el.addClass 'property-widget'
      # first cast
      @_castValue()
      rendering = null
      isNull = @options.value is null or @options.value is undefined
      # depends on the type
      switch @options.type
        when 'string'
          # simple text input
          rendering = $("""<input type="text" value="#{@options.value or ''}"/>""").appendTo @$el
          rendering.on 'keyup', @_onChange
          unless isNull
            @options.value = rendering.val()

        when 'text'
          # textarea
          rendering = $("""<textarea>#{@options.value or ''}</textarea>""").appendTo @$el
          rendering.on 'keyup', @_onChange
          unless isNull 
            @options.value = rendering.val()
        
        when 'boolean'
          # checkbox 
          group = parseInt Math.random()*1000000000
          rendering = $("""
            <span class="boolean-value">
              <input name="#{group}" value="true" type="radio" #{if @options.value is true then 'checked="checked"' else ''}/>
              #{i18n.property.isTrue}
              <input name="#{group}" value="false" type="radio" #{if @options.value is false then 'checked="checked"' else ''}/>
              #{i18n.property.isFalse}
            </span>
            """).appendTo @$el
          rendering.find('input').on 'change', @_onChange

        when 'integer', 'float'
          # stepper
          step =  if @options.type is 'integer' then 1 else 0.01
          rendering = $("""
            <input type="number" min="#{@options.min}" 
                   max="#{@options.max}" step="#{step}" 
                   value="#{@options.value}"/>""").appendTo @$el
          rendering.on 'change keyup', @_onChange
          unless isNull 
            @options.value = rendering.val()
            @_castValue()

        else throw new Error "unsupported property type #{@options.type}"

    # **private**
    # Enforce for integer, float and boolean value that the value is well casted/
    _castValue: =>
      return unless @options.value?
      switch @options.type
        when 'integer' then @options.value = parseInt @options.value
        when 'float' then @options.value = parseFloat @options.value
        when 'boolean' then @options.value = @options.value is true or @options.value is 'true'
        when 'date' 
          # null and timestamp values are not modified.
          if @options.value isnt null and isNaN @options.value
            # date and string values will be converted to timestamp
            @options.value = moment(@options.value).toDate().toISOString()

    # **private**
    # Content change handler. Update the current value and trigger event `change`
    #
    # @param event [Event] the rendering change event
    _onChange: (event) =>
      # cast value
      @options.value = $(event.target).val()     
      @_castValue()
      @$el.trigger 'change', value:@options.value
      event.stopPropagation()

  # widget declaration
  PropertyEdit._declareWidget 'propertyEdit', 

    # maximum value for type `integer` or `float`
    max: 100000000000
    
    # minimum value for type `integer` or `float`
    min: -100000000000

    # property's type: string, text, boolean, integer, float, date, array or object
    type: 'string'
    
    # property's value. Null by default
    value: null