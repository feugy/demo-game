'use strict'

define [
  'jquery'
  'i18n!nls/widget'
  'widget/baseWidget'
],  ($, i18n) ->

  # Widget that displays an image and two action buttons to upload a new version or delete the existing one.
  # Triggers a `change`event when necessary.
  $.widget 'app.loadableImage', $.app.baseWidget, 

    options:    

      # image source: a string url
      # read-only: use `setOption('source')` to modify
      source: null
      
    # **private**
    # the image DOM element
    _image: null

    # Frees DOM listeners
    destroy: ->
      @element.find('.ui-icon').unbind()
      $.app.baseWidget::destroy.apply @, arguments

    # **private**
    # Builds rendering
    _create: ->
      $.app.baseWidget::_create.apply @, arguments
      
      # encapsulates the image element in a div
      @element.addClass 'loadable'
      @_image = $('<img/>').appendTo @element
      
      # reload image
      @_setOption 'source', @options.source

    # **private**
    # Method invoked when the widget options are set. Update rendering if `source` changed.
    #
    # @param key [String] the set option's key
    # @param value [Object] new value for this option    
    _setOption: (key, value) ->
      return $.app.baseWidget::_setOption.apply @, arguments unless key in ['source']
      switch key
        when 'source' 
          @options.source = value
          # do not display alternative text yet
          @_image.removeAttr 'src'
          # load image from images service
          if @options.source is null 
            setTimeout (=> @_onLoaded false, '/images/null'), 0
          else 
            # loading handler
            @bindTo app.router, 'imageLoaded', => @_onLoaded.apply @, arguments
            app.router.trigger 'loadImage', "/images/#{@options.source}"

    # **private**
    # Creates an alternative text if necessary
    _createAlt: ->
      return if @element.find('.alt').length isnt 0
      # do not use regular HTML alt attribute because Chrome doesn't handle it correctly: position cannot be set
      @element.prepend "<p class=\"alt\">#{i18n.loadableImage.noImage}</p>"

    # **private**
    # Image loading handler: hides the alternative text if success, or displays it if error.
    #
    # @param success [Boolean] indicates wheiter or not loading succeeded
    # @param src [String] loaded image source
    # @param img [Image] if successful, loaded image DOM node
    _onLoaded: (success, src, img) -> 
      return unless src is "/images/#{@options.source}"
      @unboundFrom app.router, 'imageLoaded'
      if success 
        # displays image data and hides alertnative text
        @_image.replaceWith $(img).clone()
        @_image = @element.find 'img'
        @element.find('.alt').remove()
      else 
        # displays the alternative text
        @_createAlt()