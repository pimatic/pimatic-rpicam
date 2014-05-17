
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
          mobileFrontend.registerAssetFile 'js', "pimatic-rpicam/app/rpicam-item.coffee"
          mobileFrontend.registerAssetFile 'js', "pimatic-rpicam/app/rpicam-page.coffee"
          mobileFrontend.registerAssetFile 'html', "pimatic-rpicam/app/rpicam-item.html"
          mobileFrontend.registerAssetFile 'html', "pimatic-rpicam/app/rpicam-page.jade"
          mobileFrontend.registerAssetFile 'css', "pimatic-rpicam/app/rpicam.css"
        else
          env.logger.warn "rpicam could not find mobile-frontend. No gui will be available"

      app.get('/rpicam/preview.jpg', (req, res) =>
        res.sendfile(device.picFile)
      )

  ###
  Possible Pipe-Commands:
  ca 1  start video capture
  ca 0  stop video capture
  im    capture image
  tl    start timelapse, parameter is time between images in 1/10 seconds.
  tl 0  stop timelapse
  px    set video+img resolution/framerate (AAAA BBBB CC DD EEEE FFFF; video = AxB px, C fps, boxed 
        with D fps, image = ExF px)
  sh    set sharpness (range: [-100;100]; default: 0)
  co    set contrast (range: [-100;100]; default: 0)
  br    set brightness (range: [0;100]; default: 50)
  sa    set saturation (range: [-100;100]; default: 0)
  is    set ISO (range: [100;800]; default: 0=auto)
  vs 1  turn on video stabilisation
  vs 0  turn off video stabilisation
  ec    set exposure compensation (range: [-10;10]; default: 0)
  em    set exposure mode (range: [off/auto/night/nightpreview/backlight/spotlight/sports/snow/
        beach/verylong/fixedfps/antishake/fireworks]; default: auto)
  wb    set white balance (range: [off/auto/sun/cloudy/shade/tungsten/fluorescent/incandescent/
        flash/horizon]; default: auto)
  mm    set metering mode (range: [average/spot/backlit/matrix]; default: average)
  ie    set image effect (range: [none/negative/solarise/posterize/whiteboard/blackboard/sketch/
        denoise/emboss/oilpaint/hatch/gpen/pastel/watercolour/film/blur/saturation/colourswap/
        washedout/posterise/colourpoint/colourbalance/cartoon]; default: none)
  ce    set colour effect (A BB CC; A=enable/disable, effect = B:C)
  ro    set rotation (range: [0/90/180/270]; default: 0)
  fl    set flip (range: [0;3]; default: 0)
  ri    set sensor region (AAAAA BBBBB CCCCC DDDDD, x=A, y=B, w=C, h=D)
  qu    set output image quality (range: [0;100]; default: 85)
  bi    set output video bitrate (range: [0;25000000]; default: 17000000)
  rl 0  disables raw layer
  rl 1  enables raw layer
  ru 0  halt RaspiMJPEG and release camera
  ru 1  restart mjpeg-stream
  md 1  start motion detection
  md 0  stop motion detection
  ###

  class RpiCamDevice extends env.devices.Device

    attributes:
      enabled:
        description: "camera enabled"
        type: Boolean
        labels: ['on', 'off']
      recording:
        description: "video recording status"
        type: Boolean
        labels: ['recording', 'stopped']

    actions: 
      enableCamera:
        description: "start the live preview"
      disableCamera:
        description: "stop the live preview"
      recordImage:
        description: "record a image"
      recordVideoStart:
        description: "start video capture"
      recordVideoStop:
        description: "stop video capture"

    commandFIFO: '/home/pi/FIFO'
    picFile: '/dev/shm/mjpeg/cam.jpg' 

    constructor: (@plugin) ->
      @name = "Raspberry Pi Camera"
      @id = "rpicam"
      super()

    _executeCommand: (cmd) ->
      deferred = Q.defer()
      try
        fifo = fs.createWriteStream(@commandFIFO)
        fifo.end(cmd, 'ascii', => (deferred.resolve()) )
      catch e
        deferred.reject e
      return deferred.promise 

    getTemplateName: -> 'rpicam'

    enableCamera: -> @_executeCommand('ru 1')
    disableCamera: -> @_executeCommand('ru 0')
    recordImage: -> @_executeCommand('im')
    recordVideoStart: -> @_executeCommand('ca 1')
    recordVideoStop: -> @_executeCommand('ca 2')

    getEnabled: -> Q(yes)
    getRecording: -> Q(yes)


  # ###Finally
  # Create a instance of my plugin
  rpiCamPlugin = new RpiCam
  # and return it to the framework.
  return rpiCamPlugin