define [
  'jquery'
  'underscore'
], ($, _) ->

  classToType = {}
  for name in 'Boolean Number String Function Array Date RegExp Undefined Null'.split ' '
    classToType["[object " + name + "]"] = name.toLowerCase()

  # This method is intended to replace the broken typeof() Javascript operator.
  #
  # @param obj [Object] any check object
  # @return the string representation of the object type. One of the following:
  # object, boolean, number, string, function, array, date, regexp, undefined, null
  #
  # @see http://arcturo.github.com/library/coffeescript/07_the_bad_parts.html
  type = (obj) ->
    strType = Object::toString.call obj
    return classToType[strType] or "object"
    
  # isA() is an utility method that check if an object belongs to a certain class, or to one 
  # of it's subclasses. Uses the classes names to performs the test.
  #
  # @param obj [Object] the object which is tested
  # @param clazz [Class] the class against which the object is tested
  # @return true if this object is a the specified class, or one of its subclasses. false otherwise
  isA = (obj, clazz) ->
    return false if not (obj? and clazz?)
    currentClass = obj.constructor
    while currentClass?
      return true  if currentClass.name == clazz.name
      currentClass = currentClass.__super__?.constructor
    false
  
  {
    
    type: type
    
    isA: isA
    
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
      
    # Returns the instance name (from a Backbone enriched Model):
    # - for Item/Event/Map, use the instance name property or the type name if not found
    # - for Player, use email property
    # - for Field, use type property
    #
    # @param instance [Object] Backbone Model on which name is retrived
    # @return the model's name.
    instanceName: (instance) ->
      return instance.email if instance._className is 'Player'
      return require('model/FieldType')?.collection?.get(instance.typeId)?.name unless instance._className?
      instance?.name or instance?.type?.name
      
    # Returns the value of a given object's property, along the specified path.
    # Path may contains '.' to dive inside sub-objects, and '[]' to dive inside
    # arrays.
    # Unloaded subobject will be loaded in waterfall.
    #
    # @param object [Object] root object on which property is read
    # @param path [String] path of the read property
    # @param callback [Function] extraction end function, invoked with 3 arguments
    # @option callback err [String] an error string, null if no error occured
    # @option callback value [Object] the property value.
    # @option callback updatables [Array] list of traversed instances, on which 
    # update listener may be bound
    getProp: (obj, path, callback) ->
      return callback "invalid path '#{path}'" unless 'string' is type path
      steps = path.split '.'
      updatables = []
      
      processStep = (obj) ->
        step = steps.splice(0, 1)[0]
        
        # first check sub-array
        bracket = step.indexOf '['
        index = -1
        if bracket isnt -1
          # sub-array awaited
          bracketEnd = step.indexOf ']', bracket
          if bracketEnd > bracket
            index = parseInt step.substring bracket+1, bracketEnd
            step = step.substring 0, bracket
            
        # check the property existence
        return callback null, undefined, updatables unless 'object' is type(obj) and step of obj
        
        # store obj inside the list of updatable objects
        updatables.push obj if obj._className? and obj.save?    
        subObj = if index isnt -1 then obj[step][index] else obj[step]
        
        endStep = ->
          # iterate on sub object or returns value
          if steps.length is 0
            return callback null, subObj, updatables
          else
            processStep subObj
            
        # if the object has a type and the path is along an object/array property
        if obj.type?.properties?[step]?.type is 'object' or obj.type?.properties?[step]?.type is 'array'
          # we may need to load object.
          if ('array' is type(subObj) and 'string' is type subObj?[0]) or 'string' is type subObj
            obj.getLinked (err, obj) ->
              return callback "error on loading step #{step} along path #{path}: #{err}" if err?
              subObj = if index isnt -1 then obj[step][index] else obj[step]
              endStep()
          else
            endStep()
        else
          endStep()
      
      processStep obj

  }