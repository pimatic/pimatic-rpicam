# #rpi-cam configuration options

# Declare your config option for your plugin here. 

# Defines a `node-convict` config-schema and exports it.
module.exports = {
  title: "rpi-cam config"
  type: "string"
  properties:
    raspimjpegSettingsFile:
      description: "raspimjpeg settings file"
      type: "string"
      default: "/etc/raspimjpeg"
}
