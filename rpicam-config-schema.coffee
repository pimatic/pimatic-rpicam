# #my-plugin configuration options

# Declare your config option for your plugin here. 

# Defines a `node-convict` config-schema and exports it.
module.exports =
  raspimjpegSettingsFile:
    doc: "raspimjpeg settings file"
    format: String
    default: "/etc/raspimjpeg"