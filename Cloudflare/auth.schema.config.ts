// This is the schema-only counterpart to src/auth.ts.  The CLI runs in Node,
// where a Worker D1 binding does not exist; `--adapter kysely --dialect sqlite`
// below supplies the same generated schema dialect used by the Worker.
import { betterAuth } from "better-auth";
import { bearer } from "better-auth/plugins";
import { oneTimeToken } from "better-auth/plugins/one-time-token";

// The CLI introspects `sqlite_master` before it emits a full create script.
// It runs in Node, where a Worker D1 binding does not exist, so this tiny
// schema-only D1 facade reports an empty database. It is never imported by the
// Worker; the runtime factory receives `env.DB` directly.
const emptyResult = { meta: {}, results: [] };
const schemaOnlyD1 = {
  batch() {
    return Promise.resolve([]);
  },
  exec() {
    return Promise.resolve({ count: 0, duration: 0 });
  },
  prepare() {
    const statement = {
      all() {
        return Promise.resolve(emptyResult);
      },
      bind() {
        return statement;
      },
      first() {
        return Promise.resolve(null);
      },
      raw() {
        return Promise.resolve([]);
      },
      run() {
        return Promise.resolve(emptyResult);
      }
    };
    return statement;
  }
} as D1Database;

export const auth = betterAuth({
  basePath: "/api/auth",
  baseURL: "https://schema.invalid",
  database: schemaOnlyD1,
  plugins: [
    bearer(),
    oneTimeToken({
      disableClientRequest: true,
      expiresIn: 2,
      storeToken: "hashed"
    })
  ],
  user: {
    deleteUser: { enabled: true }
  },
  account: {
    encryptOAuthTokens: true,
    accountLinking: {
      allowUnlinkingAll: false,
      disableImplicitLinking: true,
      enabled: false,
      trustedProviders: []
    }
  }
});
