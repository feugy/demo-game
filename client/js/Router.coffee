'use strict'

# configure requireJs
requirejs.config  
  paths:
    'async': 'lib/async-0.1.22-min'
    'backbone': 'lib/backbone-0.9.9-min'
    'bootstrap': 'lib/bootstrap-2.2.1-min'
    'hogan': 'lib/hogan-2.0.0-min'
    'i18n': 'lib/i18n-2.0.1-min'
    'jquery': 'lib/jquery-1.8.2-min'
    'jquery-transit': 'lib/jquery-transit-0.9.9-min'
    'moment': 'lib/moment-1.7.0-min'
    'nls': '../nls'
    'numeric': 'lib/jquery-ui-numeric-1.2-min'
    'socket.io': 'lib/socket.io-0.9.11-min'
    'template': '../template'
    'text': 'lib/text-2.0.0-min'
    'underscore': 'lib/underscore-1.4.3-min'
    'underscore.string': 'lib/unserscore.string-2.3.0-min'
    # shim for rules
    'mongodb': 'lib/shim/mongodb'
    
  shim:
    'async': 
      exports: 'async'
    'backbone': 
      deps: ['underscore', 'jquery']
      exports: 'Backbone'
    'bootstrap': 
      deps: ['jquery']
    'hogan': 
      exports: 'Hogan'
    'jquery': 
      exports: '$'
    'jquery-transit':
      deps: ['jquery']
    'moment':
      exports: 'moment'
    'numeric':
      deps: ['jquery-ui']
    'socket.io': 
      exports: 'io'
    'underscore': 
      exports: '_'

# initialize application global namespace. 
# do not rename ! Used by models.
window.app = {}

define [
  'underscore'
  'jquery'
  'backbone'
  'utils/sockets'
  'utils/common'
  'service/ImagesService'
  'service/RulesService'
  'view/Login'
  'view/World'
  'view/Enroll'
  'model/Player'
  # unwired dependencies
  'jquery-transit'
  'bootstrap'
  'utils/extensions'
  'mongodb'
], (_, $, Backbone, sockets, utils, ImagesService, RulesService, LoginView, WorldView, EnrollView, Player) ->

  router = null
    
  # tries to reconnect from the locally stored token, to avoid authentication
  #
  # @return true if the reconnection is inprogress
  reconnect = ->
    return false if app.connected
    token = localStorage.getItem 'app.token'
    unless token? 
      _.defer -> app.router.navigate 'login', trigger:true
    else
      app.connected = true
      connect token
    true
      
  # wired to the server with given token, and navigate to home when successfull.
  # 
  # @param token [String] the authentication token
  connect = (token) ->
    console.info "try to wire on server..."
    isLoggingOut = false
  
    # Connects token
    sockets.connect token, 'app.token', =>
      console.info "successfully loged in !"
      # construct a BAckbone model to replace raw player
      Player.collection.add app.player
      app.player = Player.collection.get app.player._id
      
      # run current route or goes to world map
      current = window.location.pathname.replace conf.basePath, ''
      current = 'world' if current is 'login'
      
      # reset Backbone.history internal state to allow re-running current route
      Backbone.history.fragment = null
      app.router.navigate current, trigger:true
    , (err) =>
      # something goes wrong !
      router._onLogin err.replace('handshake ', '').replace 'error ', ''
      
  class Router extends Backbone.Router

    # Define some URL routes (order is significant: evaluated from first to last)
    routes:
      'world': '_onWorld'
      'enroll': '_onEnroll'
      'login': '_onLogin'
      '*route': '_onNotFound'
      
    # Router constructor: defines routes and starts history tracking in pushState mode
    constructor: ->
      super()
      # immediately initialize global router
      app.router = @
      # service singletons
      app.imagesService = new ImagesService()
      app.rulesService = new RulesService()
      
      # general error handler
      @on 'serverError', (err, details) ->
        console.error "server error: #{if typeof err is 'object' then err.message else err}"
        console.dir details
        
      # global key handler
      $(window).on 'keyup', (event) =>
        # broadcast on the event bus.
        @trigger 'key', 
          target: event.target
          keyCode: event.which
          shift: event.shiftKey
          ctrl: event.ctrlKey
          meta: event.metaKey
      $(window).on 'resize', _.debounce @_onResize, 100
      
      $('body').on 'click', '.logout', (event) => 
        event?.preventDefault()
        app.router.trigger 'logout'
      
      # run current route
      Backbone.history.start
        root: conf.basePath
        pushState: true

    # **private**
    # Handle that set trigger the resize event after debouncing it
    _onResize: => @.trigger 'resize'
      
    # **private**
    # Handle login steps: display form, manage returned token or errors
    #
    # @param error [String] allow to specify manually a login error
    _onLogin: (error) =>
      params = utils.queryParams()
      if error? or params?.error?
        console.error "Failed to login: #{error or params.error}"
        return window.location = "#{conf.basePath}login"
      else if params?.token?
        return connect params.token
      # display login form
      form = $('#login-stock').show()
      $('#main').removeClass('fullscreen').empty().append new LoginView(form).render().$el
      @_onResize()
  
    # **private**
    # Display enrollment view.
    _onEnroll: =>
      # try to reconnect
      return if reconnect()   
      return @navigate 'world', {trigger:true} if app.player.characters?.length > 0 
      $('#main').removeClass('fullscreen').empty().append new EnrollView().render().$el
      @_onResize()
    
    # **private**
    # Display world map
    _onWorld: =>
      # try to reconnect
      return if reconnect()    
      return @navigate 'enroll', {trigger:true} unless app.player.characters?.length > 0
      $('#main').addClass('fullscreen').empty().append new WorldView().render().$el
      @_onResize()
      
    # **private**
    # Invoked when a route that doesn't exists has been run.
    # 
    # @param route [String] the unknown route
    _onNotFound: (route) =>
      console.error "Unknown route #{route}"
      @navigate 'login', trigger:true

  router = new Router()