// Repro through the Workers binding: delete(name) resolves true, yet an immediate
// create(name) throws ALREADY_EXISTS while get(name) throws NOT_FOUND.
// GET /?trials=5 runs the trials and returns JSON.
const attempt = async (f) => { try { await f(); return "ok"; } catch (e) { return `${e.code}: ${e.message}`; } };

export default {
  async fetch(req, env) {
    const A = env.ARTIFACTS;
    const trials = Math.min(+(new URL(req.url).searchParams.get("trials") ?? 5), 20);
    const results = [];
    for (let i = 1; i <= trials; i++) {
      const name = `binding-${Date.now()}-${i}`;
      await A.create(name);
      const deleted = await A.delete(name);
      const t0 = Date.now();
      const immediateCreate = await attempt(() => A.create(name));
      const get = await attempt(async () => { using r = await A.get(name); await r.info(); });
      let attempts = 1, created = immediateCreate === "ok";
      while (!created && attempts < 100) {
        await new Promise((r) => setTimeout(r, 200));
        attempts++;
        created = (await attempt(() => A.create(name))) === "ok";
      }
      results.push({ deleted, immediateCreate, get, createSucceededAfterMs: Date.now() - t0, attempts });
      await A.delete(name);
    }
    return Response.json(results);
  },
};
