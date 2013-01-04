define [
  'model/BaseModel'
], (Base) ->

  # Client cache of item types.
  class _ItemTypes extends Base.Collection

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'ItemType'

  # Modelisation of a single Item Type.
  # Not wired to the server : use collections ItemTypes instead
  class ItemType extends Base.Model

    # Local cache for models.
    @collection: new _ItemTypes @

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'ItemType'

    # **private**
    # List of model attributes that are localized.
    _i18nAttributes: ['name', 'desc']
    
    # **private**
    # List of properties that must be defined in this instance.
    _fixedAttributes: ['descImage', 'images', 'properties', 'quantifiable']