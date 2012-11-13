'use strict'

define [
  'jquery'
  'backbone'
  'text!template/login.html'
  'i18n!nls/common'
], ($, Backbone, template, i18n) ->

  # Displays and handle user login.
  class LoginView extends Backbone.View
    
    # used for rendering
    i18n: i18n
    
    # **private**
    # mustache template rendered
    _template: template

    # **private**
    # login form already present inside DOM to attach inside template
    _form: null

    # The view constructor.
    #
    # @param form [Object] login form already present inside DOM to attach inside template
    constructor: (@_form) ->
      super tagName: 'div', className:'login-view'

    # the render method, which use the specified template
    render: =>
      super()
      @$el.find('.loader').hide()

      # replace form inside view
      @$el.find('.form-placeholder').replaceWith @_form
      @_form.find('input').wrap('<fieldset></fieldset>')
      @_form.find('[name="username"]').before "<label>#{i18n.labels.enterLogin}</label>"
      @_form.find('[name="password"]').before "<label>#{i18n.labels.enterPassword}</label>"
      @_form.show()

      # wire connection buttons and form
      @$el.find('.google').attr 'href', "#{conf.apiBaseUrl}/auth/google"
      @$el.find('.twitter').attr 'href', "#{conf.apiBaseUrl}/auth/twitter"
      @$el.find('#login-form').attr 'action', "#{conf.apiBaseUrl}/auth/login"
      @$el.find('#login-form').on 'submit', =>
        @$el.find('.loader').show()
        # send back form into body
        @_form.hide().appendTo 'body'

      @$el.find('.login').button(
        label: i18n.buttons.login
      ).click (event) => 
        event?.preventDefault()
        @$el.find('#login-form').submit()
      
      # for chaining purposes
      @