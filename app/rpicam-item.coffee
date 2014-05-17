
$(document).on( "templateinit", (event) ->
  # define the item class
  class RpiCamDeviceItem extends pimatic.DeviceItem
    constructor: (data) ->
      super(data)
      @previewUrl = '/rpicam/preview.jpg'
      @previewImageUrl = ko.observable(@previewUrl)
      @updatePreview()
      # Do something, after create: console.log(this)
    afterRender: (elements) -> 
      super(elements)
      #@imageEle = $(elements).find('rpicam-preview-thumb')
      @updateTimeout = setInterval((=> @updatePreview()), 5000);
      # Do something after the html-element was added
    onRecordImagePress: ->
      $.get("/api/device/#{@deviceId}/recordImage").fail(ajaxAlertFail)

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