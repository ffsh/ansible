# Documentation site

This directory contains the Freifunk Südholstein Ansible documentation site,
built with Astro and Starlight. It is independent of the Ansible runtime and
uses its own npm dependencies.

## Requirements

Node.js 22.23.4 or newer and npm.

## Commands

Run these commands from `docs/`:

```
npm ci
npm run dev
```

Build and preview the static site with:

```
npm run build
npm run preview
```

Add Markdown or MDX pages under `src/content/docs/`. Pages in `guides/` and
`reference/` are added to their corresponding sidebar sections automatically.

## Publishing

The GitHub Actions workflow builds documentation changes in pull requests and
deploys successful pushes to `main` to GitHub Pages. In the repository settings,
set **Pages → Build and deployment → Source** to **GitHub Actions**.

