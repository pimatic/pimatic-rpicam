
$(document).on( "templateinit", (event) ->
  # define the item class
  class RpiCamDeviceItem extends pimatic.DeviceItem
    
    constructor: (templData, @device) ->
      super(templData, @device)
      @previewUrl = '/rpicam/preview.jpg'
      @previewImageUrl = ko.observable(@previewUrl)
      @updatePreview()
      @infoText = ko.computed( =>
        enabled = @getAttribute("enabled").value
        recording = @getAttribute("recording").value
        unless enabled()? and recording()? then return ""
        return (
          if enabled() then __("Enabled") + " (" + (if recording() then __("Recording") else __("Idle")) + ")" 
          else __("Disabled")
        )
      )
      # Do something, after create: console.log(this)
    afterRender: (elements) -> 
      super(elements)
      #@imageEle = $(elements).find('rpicam-preview-thumb')
      @updateTimeout = setInterval((=> @updatePreview()), 1000);
      # Do something after the html-element was added
    # onRecordImagePress: ->
    #   $.get("/api/device/#{@deviceId}/recordImage").fail(ajaxAlertFail)

    onShowPress: ->
      pimatic.rpicam = this
      jQuery.mobile.changePage '#rpicam', transition: 'slide'

    updatePreview: ->
      # to prevent caching
      time = (new Date()).getTime()
      @previewImageUrl("#{@previewUrl}?#{time}")
      
  # register the item-class
  pimatic.templateClasses['rpicam'] = RpiCamDeviceItem
)