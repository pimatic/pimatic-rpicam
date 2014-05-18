# log-page
# ---------
tc = pimatic.tryCatch

$(document).on("pagecreate", '#rpicam', tc (event) ->

  class RpicamViewModel

    recording: ko.observable(no)
    enabled: ko.observable(no)
    hasPendingAction: ko.observable(no)

    constructor: ->
      @deviceId = pimatic.rpicam.deviceId
      @videoButtonText = ko.computed( =>
        if @recording() then __('Stop Recording') else __('Start Recording')
      )
      @startCameraText = ko.computed( =>
        if @enabled() then __('Disable Camera') else __('Enable Camera')
      )
      @previewUrl = '/rpicam/preview.jpg'
      @previewImageUrl = ko.observable(@previewUrl)

      enabledAttr = pimatic.rpicam.getAttribute('enabled')
      if enabledAttr.value()?
        @enabled(enabledAttr.value())
      recordingAttr = pimatic.rpicam.getAttribute('recording')
      if recordingAttr.value()?
        @recording(recordingAttr.value())

    updatePreview: ->
      # to prevent caching
      time = (new Date()).getTime()
      @previewImageUrl("#{@previewUrl}?#{time}")

    stopUpdatePreview: ->
      clearTimeout(@updateTimeout)

    startUpdatePreview: ->
      clearTimeout(@updateTimeout)
      @updateTimeout = setInterval((=> @updatePreview()), 1000/5);

    onRecordVideoPress: -> 
      if @recording()
        @_makeRequest('recordVideoStop')
      else
        @_makeRequest('recordVideoStart')
    onCaptureImagePress: -> 
       @_makeRequest('recordImage')
    onEnableCameraPress: -> 
      if @enabled()
        @_makeRequest('disableCamera').done( => @stopUpdatePreview() )
      else
        @_makeRequest('enableCamera').done( => @startUpdatePreview() )

    _makeRequest: (action) ->
      @hasPendingAction(yes)
      $.get("/api/device/#{@deviceId}/#{action}")
        .fail(ajaxAlertFail)
        .always( => @hasPendingAction(no) )

  try
    pimatic.pages.rpicam = rpicam = new RpicamViewModel()

    pimatic.socket.on("device-attribute", tc (attrEvent) -> 
      unless pimatic.rpicam? then return
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


$(document).on("pagehide", '#rpicam', (event) ->
  pimatic.pages.rpicam?.stopUpdatePreview()
  return
)

$(document).on("pagebeforeshow", '#rpicam', (event) ->
  unless pimatic.rpicam?
    jQuery.mobile.changePage '#index'
    return false
  pimatic.pages.rpicam.deviceId = pimatic.rpicam.deviceId
  pimatic.pages.rpicam.startUpdatePreview()
)