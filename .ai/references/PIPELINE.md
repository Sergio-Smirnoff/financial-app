# Pipeline

Central reusable workflows live in the parent repo's `.github/workflows/`. Every service
repo holds a thin caller that references them `@master`. Change a reusable workflow here
and all nine repos pick it up on their next run.

## Reusable workflows

| Workflow | Called by | Does |
|---|---|---|
| `backend-ci.yml` | 7 backend services | checkout service + parent, Java 21 temurin, `mvn install` the BOM and commons, `mvn -B verify` the service, then a no-push Docker build to validate the Dockerfile |
| `frontend-ci.yml` | frontend | Node 22, `npm ci`, `npm run lint`, `npm run build`, no-push Docker build |
| `parent-ci.yml` | financial-app-parent | Java 21, `mvn -B verify` over the commons modules |
| `backend-publish.yml` | 7 backend services | multi-arch build (`linux/amd64` on `ubuntu-latest`, `linux/arm64` on `ubuntu-24.04-arm`), push by digest, then merge into one manifest list |
| `frontend-publish.yml` | frontend | same multi-arch build-and-merge shape for the Next.js image |
| `release.yml` | 9 repos | reads the latest `v*` tag, applies the `bump` input (`major`/`minor`/`patch`), creates the tag and a GitHub Release with generated notes |

`backend-ci` takes `module` (required) and `parent_ref` (default `master`). It checks the
parent out of `Sergio-Smirnoff/financial-app-back-financial-app-parent` at that ref — which
is why unmerged `commons-*` changes fail service CI while passing locally.

## Triggers, per service repo

- `ci.yml` — every PR and every push to `develop`/`master`; produces the `ci / build` check
- `docker-publish.yml` — push to `master`, or a `v*` tag
- `release.yml` — manual from the Actions tab, or `scripts/github/release-manager.sh release`.
  The caller runs only from `master` (`if: github.ref == 'refs/heads/master'`).

## Concurrency

CI workflows group on `ci-<repo>-<ref>` with `cancel-in-progress: true` — a new push
cancels the in-flight run for that ref. Publish workflows group on `publish-<repo>` with
cancellation **off**, so pushes queue rather than abort a half-pushed manifest.

## Image tags

Published to `ghcr.io/<repo-lowercased>`. The merge job tags `latest`, `sha-<commit>`, and
when `version` is supplied, `X.Y.Z` and `X.Y`.

## Branch rulesets

Applied with `scripts/github/apply-rulesets.sh`; JSON in `.github/rulesets/`.

| Branch | Rules |
|---|---|
| `master` | PR required (0 approvals), `ci / build` must pass, no deletion, no force-push |
| `develop` | no deletion, no force-push; direct push allowed so the local merge flow keeps working |

No bypass actors on either. Copilot review is enabled account-wide rather than by ruleset —
that field is not available on this plan.

## CI runs with no local infrastructure

The runner has no Postgres, no Kafka and no MinIO. `mvn -B verify` must pass without them:
use H2 or a sliced `@SpringBootTest` for the database, `EmbeddedKafka` for messaging, and an
in-process fake for MinIO. Jacoco thresholds from each service's `pom.xml` are enforced on
every PR — dropping below a threshold fails the check.

Never skip, tag-exclude or `@Disabled` a test to get green (`RULES.md` R17). `-DskipTests`
still compiles test sources, so stale test code breaks Docker builds too.

## Release and promotion

`scripts/github/release-manager.sh promote` opens the `develop` → `master` PR, waits for
`ci / build`, and merges — parent first, then services. `release` then triggers the version
bump, which tags and publishes `X.Y.Z`, `X.Y`, `latest` and `sha-*`.

All the `scripts/github/*` tools read `GITHUB_TOKEN` from the environment. Export it per
session; never put it in `.env`. The fine-grained PAT is scoped to the nine repos and needs:

| Permission | Needed by |
|---|---|
| Administration: read/write | `apply-rulesets.sh` |
| Actions: read/write | `release-manager.sh release`, `fetch-failure-logs.sh`, `read-ci-failures.sh` |
| Pull requests: read/write | `release-manager.sh promote` (create PR) |
| Contents: read/write | `release-manager.sh promote` (merge), `release.yml` (tag) |
