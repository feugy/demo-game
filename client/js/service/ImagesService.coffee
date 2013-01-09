define [
  'underscore'
], (_) ->

  # Instanciated as a singleton in `app.imagesService` by the Router
  class ImagesService

    # **private**        
    # Temporary storage of loading images.
    _pendingImages: []

    # **private**
    # Image local cache, that store Image objects
    _cache: {}
        
    # **private**
    # Timestamps added to image request to server, avoiding cache
    _timestamps: {}
    
    # Constructor. 
    constructor: ->
      app.router.on 'loadImage', @load
    
    # Load an image. Once it's available, `imageLoaded` event will be emitted on the bus.
    # If this image has already been loaded (url used as key), the event is imediately emitted.
    #
    # @param image [String] the image **ABSOLUTE** url
    # @return true if the image wasn't loaded, false if the cache will be used
    load: (image) =>
      isLoading = false
      return isLoading unless image?
      # Use cache if available, with a timeout to simulate asynchronous behaviour
      if image of @_cache
        _.defer =>
          app.router.trigger 'imageLoaded', true, image, "#{image}?#{@_timestamps[image]}"
      else unless image in @_pendingImages
        @_pendingImages.push image
        # creates an image facility
        imgData = new Image()
        # bind loading handlers
        $(imgData).load @_onImageLoaded
        $(imgData).error @_onImageFailed
        @_timestamps[image] = new Date().getTime()
        # adds a timestamped value to avoid browser cache
        imgData.src = "#{image}?#{@_timestamps[image]}"
        isLoading = true
      isLoading

    # Returns the image content from the cache, or null if the image was not requested yet
    getImage: (image) =>
      return null unless image of @_cache
      @_cache[image]

    # **private**
    # Handler invoked when an image finisedh to load. Emit the `imageLoaded` event. 
    #
    # @param event [Event] image loading success event
    _onImageLoaded: (event) =>
      src = event.target.src.replace /\?\d*$/, ''
      src = _.find @_pendingImages, (image) -> _(src).endsWith image
      return unless src?
      # Remove event from pending array
      @_pendingImages.splice @_pendingImages.indexOf(src), 1
      # Store Image object and emit on the event bus
      @_cache[src] = event.target
      app.router.trigger 'imageLoaded', true, src, "#{src}?#{@_timestamps[src]}"
  
    # **private**
    # Handler invoked when an image failed loading. Also emit the `imageLoaded` event.
    # @param event [Event] image loading fail event
    _onImageFailed: (event) =>
      src = event.target.src.replace /\?\d*$/, ''
      src = _.find @_pendingImages, (image) -> _(src).endsWith image
      return unless src?
      # Remove event from pending array
      @_pendingImages.splice @_pendingImages.indexOf(src), 1
      # Emit an error on the event bus
      app.router.trigger 'imageLoaded', false, src