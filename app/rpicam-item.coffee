
$(document).on( "templateinit", (event) ->
  # define the item class
  class RpiCamDeviceItem extends pimatic.DeviceItem
    constructor: (data) ->
      super(data)
      # Do something, after create: console.log(this)
    afterRender: (elements) -> 
      super(elements)
      # Do something after the html-element was added
    onRecordImagePress: ->
      $.get("/api/device/#{@deviceId}/recordImage").fail(ajaxAlertFail)

    onShowPress: ->
      
  # register the item-class
  pimatic.templateClasses['rpicam'] = RpiCamDeviceItem
)