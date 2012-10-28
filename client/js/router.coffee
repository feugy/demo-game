'use strict'

# configure requireJs
requirejs.config  
  paths:
    'backbone': 'lib/backbone-0.9.2-min'
    'i18n': 'lib/i18n-2.0.1-min.js'
    'jquery': 'lib/jquery-1.8.2-min'
    'nls': '../nls'
    'socket.io': 'lib/socket.io-0.9.10-min'
    'template': '../template'
    'text': 'lib/text-2.0.0-min.js'
    'underscore': 'lib/underscore-1.3.3-min'
    'underscore.string': 'lib/unserscore.string-2.2.0rc-min'
  shim:
    'backbone': 
      deps: ['underscore', 'jquery']
      exports: 'Backbone'
    'underscore': 
      exports: '_'
    'jquery': 
      exports: '$'
    'socket.io': 
      exports: 'io'

# initialize application global namespace
window.app = {}

define [
  'underscore'
  'jquery' 
  'socket.io'
  'backbone'
], (_, $, io, Backbone) ->
  $('body').append 'toto'
  