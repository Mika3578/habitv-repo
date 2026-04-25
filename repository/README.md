# repository/ layout guide

This folder is the public static artifact root served by GitHub Pages.

The **public base URL** for this folder is:

```
https://mika3578.github.io/habitv-repo/repository
```

## Maven-like artifact layout

Artifacts are stored in the repository filesystem at:

```
repository/com/dabi/habitv/<artifactId>/<version>/<file>
```

The corresponding **public URL** for each artifact is:

```
https://mika3578.github.io/habitv-repo/repository/com/dabi/habitv/<artifactId>/<version>/<file>
```

Examples:

- Plugin JAR
  - Filesystem path: `repository/com/dabi/habitv/youtube/4.1.0-SNAPSHOT/youtube-4.1.0-SNAPSHOT.jar`
  - Public URL: `https://mika3578.github.io/habitv-repo/repository/com/dabi/habitv/youtube/4.1.0-SNAPSHOT/youtube-4.1.0-SNAPSHOT.jar`
- External tool ZIP
  - Filesystem path: `repository/com/dabi/habitv/ffmpeg/7.1.1/ffmpeg-7.1.1-windows-x64.zip`
  - Public URL: `https://mika3578.github.io/habitv-repo/repository/com/dabi/habitv/ffmpeg/7.1.1/ffmpeg-7.1.1-windows-x64.zip`

## `plugins.txt`

`repository/plugins.txt` (filesystem path) is the plugin manifest/index consumed by Habitv.

Public URL: `https://mika3578.github.io/habitv-repo/repository/plugins.txt`

The exact production line format (including whether comments are supported) must be
verified from Habitv source before publishing production entries.
For bootstrap, keep this file minimal and do not invent unverified final entries.
