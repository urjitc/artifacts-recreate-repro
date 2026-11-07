# Artifacts: a deleted repo's name stays taken for ~2 s

Minimal repro for [Cloudflare Artifacts](https://developers.cloudflare.com/artifacts/). After a delete succeeds, creating a repo with the same name fails with `ALREADY_EXISTS` (10201) for about 1–2.5 seconds. During that window `get` returns `NOT_FOUND` (10200), so there's no way to tell the delete is still in progress.

Both versions use a throwaway namespace, `artifacts-repro` (set `ARTIFACTS_NAMESPACE` to change it), and delete what they create.

## REST

Needs `curl`, `jq`, `python3`.

```sh
export CLOUDFLARE_ACCOUNT_ID=...
export CLOUDFLARE_API_TOKEN=...   # Artifacts edit access; `wrangler auth token` works
./recreate-after-delete.sh 5
```

```
trial 1: DELETE=202  immediate POST=409 [{"code":10201,"message":"repo already exists: recreate-1794019414-1"}]  GET=404  create succeeded after 1162 ms (2 attempts)
trial 2: DELETE=202  immediate POST=409 [{"code":10201,"message":"repo already exists: recreate-1794019417-2"}]  GET=404  create succeeded after 2472 ms (5 attempts)
trial 3: DELETE=202  immediate POST=409 [{"code":10201,"message":"repo already exists: recreate-1794019422-3"}]  GET=404  create succeeded after 1957 ms (4 attempts)
trial 4: DELETE=202  immediate POST=409 [{"code":10201,"message":"repo already exists: recreate-1794019426-4"}]  GET=404  create succeeded after 1407 ms (3 attempts)
trial 5: DELETE=202  immediate POST=409 [{"code":10201,"message":"repo already exists: recreate-1794019429-5"}]  GET=404  create succeeded after 1665 ms (4 attempts)
```

## Workers binding

`delete()` resolves `true`, then `create()` throws.

```sh
cd worker && npx wrangler deploy
curl "https://artifacts-recreate-repro.<your-subdomain>.workers.dev/?trials=5"
```

```json
{"deleted":true,"immediateCreate":"ALREADY_EXISTS: repo already exists: binding-1794019455902-1","get":"NOT_FOUND: Repository not found: binding-1794019455902-1.","createSucceededAfterMs":1434,"attempts":6}
{"deleted":true,"immediateCreate":"ALREADY_EXISTS: repo already exists: binding-1794019458789-2","get":"NOT_FOUND: Repository not found: binding-1794019458789-2.","createSucceededAfterMs":1569,"attempts":6}
{"deleted":true,"immediateCreate":"ALREADY_EXISTS: repo already exists: binding-1794019461668-3","get":"NOT_FOUND: Repository not found: binding-1794019461668-3.","createSucceededAfterMs":1592,"attempts":7}
{"deleted":true,"immediateCreate":"ALREADY_EXISTS: repo already exists: binding-1794019465264-4","get":"NOT_FOUND: Repository not found: binding-1794019465264-4.","createSucceededAfterMs":1581,"attempts":7}
{"deleted":true,"immediateCreate":"ALREADY_EXISTS: repo already exists: binding-1794019468353-5","get":"NOT_FOUND: Repository not found: binding-1794019468353-5.","createSucceededAfterMs":1602,"attempts":7}
```

Observed 2026-11-07 (UTC), wrangler 4.158.0, compatibility date 2026-11-01.
