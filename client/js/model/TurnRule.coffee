define [], ->

  # Game turn-rules on client does not contains any methods
  class TurnRule

    # Activation status. True by default
    active: true

    # Construct a rule, with a friendly name and a rank
    constructor: (@name, @rank = 0) ->