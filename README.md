# Habitv Static Update Repository

This repository hosts **public static artifacts** used by Habitv startup plugin/tool updates.
It is not the Habitv application source code repository.

## GitHub Pages

This repository is expected to be published via GitHub Pages.

- Target public base URL: `https://mika3578.github.io/habitv-repo/repository`
- All downloads must remain public and unauthenticated.
- Do not use private tokens or GitHub Packages for update delivery.

## Artifact layout rules

Artifacts must be published under a Maven-like path rooted at `repository/`.
Keep artifact file names/version folders stable for clients that already depend on them.

## Historical version retention warning

Do **not** delete historical versions that may still be referenced by existing Habitv clients.
Removing previously published files can break updates for users pinned to older manifests/versions.
