# #rpi-cam configuration options
module.exports = {
  title: "rpi-cam config"
  type: "object"
  properties:
    raspimjpegSettingsFile:
      description: "raspimjpeg settings file"
      type: "string"
      default: "/etc/raspimjpeg"
}
