
module.exports = (env) ->

  # ###require modules included in pimatic
  # To require modules that are included in pimatic use `env.require`. For available packages take 
  # a look at the dependencies section in pimatics package.json

  # Require [convict](https://github.com/mozilla/node-convict) for config validation.
  convict = env.require "convict"

  # Require the [Q](https://github.com/kriskowal/q) promise library
  Q = env.require 'q'

  # Require the [cassert library](https://github.com/rhoot/cassert).
  assert = env.require 'cassert'

  fs = require 'fs'

  class RpiCam extends env.plugins.Plugin

    init: (app, @framework, config) =>
      # Require your config schema
      @conf = convict require("./rpicam-config-schema")
      # and validate the given config.
      @conf.load(config)
      @conf.validate()

      device = new RpiCamDevice(this)
      @framework.registerDevice(device)

      @framework.on "after init", =>
        mobileFrontend = @framework.getPlugin 'mobile-frontend'
        if mobileFrontend?
          # mobileFrontend.registerAssetFile 'js', "pimatic-datalogger/app/datalogger-page.coffee"
          # mobileFrontend.registerAssetFile 'css', "pimatic-datalogger/app/css/datalogger.css"
          # mobileFrontend.registerAssetFile 'html', "pimatic-datalogger/app/datalogger-page.jade"
        else
          env.logger.warn "rpicam could not find mobile-frontend. No gui will be available"

      app.get('/rpicam/cam.jpg', (req, res) =>
        res.sendfile(device.picFile)
      )

  class RpiCamDevice extends env.devices.Device

    commandFIFO: '/var/www/FIFO'
    picFile: '/dev/shm/mjpeg/cam.jpg' 

    constructor: (@plugin) ->
      @name = "Raspberry Pi Camera"
      @id = "rpi-cam"
      super()

    _executeCommand: (cmd) ->
      deferred = Q.defer()
      try
        fifo = fs.createWriteStream(@commandFIFO)
        fifo.end(cmd, 'ascii', => (deferred.resolve()) )
      catch e
        deferred.reject e
      return deferred.promise 

    startCamera: -> @_executeCommand('start camera')
    stopCamera: -> @_executeCommand('stop camera')
    recordImage: -> @_executeCommand('record image')
    recordVideoStart: -> @_executeCommand('record video start')
    recordVideoStop: -> @_executeCommand('record video stop')


  # ###Finally
  # Create a instance of my plugin
  rpiCamPlugin = new RpiCam
  # and return it to the framework.
  return rpiCamPlugin