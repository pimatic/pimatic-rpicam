module.exports = (env) ->

  # ###require modules included in pimatic
  # To require modules that are included in pimatic use `env.require`. For available packages take 
  # a look at the dependencies section in pimatics package.json

  Promise = env.require 'bluebird'
  convict = env.require "convict"
  assert = env.require 'cassert'

  fs = Promise.promisifyAll(require 'fs')

  class RpiCam extends env.plugins.Plugin

    init: (app, @framework, config) =>
      raspimjpegSettingsFile = config.raspimjpegSettingsFile

      deferred = Promise.pending()

      files = {}

      fs.readFileAsync(raspimjpegSettingsFile, 'utf8').then( (settings) =>

        fileSettings = {
          previewImage: 'preview_path'
          imageFile: 'image_path'
          videoFile: 'video_path'
          status: 'status_file'
          control: 'control_file'
        }

        for name, text of fileSettings
          regexp = new RegExp("^#{text} (.+)$", "m")
          if (match = regexp.exec settings)?
            files[name] = match[1]
          else
            throw new Error ("Could not find #{text} in settings file.")

        device = new RpiCamDevice(this, files)
        @framework.deviceManager.registerDevice(device)

      ).catch( (error) =>
        env.logger.error(
          "Error reading raspimjpeg config file (#{raspimjpegSettingsFile}): #{error.message}"
        )
        env.logger.debug(error)
      ).done()

      @framework.on "after init", =>
        mobileFrontend = @framework.pluginManager.getPlugin 'mobile-frontend'
        if mobileFrontend?
          mobileFrontend.registerAssetFile 'js', "pimatic-rpicam/app/rpicam-item.coffee"
          mobileFrontend.registerAssetFile 'js', "pimatic-rpicam/app/rpicam-page.coffee"
          mobileFrontend.registerAssetFile 'html', "pimatic-rpicam/app/rpicam-item.html"
          mobileFrontend.registerAssetFile 'html', "pimatic-rpicam/app/rpicam-page.jade"
          mobileFrontend.registerAssetFile 'css', "pimatic-rpicam/app/rpicam.css"
        else
          env.logger.warn "rpicam could not find mobile-frontend. No gui will be available"

      app.get('/rpicam/preview.jpg', (req, res) =>
        if files.previewImage?
          res.sendfile(files.previewImage)
        else
          res.end()
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
        type: "boolean"
        labels: ['on', 'off']
      recording:
        description: "video recording status"
        type: "boolean"
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

    template: 'rpicam'

    _isEnabled: no
    _isRecording: no
    _lastStatus: null

    constructor: (@plugin, @files) ->
      @name = "Raspberry Pi Camera"
      @id = "rpicam"

      fs.watch(@files.status, {persistent: false}, (type) => @_readStatus().done() )
      @_readStatus().done()
      super()

    _readStatus: ->
      fs.readFileAsync(@files.status, 'utf8').then( (status) =>
        @_onStatusRead(status.trim())
      )

    _onStatusRead: (status) ->
      if status is @_lastStatus then return
      switch status
        when "ready"
          unless @_isEnabled is yes then @_setEnabled(yes)
          unless @_isRecording is no then @_setRecording(no)
        when "halted"
          unless @_isEnabled is no then @_setEnabled(no)
          unless @_isRecording is no then @_setRecording(no)
        when "video"
          unless @_isEnabled is yes then @_setEnabled(yes)
          unless @_isRecording is yes then @_setRecording(yes)
        else
          if (match = status.match("^Error: (.+)"))?
            env.logger.error("rpicam error from raspimjpeg: " + match[1])
            unless @_isEnabled is no then @_setEnabled(no)
            unless @_isRecording is no then @_setRecording(no)

      @emit "status #{status}"
      @_lastStatus = status

    _executeCommand: (cmd) ->
      deferred = Promise.pending()
      try
        fifo = fs.createWriteStream(@files.control)
        fifo.end(cmd, 'ascii', => (deferred.resolve()) )
      catch e
        deferred.reject e
      return deferred.promise 

    _setEnabled: (state) =>
      @_isEnabled = state
      @emit 'enabled', state

    _setRecording: (state) =>
      @_isRecording = state
      @emit 'recording', state

    enableCamera: -> 
      if @_isEnabled then return Promise.resolve()

      deferred = Promise.pending()
      @_executeCommand('ru 1').catch(deferred.reject)
      @once("status ready", deferred.resolve)
      return deferred.promise.timeout(5000)

    disableCamera: ->
      if @_isRecording
        return Promise.try => throw new Error("Can't disable camera while recording")
      unless @_isEnabled then return Promise.resolve()

      deferred = Promise.pending()
      @_executeCommand('ru 0').catch(deferred.reject)
      @once("status halted", deferred.resolve)
      return deferred.promise.timeout(5000)

    recordImage: -> 
      if @_isRecording
        return Promise.try => throw new Error("Can't capture image while recording")

      deferred = Promise.pending()
      @_executeCommand('im').catch(deferred.reject)
      @once("status image", deferred.resolve)
      return deferred.promise.timeout(5000)

    recordVideoStart: -> 
      if @_isRecording then return Promise.resolve()

      deferred = Promise.pending()
      @_executeCommand('ca 1').catch(deferred.reject)
      @once("status video", deferred.resolve)
      return deferred.promise.timeout(5000)

    recordVideoStop: -> 
      unless @_isRecording then return Promise.resolve()

      deferred = Promise.pending()
      @_executeCommand('ca 0').catch(deferred.reject)
      @once("status ready", deferred.resolve)
      @once("status halted", deferred.resolve)
      return deferred.promise.timeout(5000)

    getEnabled: -> Promise.resolve(@_isEnabled)
    getRecording: -> Promise.resolve(@_isRecording)


  # ###Finally
  # Create a instance of my plugin
  rpiCamPlugin = new RpiCam
  # and return it to the framework.
  return rpiCamPlugin
