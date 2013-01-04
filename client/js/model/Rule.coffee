define [], ->

  # Game rules on client side only contains the `canExecute()` part:
  class Rule
    
    # Activation status. True by default
    active: true

    # Construct a rule, with a friendly name and a category.
    constructor: (@name, @category = '') ->
   
    # This method indicates wheter or not the rule apply to a given situation.
    # Beware: `canExecute`  is intended to be invoked on server and client side, thus, database access are not allowed.
    # This method must be overloaded by sub-classes
    #
    # @param actor [Item] the concerned actor
    # @param target [Item] the concerned target
    # @param callback [Function] called when the rule is applied, with two arguments:
    #   @param err [String] error string. Null if no error occured
    #   @param apply [Boolean] true if the rule apply, false otherwise.
    canExecute: (actor, target, callback) =>
      throw "#{module.filename}.canExecute() is not implemented yet !"