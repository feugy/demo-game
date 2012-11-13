'use strict'

define [
  'jquery'
  'underscore'
], ($, _) ->

  classToType = {}
  for name in 'Boolean Number String Function Array Date RegExp Undefined Null'.split ' '
    classToType["[object " + name + "]"] = name.toLowerCase()

  {
    
    # Decode url query parameters to a json object
    # @return a json object containing parameter names as key and their associated values
    queryParams: () ->
      params = {}
      query = window.location.search.substring 1
      return params unless query?.length > 0
      search = /([^&=]+)=?([^&]*)/g
      decode = (s) -> decodeURIComponent s.replace /\+/g, ' '
      params[decode match[1]] = decode match[2] while match = search.exec query
      params

    # Used to execute some behaviour when client is fully wired to server.
    #
    # @param callback [Function] asynchronously executed callback, when sockets are wired
    onWired: (callback) ->
      if app?.connected
        _.defer callback
      else
        $(window).on 'wired', callback 

    # This method is intended to replace the broken typeof() Javascript operator.
    #
    # @param obj [Object] any check object
    # @return the string representation of the object type. One of the following:
    # object, boolean, number, string, function, array, date, regexp, undefined, null
    #
    # @see http://arcturo.github.com/library/coffeescript/07_the_bad_parts.html
    type: (obj) ->
      strType = Object::toString.call obj
      return classToType[strType] or "object"

    # Gets the base 64 image data from an image
    #
    # @param image [Image] concerned Image object
    # @return the base 64 corresponding image data
    getImageString: (image) ->
      canvas = $("<canvas></canvas>")[0]
      canvas.width = image.width
      canvas.height = image.height
      # Copy the image contents to the canvas
      ctx = canvas.getContext '2d'
      ctx.drawImage image, 0, 0
      canvas.toDataURL 'image/png'

  }