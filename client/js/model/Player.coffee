define [
  'underscore'
  'model/BaseModel'
  'model/Item'
  'utils/common'
  'utils/sockets'
], (_, Base, Item, utils, sockets) ->

  # Enrich player characters from with Backbone Model. 
  # May ask to server the missing characters item.
  # Use a callback or trigger update on enriched model.
  #
  # @param model [Event] enriched model
  # @param callback [Function] end enrichment callback. Default to null.
  enrichCharacters = (model, callback) ->
    callback = if 'function' is utils.type callback then callback else () -> true
    raws = model.characters.concat()
    loaded = []
    doLoad = false
    model.characters = []
    # try to replace all characters by their respective Backbone Model
    for raw in raws
      id = if 'object' is utils.type raw then raw._id else raw
      loaded.push id
      character = Item.collection.get id
      if !(character?) and 'object' is utils.type raw
        character = new Item raw
        Item.collection.add character
      else if !(character?)
        doLoad = true
        character = id
      model.characters.push character
    
    if doLoad
      # load missing characters
      processItems = (err, items) =>
        unless err? or null is _.find(items, (item) -> item._id is loaded[0])
          sockets.game.removeListener 'getItems-resp', processItems
          model.characters = []
          # immediately add enriched characters
          for raw in items
            existing = Item.collection.get raw._id
            if existing?
              model.characters.push existing
              # reuse existing but merge its values
              Item.collection.add raw
            else
              # add new character
              character = new Item raw
              Item.collection.add character
              model.characters.push character

          callback()

      sockets.game.on 'getItems-resp', processItems
      sockets.game.emit 'getItems', loaded
    else
      callback()

  # Client cache of players.
  # Wired to the server through socket.io
  class _Players extends Base.Collection

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'Player'

    # **private**
    # Callback invoked when a database creation is received.
    # Adds the model to the current collection if needed, and fire event 'add'.
    # Extension to resolve characters when needed
    #
    # @param className [String] the modified object className
    # @param model [Object] created model.
    _onAdd: (className, model) =>
      return unless className is @_className
      
      # resolves characters object if possible
      if 'characters' of model and Array.isArray changes.characters
        # calls inherited merhod
        enrichCharacters model, => super className, model
      else
        # calls inherited merhod
        super className, model

    # **private**
    # Callback invoked when a database update is received.
    # Update the model from the current collection if needed, and fire event 'update'.
    # Extension to resolve characters when needed
    #
    # @param className [String] the modified object className
    # @param changes [Object] new changes for a given model.
    _onUpdate: (className, changes) =>
      return unless className is @_className

      # resolves characters object if possible
      if 'characters' of changes and Array.isArray changes.characters
        enrichCharacters changes, => super className, changes
      else
        # Call inherited merhod
        super className, changes

  # Player account.
  class Player extends Base.Model

    # Local cache for models.
    @collection: new _Players @

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'Player'

    # **private**
    # List of properties that must be defined in this instance.
    _fixedAttributes: ['email', 'provider', 'lastConnection', 'firstName', 'lastName', 'password', 'isAdmin', 'characters', 'prefs']

    # bind the Backbone attribute and the MongoDB attribute
    idAttribute: '_id'

    # Player constructor.
    #
    # @param attributes [Object] raw attributes of the created instance.
    constructor: (attributes) ->
      # and now initialize the Player
      super attributes
      if Array.isArray @characters
        # constructs Items for the corresponding characters
        enrichCharacters @
        
      # update if one of characters item was removed
      app.router.on 'modelChanged', (kind, model) => 
        return unless kind is 'remove' and !@equals model
        modified = false
        @characters = _.filter @characters, (character) -> 
          if model.equals character
            modified = true
            false
          else
            true
        # indicate that model changed
        if modified
          console.log "update player #{@id} after removing a linked characters #{model.id}"
          @trigger 'update', @, characters: @characters

    # **private** 
    # Method used to serialize a model when saving and removing it
    # Extend inherited method to avoid sending from item, to avoid recursion, before returning JSON representation 
    #
    # @return a serialized version of this model
    _serialize: => 
      attrs = super()
      if Array.isArray attrs.characters
        attrs.characters = _.map attrs.characters, (character) -> character?.id
      attrs