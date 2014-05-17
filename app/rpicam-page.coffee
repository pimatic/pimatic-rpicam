# log-page
# ---------
tc = pimatic.tryCatch
$(document).on("pagecreate", '#rpicam', tc (event) ->

  class RpicamViewModel

    recording: ko.observable(no)
    enabled: ko.observable(no)

    constructor: ->
      @deviceId = pimatic.rpicam.deviceId
      @videoButtonText = ko.computed( =>
        if @recording() then __('Stop Recording') else __('Start Recording')
      )
      @startCameraText = ko.computed( =>
        if @enabled() then __('Enable Camera') else __('Disable Camera')
      )
      @previewUrl = '/rpicam/preview.jpg'
      @previewImageUrl = ko.observable(@previewUrl)

      enabledAttr = pimatic.rpicam.getAttribute('enabled')
      if enabledAttr.value()?
        @enabled(enabledAttr.value())
      recordingAttr = pimatic.rpicam.getAttribute('recording')
      if recordingAttr.value()?
        @recording(recordingAttr.value())

      console.log(ko.toJSON(this))

      @updateTimeout = setInterval((=> @updatePreview()), 1000/5);

    updatePreview: ->
      # to prevent caching
      time = (new Date()).getTime()
      @previewImageUrl("#{@previewUrl}?#{time}")

    onRecordVideoPress: -> 
      if @recording()
        $.get("/api/device/#{@deviceId}/recordVideoStop").fail(ajaxAlertFail)
      else
        $.get("/api/device/#{@deviceId}/recordVideoStart").fail(ajaxAlertFail)
    onCaptureImagePress: -> 
      $.get("/api/device/#{@deviceId}/recordImage").fail(ajaxAlertFail)
    onEnableCameraPress: -> 
      if @recording()
        $.get("/api/device/#{@deviceId}/enableCamera").fail(ajaxAlertFail)
      else
        $.get("/api/device/#{@deviceId}/disableCamera").fail(ajaxAlertFail)

  try
    pimatic.pages.rpicam = rpicam = new RpicamViewModel()

    pimatic.socket.on("device-attribute", tc (attrEvent) -> 
      unless attrEvent.id is pimatic.rpicam.deviceId then return
      console.log attrEvent
      switch attrEvent.name
        when 'enabled' then rpicam.enabled(attrEvent.value)
        when 'recording' then rpicam.recording(attrEvent.value)
    )

    ko.applyBindings(rpicam, $('#rpicam')[0])
  catch e
    TraceKit.report(e)
  return
)