import { AuthEnv, AuthInstance, createAuth } from "./auth";
import { HttpError, notFound } from "./http";

export type SessionOwner = {
  id: string;
  name: string;
  email: string;
  sessionCreatedAt: Date;
  auth: AuthInstance;
};

export async function requireSession(
  request: Request,
  env: AuthEnv,
  allowAccountDeletion = false
): Promise<SessionOwner> {
  const auth = createAuth(env, new URL(request.url).origin);
  const session = await auth.api.getSession({ headers: request.headers });
  if (!session) throw new HttpError(401, "unauthenticated", "A valid bearer session is required");
  if (!allowAccountDeletion && await isAccountDeleting(env.DB, session.user.id)) {
    throw new HttpError(409, "account_deleting", "This account is being deleted");
  }
  return {
    auth,
    email: session.user.email,
    id: session.user.id,
    name: session.user.name,
    sessionCreatedAt: new Date(session.session.createdAt)
  };
}

export async function isAccountDeleting(db: D1Database, ownerID: string): Promise<boolean> {
  return (await db.prepare("SELECT 1 FROM account_deletions WHERE user_id = ?").bind(ownerID).first()) !== null;
}

export function requireRecentSession(owner: SessionOwner): void {
  if (Date.now() - owner.sessionCreatedAt.getTime() > 300_000) {
    throw new HttpError(401, "session_not_fresh", "A recent sign-in is required for account deletion");
  }
}

export async function accountProvider(env: AuthEnv, ownerID: string): Promise<{ provider: string }> {
  const account = await env.DB.prepare(
    'SELECT "providerId" AS provider FROM "account" WHERE "userId" = ? AND "providerId" IN (\'apple\', \'google\') LIMIT 1'
  )
    .bind(ownerID)
    .first<{ provider: string }>();
  if (!account) throw notFound();
  return account;
}

export async function revokeProviderGrant(request: Request, owner: SessionOwner, env: AuthEnv): Promise<void> {
  let account: Awaited<ReturnType<typeof accountProvider>>;
  try {
    account = await accountProvider(env, owner.id);
  } catch (error) {
    if (error instanceof HttpError && error.status === 404) {
      throw new HttpError(503, "provider_revocation_unavailable", "No provider grant is available to revoke");
    }
    throw error;
  }
  let token: string;
  try {
    token = (await owner.auth.api.getAccessToken({
      body: { providerId: account.provider },
      headers: request.headers
    })).accessToken;
  } catch {
    throw new HttpError(503, "provider_revocation_unavailable", "The provider did not supply a revocable grant");
  }
  let response: Response;
  if (account.provider === "google") {
    response = await fetch("https://oauth2.googleapis.com/revoke", {
      body: new URLSearchParams({ token }),
      headers: { "content-type": "application/x-www-form-urlencoded" },
      method: "POST"
    });
  } else if (account.provider === "apple") {
    if (!env.APPLE_CLIENT_ID || !env.APPLE_CLIENT_SECRET) {
      // Apple requires a current team-signed client secret for /auth/revoke.
      throw new HttpError(503, "provider_revocation_unavailable", "Apple revocation is not configured");
    }
    response = await fetch("https://appleid.apple.com/auth/revoke", {
      body: new URLSearchParams({
        client_id: env.APPLE_CLIENT_ID,
        client_secret: env.APPLE_CLIENT_SECRET,
        token,
        token_type_hint: "access_token"
      }),
      headers: { "content-type": "application/x-www-form-urlencoded" },
      method: "POST"
    });
  } else {
    throw new HttpError(503, "provider_revocation_unavailable", "The identity provider cannot be revoked safely");
  }
  if (!response.ok) {
    throw new HttpError(503, "provider_revocation_unavailable", "The provider could not revoke the grant");
  }
}

export async function deleteOwnerObjects(bucket: R2Bucket, ownerID: string): Promise<void> {
  const prefix = `owners/${ownerID}/`;
  let cursor: string | undefined;
  do {
    const page = await bucket.list({ cursor, prefix });
    if (page.objects.length) await bucket.delete(page.objects.map((object) => object.key));
    cursor = page.truncated ? page.cursor : undefined;
  } while (cursor);
}

export async function cleanupPendingAccountDeletions(env: AuthEnv, maximum = 10): Promise<void> {
  const deletions = await env.DB.prepare("SELECT user_id FROM account_deletions ORDER BY started_at_ms LIMIT ?")
    .bind(maximum)
    .all<{ user_id: string }>();
  for (const deletion of deletions.results) {
    try {
      await deleteOwnerObjects(env.GUIDE_PHOTOS, deletion.user_id);
      await env.DB.prepare("DELETE FROM guide_photo_deletions WHERE owner_id = ?").bind(deletion.user_id).run();
      await env.DB.prepare("DELETE FROM account_deletions WHERE user_id = ?").bind(deletion.user_id).run();
    } catch {
      // A later request or scheduled run retries this durable cleanup marker.
    }
  }
}
