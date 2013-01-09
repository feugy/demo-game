define [
  'utils/common'
  'model/BaseModel'
  'model/ItemType'
  'utils/sockets'
], (utils, Base, ItemType, sockets) ->

  # Enrich item map with Backbone Model, in a synchronous fashion
  #
  # @param model [Event] enriched model
  enrichMap = (model) ->
    # to avoid circular dependencies
    Map = require 'model/Map'
    id = if 'string' is utils.type model.map then model.map else model.map._id
    # gets by id
    map = Map.collection.get id
    unless map?
      # construct it directly because it does not exist
      if 'string' is utils.type model.map
        # do not add it: just temporary
        model.map = new Map _id: id 
      else
        model.map = new Map model.map
        Map.collection.add model.map
    else 
      model.map = map

  # Client cache of items.
  class _Items extends Base.LinkedCollection

    # Class of the type of this model.
    @typeClass: ItemType

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'Item'

    # **private**
    # List of not upadated attributes
    _notUpdated: ['_id', 'type']
    
    # enhanced inheritted method to trigger `add` event on existing models that
    # are added a second time.
    #
    # @param models [Object/Array] added model(s)
    # @param options [Object] addition options
    add: (models, options) =>
      existings = []
      
      models = if Array.isArray models then models else [models]
      # keep existing models that will be merged
      existings.push @_byId[model._id] for model in models when @_byId?[model._id]?
      
      options = {} unless options?
      options.merge = true  
      
      # superclass behaviour
      super models, options
      
      # trigger existing model re-addition
      model.trigger 'add', model, @, options for model in existings
      
    # **private**
    # Callback invoked when a database update is received.
    # Update the model from the current collection if needed, and fire event 'update'.
    # Extension to resolve map when needed
    #
    # @param className [String] the modified object className
    # @param changes [Object] new changes for a given model.
    _onUpdate: (className, changes) =>
      return unless className is @_className
      
      # add unexisting models
      model = @get changes._id
      return new Item(changes).fetch() unless model?
      
      enrichMap changes if changes?.map?

      # manages transition changes
      model?._transition = changes.transition if 'transition' of changes

      # Call inherited merhod
      super className, changes
      
      # reset transition change detection when updated
      model?._transitionChanged = false if 'transition' of changes

  # Modelisation of a single Item.
  # Not wired to the server : use collections Items instead
  class Item extends Base.LinkedModel

    # Class of the type of this model.
    @typeClass: ItemType

    # Array of path of classes in which linked objects are searched.
    @linkedCandidateClasses: ['model/Event']

    # Local cache for models.
    # **Caution** must be defined after @linkedCandidateClasses to allow loading 
    @collection: new _Items @

    # **private**
    # Provide the transition used to animate items.
    # Do not use directly used `model.get('transition')` because it's not reset when not appliable.
    _transition: null

    # **private**
    # FIXME: for some unknown reason, BAckbone Model does not detect changes on attributes, andwe must
    # detect them manually
    _transitionChanged: false

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'Item'

    # Item constructor.
    # Will fetch type from server if necessary, and trigger the 'typeFetched' when finished.
    #
    # @param attributes [Object] raw attributes of the created instance.
    constructor: (attributes) ->
      # Construct a Map around the raw map.
      enrichMap attributes if attributes?.map?
      super attributes
      @_transition = null
      @_transitionChanged = false

    # Overrides inherited setter to handle i18n fields.
    #
    # @param attr [String] the modified attribute
    # @param value [Object] the new attribute value
    # @param options [Object] optionnal set options
    set: (attr, value, options) =>
      super attr, value, options
      @_transitionChanged = true if attr is 'transition'
  
    # Retrieve a single item with its linked processed
    # Item is automatically added to collection
    fetch: =>
      
      # process server response
      process = (err, instances) =>
        return callback "Unable to fetch #{@id}: #{err}" if err?
        # only for our own request
        return unless instances.length is 1 and instances[0][@idAttribute] is @[@idAttribute]
        sockets.game.removeListener "get#{@_className}s-resp", process
        # copie values
        @[prop] = value for prop, value of instances[0]
        enrichMap @ if @map?
        # add to collection
        @constructor.collection.add @
              
      # get the single instance
      sockets.game.on "get#{@_className}s-resp", process
      sockets.game.emit "get#{@_className}s", [@id]
      
    # **private** 
    # Method used to serialize a model when saving and removing it
    # Removes transition if no modification detected
    #
    # @return a serialized version of this model
    _serialize: => 
      result = super()
      delete result.transition unless @_transitionChanged
      result

    # Returns the Item's transition. Designed to be used only one time.
    # When restrieved, the transition is reset until its next change.
    #
    # @return the current transition, or null if no transition available.
    getTransition: =>
      transition = @_transition 
      @_transition = null
      transition