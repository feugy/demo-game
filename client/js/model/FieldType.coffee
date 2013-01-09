define [
  'model/BaseModel'
  'utils/common'
  'utils/sockets'
], (Base, utils, sockets) ->

  # Client cache of field types.
  class _FieldTypes extends Base.Collection

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'FieldType'
    
    # Collection constructor. Binds to getTypes result to add retrieved field types
    #
    # @param model [Object] the managed model
    # @param options [Object] unused
    constructor: (@model, @options) ->
      super model, options
      # bind updates
      utils.onWired =>
        sockets.game.on 'getTypes-resp', @_onAddTypes
    
    # **private**
    # Add to collection retrived field types
    #
    # @param err [String] an error string. Null if type where properly retrieved
    # @param types [Array] array of item, event and field types
    _onAddTypes: (err, types) =>
      return if err?
      @_onAdd type._className, type for type in types
      
  # Modelisation of a single Field Type.
  # Not wired to the server : use collections FieldTypes instead
  #
  class FieldType extends Base.Model

    # Local cache for models.
    @collection: new _FieldTypes @

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'FieldType'

    # **private**
    # List of model attributes that are localized.
    _i18nAttributes: ['name', 'desc']
    
    # **private**
    # List of properties that must be defined in this instance.
    _fixedAttributes: ['descImage', 'images']