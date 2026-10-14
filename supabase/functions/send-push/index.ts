//
//  send-push — Supabase Edge Function
//
//  Delivers iOS push notifications through Apple's APNs, straight from
//  Supabase (no third-party push service).
//
//  Two ways in:
//
//  1. Database Webhook (automatic). Every row inserted into
//     public.notifications — connect requests, accepted requests, gig
//     applications, announcements — is pushed to that user's devices.
//     Body is Supabase's webhook payload: { type: "INSERT", record }.
//
//  2. Direct call (broadcasts / targeted sends):
//       POST /functions/v1/send-push
//       x-push-secret: <PUSH_ADMIN_SECRET>
//       { "title": "...", "body": "...",
//         "all": true                        // every registered device
//         // or "user_ids": ["uuid", ...]    // specific users
//         "data": { ... }                    // optional extra payload
//       }
//
//  Tokens Apple reports as dead (410 / BadDeviceToken / Unregistered)
//  are deleted from public.device_tokens.
//
//  ─── Setup (once) ────────────────────────────────────────────────
//  1. Apple Developer → Certificates, IDs & Profiles → Keys → "+" →
//     enable "Apple Push Notifications service (APNs)" → download the
//     .p8 file (only downloadable once). Note its Key ID.
//  2. Function secrets (Dashboard → Edge Functions → Secrets, or
//     `supabase secrets set ...`):
//       APNS_KEY_ID        the key's ID (10 chars)
//       APNS_TEAM_ID       96FSXUUZ2T
//       APNS_PRIVATE_KEY   full contents of the .p8 file, including the
//                          -----BEGIN/END PRIVATE KEY----- lines
//       APNS_BUNDLE_ID     in.co.mattr.SuperDex
//       PUSH_ADMIN_SECRET  any long random string you choose
//  3. Deploy:  supabase functions deploy send-push --no-verify-jwt
//     (--no-verify-jwt: callers authenticate with x-push-secret.)
//  4. Dashboard → Database → Webhooks → Create:
//       table public.notifications, event INSERT,
//       type "Supabase Edge Functions" → send-push,
//       HTTP header  x-push-secret: <PUSH_ADMIN_SECRET>
//  ──────────────────────────────────────────────────────────────────
//

import { createClient } from "jsr:@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "npm:jose@5";

type Token = { token: string; user_id: string; environment: string };

type PushMessage = {
  title: string;
  body?: string | null;
  data?: Record<string, unknown>;
};

const APNS_HOSTS: Record<string, string> = {
  production: "https://api.push.apple.com",
  sandbox: "https://api.sandbox.push.apple.com",
};

// ─── APNs auth token ───────────────────────────────────────────────
// Apple wants the provider JWT refreshed at most every 20 minutes and
// rejects ones older than an hour, so reuse it for ~45 minutes.
let cachedJWT: { value: string; issuedAt: number } | null = null;

async function apnsJWT(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJWT && now - cachedJWT.issuedAt < 45 * 60) return cachedJWT.value;

  const keyId = Deno.env.get("APNS_KEY_ID");
  const teamId = Deno.env.get("APNS_TEAM_ID");
  const pem = Deno.env.get("APNS_PRIVATE_KEY");
  if (!keyId || !teamId || !pem) throw new Error("APNs secrets are not set");

  const key = await importPKCS8(pem.replace(/\\n/g, "\n"), "ES256");
  const value = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId })
    .setIssuer(teamId)
    .setIssuedAt(now)
    .sign(key);
  cachedJWT = { value, issuedAt: now };
  return value;
}

// ─── Sending ───────────────────────────────────────────────────────

