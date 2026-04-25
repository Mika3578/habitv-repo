# Habitv Static Update Repository

This repository hosts **public static artifacts** used by Habitv startup plugin/tool updates.
It is not the Habitv application source code repository.

## GitHub Pages

This repository is published via GitHub Pages from the repository root.

- All downloads must remain public and unauthenticated.
- Do not use private tokens or GitHub Packages for update delivery.

## Artifact layouts

### Legacy root layout

Existing artifacts are stored at the repository root under `com/dabi/habitv/…` with a
matching root-level `plugins.txt`. They are served at:

```
https://mika3578.github.io/habitv-repo/com/dabi/habitv/…
```

Do **not** delete or restructure these paths; existing Habitv clients depend on them.

### `repository/` subfolder layout

New artifacts should be published under the `repository/` subfolder using the same
Maven-like path convention. They are served at:

```
https://mika3578.github.io/habitv-repo/repository/com/dabi/habitv/…
```

The public base URL for this layout is:

```
https://mika3578.github.io/habitv-repo/repository
```

## Historical version retention warning

Do **not** delete historical versions that may still be referenced by existing Habitv clients.
Removing previously published files can break updates for users pinned to older manifests/versions.
