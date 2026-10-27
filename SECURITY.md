---
versions: {}
---

# Security Policy

WhittakerTech asks that security vulnerabilities be reported privately rather
than through public issues or pull requests. This file is the canonical source
of truth for which versions of Poly receive fixes; the YAML frontmatter above is
machine-readable and the table below mirrors it.

## Supported Versions

Poly follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
(see `CHANGELOG.md`). Released lines: 1.0.x, 1.1.x, 1.2.x and 1.3.x (latest
published: 1.3.0).

No version-support policy has been formally adopted for Poly, so no line is
declared in the frontmatter yet. See "Decisions pending" below.

| Version line | Support | EOL |
| ------------ | ------- | --- |
| _none declared_ | _pending_ | _pending_ |

Ruby, ActiveRecord and database compatibility (see `README.md` and the
CHANGELOG) describes what Poly runs on. It is not a statement about which Poly
versions receive security fixes.

## Reporting a Vulnerability

Please report suspected security vulnerabilities **privately**, using GitHub's
private vulnerability reporting for this repository:

**[Report a vulnerability](https://github.com/whittakertech/poly/security/advisories/new)**
(or open the repository's **Security** tab and choose **Report a vulnerability**).

Do not disclose vulnerabilities in public issues, pull requests or discussions.
Please include the affected version, a description of the problem, and steps to
reproduce it.

## Disclosure and Remediation

No disclosure or remediation process, response time, or schedule has been
formally adopted for this project, so none is promised here.

## Decisions pending

- Which Poly version lines receive `full` or `security` support, and any EOL
  dates. No support policy exists in the repository, so the frontmatter
  `versions` mapping is intentionally empty.
