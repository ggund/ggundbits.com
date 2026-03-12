# ggundbits.com

Source for [ggundbits.com](https://ggundbits.com) — cloud engineering guides, demos, and deep dives.

Built with Jekyll + GitHub Pages using the [Minimal Mistakes](https://mmistakes.github.io/minimal-mistakes/) theme.

## Blog Posts

| Post | Project Repo |
|------|-------------|
| [ServiceNow MID Server on EKS Auto Mode](https://ggundbits.com/servicenow-mid-server-eks/) | [servicenow-mid-server-eks](https://github.com/ggund/servicenow-mid-server-eks) |

## Local Development

```bash
cd docs
bundle install
bundle exec jekyll serve
```

Then open `http://localhost:4000`.

## Adding a New Post

Create `docs/_posts/YYYY-MM-DD-your-post-title.md` with front matter:

```yaml
---
layout: single
title: "Your Post Title"
date: YYYY-MM-DD
permalink: /your-post-slug/
categories: [category1]
tags: [tag1, tag2]
toc: true
toc_sticky: true
excerpt: "Short description."
---
```

Push to `main` — GitHub Pages rebuilds automatically.
