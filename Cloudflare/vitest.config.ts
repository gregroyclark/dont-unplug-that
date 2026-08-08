import { cloudflareTest, readD1Migrations } from "@cloudflare/vitest-pool-workers";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [
    cloudflareTest(async () => ({
      miniflare: {
        bindings: {
          APPLE_CLIENT_ID: "test.apple.client",
          APPLE_CLIENT_SECRET: "test-apple-client-secret",
          BETTER_AUTH_SECRET: "test-better-auth-secret-at-least-32-bytes",
          GOOGLE_CLIENT_ID: "test.google.client",
          GOOGLE_CLIENT_SECRET: "test-google-client-secret",
          TEST_MIGRATIONS: await readD1Migrations("./migrations")
        }
      },
      wrangler: { configPath: "./wrangler.jsonc" }
    }))
  ],
  test: { setupFiles: ["./test/setup.ts"] }
});
