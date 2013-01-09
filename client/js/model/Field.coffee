define [
  'underscore'
  'backbone'
  'model/FieldType'
  'utils/common'
  'utils/sockets'
], (_, Backbone, FieldType, utils, sockets) ->

  # Field collection to handle multiple operaions on fields.
  # Do not provide any local cache, nor allows field retrival. Use `Map.consult()` method instead.
  # Wired to server changes events.
  class _Fields extends Backbone.Collection

    # Collection constructor, that wired on events.
    #
    # @param model [Object] the managed model
    # @param options [Object] unused
    constructor: (@model, @options) ->
      super [], options
      # bind updates
      utils.onWired =>
        sockets.updates.on 'creation', @_onAdd
        sockets.updates.on 'deletion', @_onRemove

    # Extends the inherited method to unstore added models.
    # Storing fields is a nonsense in Rheia because no browser action will occur on Fields.
    # Unstoring them will save some memory for other usage
    #
    # @param models [Array|Object] added model, or added array of models
    # @param options [Object] optional arguments, like silent
    add: (models, options) =>
      # calls the inherited method
      super models, options
      models = if _.isArray models then models.slice() else [models]
      typeIds = []
      for model in models
        @_removeReference @_byId[model._id]
        typeIds.push model.typeId unless model.typeId in typeIds
      # deletes local caching
      @models = []
      @_byCid = {}
      @_byId = {}
      length = 0
      # load types if needed
      typeIds = _.reject typeIds, (id) -> FieldType.collection.get(id)?
      sockets.game.emit 'getTypes', typeIds if typeIds.length isnt 0
      return @

    # Override the inherited method to trigger remove events.
    #
    # @param models [Array|Object] removed model, or removed array of models
    # @param options [Object] optional arguments, like silent
    remove: (models, options) =>
      # manually trigger remove events
      models = if _.isArray models then models.slice() else [models]
      @trigger 'remove', @_prepareModel(model, options), @, options for model in models

    # **private**
    # Callback invoked when a database creation is received.
    # Fire event 'add'.
    #
    # @param className [String] the modified object className
    # @param model [Object] created model.
    _onAdd: (className, model) =>
      return unless className is 'Field'
      # only to trigger add event
      @add model

    # **private**
    # Callback invoked when a database deletion is received.
    # Fire event 'remove'.
    #
    # @param className [String] the deleted object className
    # @param model [Object] deleted model.
    _onRemove: (className, model) =>
      # only to trigger add event
      @remove new @model model

  # Field model class. Allow creation and removal. Update is not permitted.
  class Field extends Backbone.Model

    # Local cache for models.
    @collection: new _Fields @

    # bind the Backbone attribute and the MongoDB attribute
    idAttribute: '_id'

    # Initialization logic: declare dynamic properties for each of model's attributes
    initialize: =>
      names = _.keys @attributes
      for name in names
        ((name) =>
          unless Object.getOwnPropertyDescriptor(@, name)?
            Object.defineProperty @, name,
              enumerable: true
              configurable: true
              get: -> @get name
              set: (v) -> @set name, v
        )(name)
        
    # An equality method that tests ids.
    #
    # @param other [Object] the object against which the current item is tested
    # @return true if both object have the samge ids, and false otherwise.
    equals: (other) =>
      @.id is other?.id