# repository/ layout guide

This folder is the public static artifact root served by GitHub Pages.

## Maven-like artifact layout

Use the following path convention:

`repository/com/dabi/habitv/<artifactId>/<version>/<file>`

Examples:

- Plugin JAR:
  `repository/com/dabi/habitv/youtube/4.1.0-SNAPSHOT/youtube-4.1.0-SNAPSHOT.jar`
- External tool ZIP:
  `repository/com/dabi/habitv/ffmpeg/7.1.1/ffmpeg-7.1.1-windows-x64.zip`

## `plugins.txt`

`repository/plugins.txt` is the plugin manifest/index consumed by Habitv.

The exact production line format (including whether comments are supported) must be
verified from Habitv source before publishing production entries.
For bootstrap, keep this file minimal and do not invent unverified final entries.
