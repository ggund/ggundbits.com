# Post feedback (👍 / 👎)

The site shows **Was this post helpful?** on every blog post. Votes are stored in the browser so each reader can only vote once per post.

## Show totals for everyone (optional)

GitHub Pages is static—there is no server—so **aggregated counts** need a tiny backend. This repo includes a **Cloudflare Worker** that stores counts in **KV**.

1. Install [Wrangler](https://developers.cloudflare.com/workers/wrangler/install-and-update/) and log in.
2. Create a KV namespace:
   ```bash
   cd docs/workers
   npx wrangler kv namespace create POST_FEEDBACK
   ```
3. Copy `wrangler.toml.example` → `wrangler.toml` and paste the KV **id**.
4. Deploy:
   ```bash
   npx wrangler deploy
   ```
5. In `docs/_config.yml`, set:
   ```yaml
   post_feedback_worker_url: "https://ggundbits-post-feedback.<your-subdomain>.workers.dev"
   ```
6. Rebuild and publish the site.

CORS allows any origin by default; tighten `Access-Control-Allow-Origin` in the Worker if you want only `https://ggundbits.com`.

## Turn off on one post

Front matter:

```yaml
feedback: false
```
