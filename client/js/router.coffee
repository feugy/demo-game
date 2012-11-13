'use strict'

# configure requireJs
requirejs.config  
  paths:
    'async': 'lib/async-0.1.22-min'
    'backbone': 'lib/backbone-20122910'
    'hogan': 'lib/hogan-2.0.0-min'
    'i18n': 'lib/i18n-2.0.1-min'
    'jquery': 'lib/jquery-1.8.2-min'
    'jquery-ui': 'lib/jquery-ui-1.9.1-min'
    'mongodb': 'lib/shim/mongodb'
    'nls': '../nls'
    'socket.io': 'lib/socket.io-0.9.11-min'
    'template': '../template'
    'text': 'lib/text-2.0.0-min'
    'underscore': 'lib/underscore-1.3.3-min'
    'underscore.string': 'lib/unserscore.string-2.2.0rc-min'
    
  shim:
    'async': 
      exports: 'async'
    'backbone': 
      deps: ['underscore', 'jquery']
      exports: 'Backbone'
    'hogan': 
      exports: 'Hogan'
    'jquery': 
      exports: '$'
    'jquery-ui': 
      deps: ['jquery']
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
  'view/Map'
  'model/Player'
  # unwired dependencies
  'jquery-ui'
  'utils/extensions'
], (_, $, Backbone, sockets, utils, ImagesService, RulesService, LoginView, MapView, Player) ->

  router = null
  
  # tries to reconnect from the locally stored token, to avoid authentication
  #
  # @return true if the reconnection is inprogress
  reconnect = ->
    console.log app.connected
    return false if app.connected
    token = localStorage.getItem 'app.token'
    console.log token
    return true unless token?
    app.connected = true
    connect token 
    return true

  # wired to the server with given token, and navigate to home when successfull.
  # 
  # @param token [String] the authentication token
  connect = (token) ->
    console.info "try to wire on server..."

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
      'test': '_onTest'
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
        
      # run current route
      Backbone.history.start
        root: conf.basePath
        pushState: true

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
      $('#main').empty().append new LoginView(form).render().$el
  
    # **private**
    # Display world map.
    _onWorld: =>
      # try to reconnect
      return if reconnect()    
      $('#main').empty().append "<h1>Coucou !</h1>"
      #$('#main').empty().append new MapView().render().$el
    
    # **private**
    # Display test page
    _onTest: =>
      # try to reconnect
      return if reconnect()    
      $('#main').empty().append "<h1>Hi #{app.player?.get 'firstName'}</h1>"
      
    # **private**
    # Invoked when a route that doesn't exists has been run.
    # 
    # @param route [String] the unknown route
    _onNotFound: (route) =>
      console.error "Unknown route #{route}"
      @navigate 'login', trigger:true

  router = new Router()