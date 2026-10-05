# Production checklist

The failure this prevents is boring and common: a site goes live while still
`noindex` from an early build, or ships without `robots.txt`, `sitemap.xml`,
`llms.txt` or security headers. Another is relaunching after edits and silently
breaking discoverability.

`prod-checkup.sh` automates the static parts and, with `--url`, the deployed
response. Run it before every launch and after every significant change.

## Before the first launch

- [ ] `robots.txt` present and **not** `Disallow: /`. It should allow crawlers
      and point to the sitemap.
- [ ] `sitemap.xml` (or a generated `sitemap.ts`) lists every public URL.
- [ ] `llms.txt` present; AI crawlers cite a site better when it explains itself.
- [ ] No stray global `noindex`. Search the source and the deployed HTML.
- [ ] Security headers set: `Strict-Transport-Security`,
      `X-Content-Type-Options: nosniff`, `X-Frame-Options` or CSP
      `frame-ancestors`, and a `Content-Security-Policy`.
- [ ] HTTPS enforced, HTTP redirects to HTTPS.
- [ ] Canonical URLs and `metadataBase` correct (Next.js).
- [ ] Contact/mail form: server-fixed recipient, schema validation, rate limit,
      captcha, no provider error leaked. See `docs/security.md`.
- [ ] Error pages do not leak stack traces or secrets.

## Next.js specifics

```ts
// app/robots.ts
import type { MetadataRoute } from "next";
export default function robots(): MetadataRoute.Robots {
  return {
    rules: [{ userAgent: "*", allow: "/" }],
    sitemap: "https://example.com/sitemap.xml",
  };
}
```

```ts
// next.config.ts — security headers
const securityHeaders = [
  { key: "Strict-Transport-Security", value: "max-age=63072000; includeSubDomains; preload" },
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "X-Frame-Options", value: "DENY" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
];
export default { async headers() { return [{ source: "/(.*)", headers: securityHeaders }]; } };
```

## Relaunch / after modifications

This is the part people forget. After a change on a live site:

- [ ] Re-run `prod-checkup.sh --url=https://your-domain`.
- [ ] Confirm the page is not serving `noindex` (a build flag, a staging env var
      or a preview setting can reintroduce it).
- [ ] Confirm new routes were added to the sitemap.
- [ ] Re-check headers if `next.config` changed.
- [ ] Verify the form still rejects abuse (the checks are static; a quick manual
      spam attempt confirms the runtime path).

## Staging vs production

Keep the difference explicit. If staging sets `noindex` through an env var, make
sure production cannot inherit it. The most reliable rule: **`noindex` is set
per-page with intent, never globally by accident.**
