# DNS Setup: poly.whittakertech.com

**Status:** DNS record created by Lee on 2026-08-16 -- record is live (confirmed via `dig`/`curl`: resolves through Cloudflare's proxy and routes to GitHub Pages). Site content is pending until this epic reaches `master` and `docs.yml` publishes to `gh-pages`.

> **DO NOT create this record yourself.** This DNS record must be created by
> Lee (or another human with dashboard access to the `whittakertech.com`
> Cloudflare zone). Per this server's standing permanent-namespace rule, no
> pipeline agent (BA/TL/SD/QA/RM) may create, modify, or attempt to create
> this record via API or dashboard automation -- in this ticket or any later
> one.

## Context

Codex's published docs target for Poly is `https://poly.whittakertech.com`
(`.github/workflows/docs.yml`'s `codex_publish` job, `site_url:
https://poly.whittakertech.com`, merged in #194). That hostname does not
resolve yet -- no DNS record exists for it.

## Record to create

| Field | Value |
|---|---|
| Zone | `whittakertech.com` |
| Type | `CNAME` |
| Name | `poly` (resulting FQDN: `poly.whittakertech.com`) |
| Target | `whittakertech.github.io` |
| Proxy status | **Proxied** (orange-cloud) |
| TTL | Auto |

This matches the confirmed-live configuration for `mosaicjs.whittakertech.com`
(proxied CNAME to `whittakertech.github.io`, not DNS-only/grey-cloud).

## Why nothing else needs to happen

The `codex_publish` job (#194) already writes a matching `CNAME` file into
Poly's `gh-pages` branch on every deploy, via `peaceiris/actions-gh-pages`'s
`cname:` input computed from `site_url`. So once the DNS record above exists,
the GitHub Pages side of the custom domain is already self-maintaining --
creating the Cloudflare CNAME is the only remaining manual step.

## Verification

After creating the record, confirm it worked with the following checks.

1. **DNS resolves through Cloudflare's proxy**

   ```
   dig +short poly.whittakertech.com
   ```

   Expect one or more Cloudflare anycast IPs (matching the range observed for
   `mosaicjs.whittakertech.com`) -- not `NXDOMAIN` and not the origin's real
   IP.

2. **HTTPS response comes from Cloudflare**

   ```
   curl -sI https://poly.whittakertech.com
   ```

   Expect a `server: cloudflare` header and a `200` status. If it 404s
   immediately after DNS propagates, allow a few minutes for the next
   `docs.yml` run on `master` to catch up, since the `CNAME` file / Pages
   custom-domain association may not have settled yet.

3. **GitHub Pages config is correct**

   ```
   GET /repos/whittakertech/poly/pages
   ```

   Expect `cname` set to `poly.whittakertech.com`, and `https_certificate` /
   `protected_domain_state` showing an issued/verified state -- not stuck on
   `pending` for more than ~15-30 minutes after DNS propagates. If it is,
   re-check that the `CNAME` file landed correctly on `gh-pages` rather than
   assuming a DNS problem.

4. **Browser check**

   Load `https://poly.whittakertech.com` in a browser and confirm it shows
   Poly's actual published docs site -- not a GitHub 404 page or a Cloudflare
   error page.
