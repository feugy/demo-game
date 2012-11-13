'use strict'

define [
  'model/BaseModel'
], (Base) ->

  # Client cache of field types.
  class _FieldTypes extends Base.Collection

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'FieldType'

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