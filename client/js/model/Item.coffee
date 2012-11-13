'use strict'

define [
  'utils/common'
  'model/BaseModel'
  'model/ItemType'
], (utils, Base, ItemType) ->

  # Client cache of items.
  class _Items extends Base.LinkedCollection

    # Class of the type of this model.
    @typeClass: ItemType

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'Item'

    # **private**
    # List of not upadated attributes
    _notUpdated: ['_id', 'type', 'map']

    # Enhance Backone method to allow existing models to be re-added.
    # Needed because map will add retrieved items when content returned from server, and `add` event needs
    # to be fired from collection
    add: (added, options) =>
      added = [added] unless Array.isArray added

      previous = []
      # silentely removes existing models to allow map to be updated
      for obj in added
        existing = @get obj._id
        continue unless existing?
        @remove existing, silent: true
        previous.push existing
        
      super added, options

      # trigger re-addition for Item views
      for existing in previous
        @trigger 'readd', existing, @get existing.id


    # **private**
    # Callback invoked when a database update is received.
    # Update the model from the current collection if needed, and fire event 'update'.
    # Extension to resolve map when needed
    #
    # @param className [String] the modified object className
    # @param changes [Object] new changes for a given model.
    _onUpdate: (className, changes) =>
      return unless className is @_className
      if 'map' of changes and changes.map?
        id = if 'object' is utils.type changes.map then changes.map._id else changes.map
        changes.map = require('model/Map').collection.get id

      # manages transition changes
      if 'transition' of changes
        model = @get changes._id
        model._transition = changes.transition if model?

      # Call inherited merhod
      super className, changes

      # reset transition change detection when updated
      if 'transition' of changes
        model = @get changes._id
        model._transitionChanged = false

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
      super attributes
      @_transitionChanged = false
      # Construct a Map around the raw map.
      if attributes?.map?
        # to avoid circular dependencies
        Map = require 'model/Map'
        if typeof attributes.map is 'string'
          # gets by id
          map = Map.collection.get attributes.map
          unless map
            # trick: do not retrieve map, and just construct with empty name.
            @set 'map', new Map _id: attributes.map
          else 
            @set 'map', map
        else
          # or construct directly
          map = new Map attributes.map
          Map.collection.add map
          @set 'map', map

    # Overrides inherited setter to handle i18n fields.
    #
    # @param attr [String] the modified attribute
    # @param value [Object] the new attribute value
    set: (attr, value) =>
      super attr, value
      @_transitionChanged = true if attr is 'transition'

    # **private** 
    # Method used to serialize a model when saving and removing it
    # Removes transition if no modification detected
    #
    # @return a serialized version of this model
    _serialize: => 
      result = @toJSON()
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