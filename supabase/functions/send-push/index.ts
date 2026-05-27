// Supabase Edge Function: send-push
//
// Sends FCM push notifications via the HTTP v1 API.
// Triggered by database triggers (see supabase/migrations) or invoked
// directly from the client / server.
//
// Required secrets (set with `supabase secrets set ...`):
//   FCM_PROJECT_ID           — your Firebase project ID
//   FCM_SERVICE_ACCOUNT_JSON — full JSON of a Firebase service account key
//
// Request body shape:
//   {
//     "tokens":  ["fcm_token_1", "fcm_token_2", ...]  // OR
//     "user_ids": ["uuid_1", "uuid_2", ...],          // tokens fetched from device_tokens
//     "title":   "string",
//     "body":    "string",
//     "data":    { ... }                              // optional payload
//   }

import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface SendPushBody {
  tokens?: string[];
  user_ids?: string[];
  title: string;
  body: string;
  data?: Record<string, unknown>;
}

const FCM_PROJECT_ID = Deno.env.get("FCM_PROJECT_ID");
const FCM_SERVICE_ACCOUNT_JSON = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

if (!FCM_PROJECT_ID || !FCM_SERVICE_ACCOUNT_JSON) {
  console.error(
    "Missing FCM_PROJECT_ID or FCM_SERVICE_ACCOUNT_JSON env vars.",
  );
}

let cachedAccessToken: { token: string; expiresAt: number } | null = null;

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const cleaned = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const binary = Uint8Array.from(atob(cleaned), (c) => c.charCodeAt(0));
  return await crypto.subtle.importKey(
    "pkcs8",
    binary,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

async function getAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedAccessToken && cachedAccessToken.expiresAt - 60 > now) {
    return cachedAccessToken.token;
  }

  if (!FCM_PROJECT_ID || !FCM_SERVICE_ACCOUNT_JSON) {
    throw new Error(
      "FCM_PROJECT_ID and FCM_SERVICE_ACCOUNT_JSON must be set via `supabase secrets set`.",
    );
  }

  let serviceAccount: { client_email: string; private_key: string };
  try {
    serviceAccount = JSON.parse(FCM_SERVICE_ACCOUNT_JSON);
  } catch (e) {
    throw new Error(
      `FCM_SERVICE_ACCOUNT_JSON is not valid JSON (length=${FCM_SERVICE_ACCOUNT_JSON.length}): ${(e as Error).message}`,
    );
  }
  const key = await importPrivateKey(serviceAccount.private_key);

  const jwt = await create(
    { alg: "RS256", typ: "JWT" },
    {
      iss: serviceAccount.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: getNumericDate(0),
      exp: getNumericDate(3600),
    },
    key,
  );

  const resp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!resp.ok) {
    throw new Error(`Failed to fetch FCM access token: ${await resp.text()}`);
  }

  const json = await resp.json();
  cachedAccessToken = {
    token: json.access_token,
    expiresAt: now + (json.expires_in ?? 3600),
  };
  return cachedAccessToken.token;
}

async function fetchTokensForUsers(userIds: string[]): Promise<string[]> {
  if (userIds.length === 0) return [];
  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const { data, error } = await supabase
    .from("device_tokens")
    .select("fcm_token")
    .in("user_id", userIds);
  if (error) {
    console.error("Failed to fetch device tokens:", error.message);
    return [];
  }
  return (data ?? []).map((r) => r.fcm_token as string);
}

function stringifyData(
  data?: Record<string, unknown>,
): Record<string, string> | undefined {
  if (!data) return undefined;
  const out: Record<string, string> = {};
  for (const [k, v] of Object.entries(data)) {
    if (v === null || v === undefined) continue;
    out[k] = typeof v === "string" ? v : JSON.stringify(v);
  }
  return out;
}

async function sendFcm(
  accessToken: string,
  token: string,
  title: string,
  body: string,
  data?: Record<string, unknown>,
): Promise<{ token: string; ok: boolean; error?: string }> {
  const resp = await fetch(
    `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data: stringifyData(data),
          android: { priority: "HIGH" },
          apns: {
            payload: { aps: { sound: "default", badge: 1 } },
          },
        },
      }),
    },
  );

  if (resp.ok) return { token, ok: true };
  const errText = await resp.text();
  console.error(`FCM send failed for token ${token.slice(0, 12)}…: ${errText}`);
  return { token, ok: false, error: errText };
}

async function removeDeadTokens(deadTokens: string[]) {
  if (deadTokens.length === 0) return;
  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  await supabase.from("device_tokens").delete().in("fcm_token", deadTokens);
}

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const payload = (await req.json()) as SendPushBody;
    if (!payload.title || !payload.body) {
      return new Response(
        JSON.stringify({ error: "title and body are required" }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    let tokens: string[] = payload.tokens ?? [];
    if (payload.user_ids && payload.user_ids.length > 0) {
      const more = await fetchTokensForUsers(payload.user_ids);
      tokens = [...new Set([...tokens, ...more])];
    }

    if (tokens.length === 0) {
      return new Response(
        JSON.stringify({ sent: 0, skipped: "no tokens" }),
        { headers: { "Content-Type": "application/json" } },
      );
    }

    const accessToken = await getAccessToken();
    const results = await Promise.all(
      tokens.map((t) =>
        sendFcm(accessToken, t, payload.title, payload.body, payload.data)
      ),
    );

    const dead = results
      .filter((r) =>
        !r.ok && (r.error?.includes("UNREGISTERED") ||
          r.error?.includes("INVALID_ARGUMENT"))
      )
      .map((r) => r.token);
    await removeDeadTokens(dead);

    return new Response(
      JSON.stringify({
        sent: results.filter((r) => r.ok).length,
        failed: results.filter((r) => !r.ok).length,
        purged: dead.length,
      }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("send-push error:", err);
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