/** Returns true if the token is dead and should be deleted. */
async function sendOne(
  token: Token,
  message: PushMessage,
  badge: number | undefined,
  jwt: string,
  bundleId: string,
): Promise<boolean> {
  const host = APNS_HOSTS[token.environment] ?? APNS_HOSTS.production;
  const payload = {
    aps: {
      alert: { title: message.title, ...(message.body ? { body: message.body } : {}) },
      sound: "default",
      ...(badge !== undefined ? { badge } : {}),
    },
    ...(message.data ?? {}),
  };

  const response = await fetch(`${host}/3/device/${token.token}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": bundleId,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (response.ok) return false;
  const reason = await response.json().then((b) => b?.reason as string | undefined).catch(() => undefined);
  console.warn(`APNs ${response.status} ${reason ?? ""} for ${token.token.slice(0, 8)}…`);
  return response.status === 410 || reason === "BadDeviceToken" || reason === "Unregistered" ||
    reason === "DeviceTokenNotForTopic";
}

async function deliver(
  supabase: ReturnType<typeof createClient>,
  tokens: Token[],
  message: PushMessage,
  withBadges: boolean,
) {
  if (tokens.length === 0) return { sent: 0, removed: 0 };
  const jwt = await apnsJWT();
  const bundleId = Deno.env.get("APNS_BUNDLE_ID") ?? "in.co.mattr.SuperDex";

  // App-icon badge = that user's unread in-app notifications.
  const badges = new Map<string, number>();
  if (withBadges) {
    for (const userId of new Set(tokens.map((t) => t.user_id))) {
      const { count } = await supabase
        .from("notifications")
        .select("id", { count: "exact", head: true })
        .eq("user_id", userId)
        .is("read_at", null);
      badges.set(userId, count ?? 0);
    }
  }

  const dead: string[] = [];
  let sent = 0;
  // Modest concurrency so a broadcast doesn't open thousands of streams at once.
  for (let i = 0; i < tokens.length; i += 50) {
    const batch = tokens.slice(i, i + 50);
    await Promise.all(batch.map((t) =>
      sendOne(t, message, badges.get(t.user_id), jwt, bundleId)
        .then((isDead) => {
          if (isDead) dead.push(t.token);
          else sent++;
        })
        .catch((error) => console.error("push failed", error))
    ));
  }

  if (dead.length > 0) {
    await supabase.from("device_tokens").delete().in("token", dead);
  }
  return { sent, removed: dead.length };
}

// ─── Entry point ───────────────────────────────────────────────────

Deno.serve(async (request) => {
  const secret = Deno.env.get("PUSH_ADMIN_SECRET");
  if (!secret || request.headers.get("x-push-secret") !== secret) {
    return new Response("unauthorized", { status: 401 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  let body: Record<string, any>;
  try {
    body = await request.json();
  } catch {
    return new Response("invalid JSON", { status: 400 });
  }

  try {
    // 1. Database webhook: one notifications row → that user's devices.
    if (body.type === "INSERT" && body.record) {
      const record = body.record;
      const { data: tokens } = await supabase
        .from("device_tokens")
        .select("token, user_id, environment")
        .eq("user_id", record.user_id);
      const result = await deliver(supabase, (tokens ?? []) as Token[], {
        title: record.title,
        body: record.body,
        data: { notification_id: record.id, type: record.type },
      }, true);
      return Response.json(result);
    }

    // 2. Direct call: broadcast or specific users.
    if (!body.title) return new Response("title is required", { status: 400 });
    let query = supabase.from("device_tokens").select("token, user_id, environment");
    if (Array.isArray(body.user_ids) && body.user_ids.length > 0) {
      query = query.in("user_id", body.user_ids);
    } else if (body.all !== true) {
      return new Response('pass "all": true or "user_ids"', { status: 400 });
    }
    const { data: tokens, error } = await query;
    if (error) throw error;
    const result = await deliver(supabase, (tokens ?? []) as Token[], {
      title: body.title,
      body: body.body,
      data: body.data,
    }, false);
    return Response.json(result);
  } catch (error) {
    console.error(error);
    return new Response(String(error), { status: 500 });
  }
});
