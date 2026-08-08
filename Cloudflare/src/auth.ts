import { betterAuth } from "better-auth";
import { bearer } from "better-auth/plugins";
import { oneTimeToken } from "better-auth/plugins/one-time-token";

export type AuthEnv = Env & {
  APPLE_CLIENT_ID: string;
  APPLE_CLIENT_SECRET: string;
  BETTER_AUTH_SECRET: string;
  GOOGLE_CLIENT_ID: string;
  GOOGLE_CLIENT_SECRET: string;
};

export function createAuth(env: AuthEnv, origin: string) {
  return betterAuth({
    account: {
      encryptOAuthTokens: true,
      accountLinking: {
        allowUnlinkingAll: false,
        disableImplicitLinking: true,
        enabled: false,
        trustedProviders: []
      }
    },
    basePath: "/api/auth",
    baseURL: origin,
    database: env.DB,
    emailAndPassword: { enabled: false },
    plugins: [
      bearer(),
      oneTimeToken({
        disableClientRequest: true,
        expiresIn: 2,
        storeToken: "hashed"
      })
    ],
    secret: env.BETTER_AUTH_SECRET,
    session: { freshAge: 300 },
    socialProviders: {
      apple: {
        clientId: env.APPLE_CLIENT_ID,
        clientSecret: env.APPLE_CLIENT_SECRET
      },
      google: {
        accessType: "offline",
        clientId: env.GOOGLE_CLIENT_ID,
        clientSecret: env.GOOGLE_CLIENT_SECRET,
        prompt: "select_account consent"
      }
    },
    trustedOrigins: [origin],
    user: { deleteUser: { enabled: true } }
  });
}

export type AuthInstance = ReturnType<typeof createAuth>;
