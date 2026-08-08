import { applyD1Migrations, env, reset } from "cloudflare:test";
import type { D1Migration } from "@cloudflare/vitest-pool-workers";
import { beforeEach } from "vitest";

const testEnv = env as typeof env & { TEST_MIGRATIONS: D1Migration[] };

beforeEach(async () => {
  await reset();
  await applyD1Migrations(testEnv.DB, testEnv.TEST_MIGRATIONS);
});
