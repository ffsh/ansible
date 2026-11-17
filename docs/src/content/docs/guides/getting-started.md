---
title: Getting started
description: Set up and work with the local documentation site.
---

## Requirements

The documentation site requires Node.js 22.23.4 or newer and npm. The
repository's devcontainer provides Node.js 22.

## Run locally

From the repository root:

```sh
cd docs
npm ci
npm run dev
```

The development server prints the local URL. Stop it with `Ctrl+C`.

To check the production build:

```sh
npm run build
```

## Add a page

Add a Markdown or MDX file under `src/content/docs/`. Put task-oriented
instructions in `guides/` and concise descriptions of repository components in
`reference/`; both sections appear in the sidebar automatically.
