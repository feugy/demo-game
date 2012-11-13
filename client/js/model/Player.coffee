'use strict'

define [
  'model/BaseModel'
  'model/Item'
  'utils/common'
], (Base, Item, utils) ->

  # Client cache of players.
  # Wired to the server through socket.io
  class _Players extends Base.Collection

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'Player'

    # **private**
    # Callback invoked when a database update is received.
    # Update the model from the current collection if needed, and fire event 'update'.
    # Extension to resolve type when needed
    #
    # @param className [String] the modified object className
    # @param changes [Object] new changes for a given model.
    _onUpdate: (className, changes) =>
      return unless className is @_className

      # enhance characters to only keep Backbone models
      if changes?.characters?
        for character, i in changes.characters
          changes.characters[i] = Item.collection.get if 'object' is utils.type character then character._id else character

      # Call inherited merhod
      super className, changes

  # Player account.
  class Player extends Base.Model

    # Local cache for models.
    @collection: new _Players @

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'Player'

    # bind the Backbone attribute and the MongoDB attribute
    idAttribute: '_id'

    # Player constructor.
    #
    # @param attributes [Object] raw attributes of the created instance.
    constructor: (attributes) ->
      # constructs Items for the corresponding characters
      if attributes?.characters?
        for character, i in attributes.characters
          # we got an object: adds it
          Item.collection.add character
          attributes.characters[i] = Item.collection.get character._id
      # and now initialize the Player
      super attributes