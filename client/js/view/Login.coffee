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
      super tagName: 'div', className:'login view'

    # the render method, which use the specified template
    render: =>
      super()
      @$('.loader').hide()

      # replace form inside view
      @$('.form-placeholder').replaceWith @_form
      @_form.find('form').addClass 'form-horizontal'
      @_form.find('[name]').wrap('<fieldset class="control-group"></fieldset>')
      @_form.find('[name="username"]').before "<label class='control-label'>#{i18n.labels.enterLogin}</label>"
      @_form.find('[name="password"]').before "<label class='control-label'>#{i18n.labels.enterPassword}</label>"
      @_form.show()

      # wire connection buttons and form
      @$('.google').attr 'href', "#{conf.apiBaseUrl}/auth/google"
      @$('.twitter').attr 'href', "#{conf.apiBaseUrl}/auth/twitter"
      @$('#login-form').attr 'action', "#{conf.apiBaseUrl}/auth/login"
      @$('#login-form').on 'submit', =>
        @$('.loader').show()
        # send back form into body
        @_form.hide().appendTo 'body'

      @$('.login').html(
        i18n.buttons.login
      ).click (event) => 
        event?.preventDefault()
        @$('#login-form').submit()
      
      # for chaining purposes
      @