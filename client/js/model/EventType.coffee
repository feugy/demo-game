define [
  'model/BaseModel'
], (Base) ->

  # Client cache of event types.
  class _EventTypes extends Base.Collection

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'EventType'

  # Modelisation of a single Item Type.
  # Not wired to the server : use collections ItemTypes instead
  class EventType extends Base.Model

    # Local cache for models.
    @collection: new _EventTypes @

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'EventType'

    # **private**
    # List of model attributes that are localized.
    _i18nAttributes: ['name', 'desc', 'template']
    
    # **private**
    # List of properties that must be defined in this instance.
    _fixedAttributes: ['descImage', 'properties']