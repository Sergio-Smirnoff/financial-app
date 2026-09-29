# `finance_data` is created by THIS repo — 2026-09-21

**Status:** required change, to land in the same PR as the Phase 20 boundary work
(`PHASE20-FINANCE-BOUNDARY.md` §1, held in the homelab-infra repo).
**Origin:** homelab-infra Phase 20 "only publisher", ruling B2.

## What changes

The Phase 20 boundary spec originally had this repo declare **all five** of its
networks `external: true`, with the homelab `edge` stack creating `finance_data`
(that was decision D22). **That does not work**, and the ownership moves here.

`finance_data` is this stack's own backend data network. No container outside this
repo ever joins it. The homelab `edge` stack declared it but gave no service a leg
on it — and Compose **silently drops a declared network that nothing joins**, so it
was never created at all. Verified against the real binary (Docker 29.8.1 /
Compose 5.5.1): `docker compose config` in the edge stack emitted zero occurrences
of `finance_data`, with or without an explicit `name:` key.

Had this shipped, the finance stack would have failed on first `up` after the
boundary PR with `network finance_data not found` — which is precisely the failure
D22 was written to prevent.

## The change to `docker-compose.yml`

In the `networks:` block (currently at ~line 360), `finance_data` is **created
here**; the other four stay `external: true` because the homelab repo really does
create them (`front_finance` and `egress` by its `edge` stack, the two
`link_backup_finance_*` by its `backups` stack).

```yaml
networks:
  finance_data:
    name: finance_data          # REQUIRED — see "The name: key" below
    internal: true
    ipam:
      config:
        - subnet: 10.0.61.0/24
  front_finance:
    external: true
  egress:
    external: true
  link_backup_finance_pg:
    external: true
  link_backup_finance_minio:
    external: true
```

This replaces `PHASE20-FINANCE-BOUNDARY.md` §1's version, where `finance_data`
carried `external: true`. Everything else in that spec — the per-service
membership table in §2, the D21 alias work in §3, §4's already-done port
deletions — is unchanged.

`internal: true` is deliberate: this network has no route off the host. Services
that must reach the internet (`prometheus`, `service-notifications`,
`service-investments`) get that from their separate `egress` leg, and must address
peers by the `-int` alias per §3 — see the alias rule there, it fails **silently**
if ignored.

The subnet `10.0.61.0/24` is assigned by the homelab address plan
(`scripts/tests/test-networks.py`, `NETWORKS`). Do not pick a different one; it is
asserted on the homelab side.

## The `name:` key is not optional

Compose names a network `<project>_<key>` unless the declaration carries an
explicit `name:`. Without it this becomes **`financial-app_finance_data`**, and
anything looking up the literal `finance_data` fails.

This repo already demonstrates the behaviour: the current `internal:` network has
no `name:` key, so Docker creates it as `financial-app_internal` — which is exactly
the literal string the homelab `backups` stack has to declare to find it:

```yaml
appnet:
  name: financial-app_internal
  external: true
```

The same mistake was made across the entire homelab Phase 20 branch (every created
network lost its `name:` key) and made ten of eleven stacks refuse to start. It was
caught only by running `docker compose config` and comparing resolved names — the
test suite was fully green while the branch could not come up. Do not rely on tests
here; run the command.

## Verify before merging

```bash
docker compose config | grep -A3 'finance_data:'
```

Must print `name: finance_data`. If it prints `financial-app_finance_data`, the
`name:` key is missing.

Then, with the homelab `edge` stack up:

```bash
docker network ls --filter name=finance_data
```

Expect exactly one network, named `finance_data`, after this stack comes up —
**not** after edge does, which is the whole point of this note.

## Matching change on the homelab side

Tracked in homelab-infra, listed here so the two repos are not read in isolation:

1. `stacks/edge/docker-compose.yml` — delete the orphan `finance_data:` entry
   (it creates nothing today).
2. `scripts/tests/test-networks.py` — drop `finance_data` from `CREATORS["edge"]`
   and record that this repo owns it; the edge stack then creates **18** networks,
   not 19.
3. `PHASE20-SERVER-STEPS.md` Step 3 — the expected network count after `edge` up
   becomes **18**.
4. `PHASE20-FINANCE-BOUNDARY.md` §1 — replace with the block above.

## Ordering on cutover night

`finance_data` no longer has to exist before this stack starts, because this stack
creates it. The four `external: true` networks **do** still have to exist first, so
the homelab `edge` and `backups` stacks must be up before this one — unchanged from
the boundary spec.
