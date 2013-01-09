define [
  'underscore'
  'jquery' 
  'socket.io'
  'async'
], (_, $, io, async) ->
  
  # internal state
  isLoggingOut = false
  app.connected = false

  # Needed on firefox to avoid errors when refreshing the page
  $(window).on 'beforeunload', () ->
    isLoggingOut = true
    undefined
    
  exports =
    
    # socket.io namespace for incoming updates
    updates: null
    
    # socket.io namespace for sending messages to server
    game: null
    
    # the connect function will try to connect with server. 
    # 
    # @param token [String] the autorization token, obtained during authentication
    # @param storageKey [String] key used to store authentication token in local storage
    # @param callback [Function] invoked when all namespaces have been connected.
    # @param errorCallback [Function] invoked when connection cannot be established, or is lost:
    # @option errorCallback err [String] the error detailed case, or null if no error occured
    connect: (token, storageKey, callback, errorCallback) ->    
      isLoggingOut = false
      connecting = true
      app.connected = false
  
      # wire logout facilities
      app.router.on 'logout', => 
        localStorage.removeItem storageKey
        isLoggingOut = true
        socket.emit 'logout'
        app.router.navigate 'login', trigger: true
      
      socket = io.connect conf.apiBaseUrl+'/', {query:"token=#{token}"}
          
      socket.on 'error', (err) ->
        if connecting or app.connected
          app.connected = false
          connecting = false
          errorCallback err
  
      socket.on 'disconnect', (reason) ->
        connecting = false
        app.connected = false
        exports[name].removeAllListeners() for name of exports
        return if isLoggingOut
        errorCallback if reason is 'booted' then 'kicked' else 'disconnected'
  
      socket.on 'connect', -> 
        # in parallel, get connected user and wired namespaces
        async.parallel [
          (end) ->
            # On connection, retrieve current connected player immediately
            socket.emit 'getConnected', (err, player) =>
              return end err if err?
              # stores the token to allow re-connection
              app.player = player
              localStorage.setItem storageKey, player.token
              # update socket.io query to allow reconnection with new token value
              socket.socket.options.query = "token=#{player.token}"
              end()
        ,
          (end) ->
            # wired both namespaces
            async.forEach ['game', 'updates'], (name, next) ->
              exports[name] = socket.of "/#{name}"
              exports[name].on 'connect', next
              exports[name].on 'connect_failed', next
            , end
        ], (err) ->
          connecting = false
          app.connected = false
          # parallel tasks common end
          return errorCallback err if err?
          # indicates that we are wired !
          app.connected = true
          $(window).trigger 'wired'
          callback()
          
  exports