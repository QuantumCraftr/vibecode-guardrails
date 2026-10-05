<!-- BEGIN:guardrails-nextjs -->
## Next.js specifics (do not skip)

- **Indexing is a production decision.** A new route is indexable by default and
  an already-public site may still carry a global `noindex` from an early build.
  Before a launch, confirm `robots.ts`/`robots.txt`, `sitemap.ts` and per-page
  metadata; after a relaunch, re-check the deployed HTML for `noindex`.
- **Every public site ships** `robots.txt`, `sitemap.xml` and `llms.txt`. New
  routes must be added to the sitemap.
- **Contact / mail routes are abuse surfaces.** A route that calls Resend,
  SendGrid or similar must: validate the body with a schema, rate-limit by IP,
  require a captcha for anonymous callers, fix the recipient server-side, and
  never echo provider errors to the client.
- **Security headers live in `next.config`.** Add HSTS, `X-Content-Type-Options`,
  `X-Frame-Options` or `frame-ancestors`, and a `Content-Security-Policy`.
- **Server-only code stays server-only.** No secrets in client components; mark
  sensitive modules `server-only`. Server Actions re-check auth themselves.
- **Do not add `force-dynamic`** to routes that read cached data; it defeats
  caching and inflates egress and cost.
- **`<img>` vs `next/image`**, `metadataBase`, canonical URLs and OpenGraph are
  set once per project; keep them consistent when adding pages.
<!-- END:guardrails-nextjs -->
