define [
  'underscore'
  'jquery'
  'backbone'
  'i18n!nls/common'
  'text!template/enroll.html'
  'utils/common'
], (_, $, Backbone, i18n, template, utils) ->

  # Trigger enrollment rule and get relevant informations
  class EnrollView extends Backbone.View
  
    events: 
      'click .trigger': '_onTriggerEnrollment'
      
    # **private**
    # rendering template
    _template: template
  
    # **private**
    # The enrollment rule name
    _ruleName: null
    
    # **private**
    # Array of awaited parameters
    _params: []
      
    # The view constructor.
    #
    # @param form [Object] login form already present inside DOM to attach inside template
    constructor: (@_form) ->
      super tagName: 'div', className:'enroll view'
      @bindTo app.player, 'update', @_onUpdatePlayer
      @bindTo app.router, 'rulesResolved', @_onRuleResolved
      # trigger rule resolution
      app.router.trigger 'resolveRules', app.player?.id
      
    # the render method, which use the specified template
    render: =>
      super()
      return @ unless @_ruleName
       
      container = @$('.parameters').empty()
      for param in @_params when param.name? and param.type?
        group = $("""<div class="control-group">
          <label class="control-label">#{param.label or param.name}</label>
        </div>""").appendTo(container)
        # creates a property widget per parameters
        $("<div class='controls' data-name='#{param.name}'></div>").propertyEdit(
          type: param.type.toLowerCase()
        ).appendTo group
        
      # for chaining purposes
      @
      
    # **protected**
    # This method provides template data for rendering
    #
    # @return an object used as template data (this by default)
    _getRenderData: -> 
      i18n: i18n
      action: @_ruleName or ''

    # **private**
    # Rule resolution handler: store returned rule name and its parameters. Re-render view
    #
    # @param args [Object] resolution arguments: playerId
    # @params rules [Object] applicable rules: an associated array with rule names id as key, and
    # as value an array containing for each concerned target:
    # @options rules target [Object] the target
    # @options rules params [Object] the awaited parameters specification
    # @options rules category/rule [String/Object] the rule category, or the whole role (wholeRule is true)
    _onRuleResolved: (args, rules) =>
      @unboundFrom app.router, 'rulesResolved'
      return unless _.keys(rules).length > 0
      @_ruleName = _.keys(rules)[0]
      @_params = rules[@_ruleName][0].params
      # render again
      @render()
      
    # **private**
    # Trigger the corresponding enrollmenet rule.
    #
    # @param event [Event] cancelled click event
    _onTriggerEnrollment: (event) =>
      event?.preventDefault()
      return unless @_ruleName
      params = {}
      properties = @$('[data-name]')
      # extract values for each property
      for property in properties
        params[$(property).data 'name'] = $(property).data('propertyEdit').options.value
      # trigger rule execution with parameters
      app.router.trigger 'executeRule', @_ruleName, app.player.id, params
    
    # **private**
    # Player modification: navigate to world view
    #
    # @param model [Object] the updated player
    _onUpdatePlayer: (model) =>
      app.player = model
      app.router.navigate 'world', trigger:true