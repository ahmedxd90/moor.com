import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { RtcRole, RtcTokenBuilder } from "npm:agora-token@2.0.5";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const TOKEN_TTL_SECONDS = 60 * 60;
const APP_ID = Deno.env.get("AGORA_APP_ID") ?? "";
const APP_CERTIFICATE = Deno.env.get("AGORA_APP_CERTIFICATE") ?? "";

function response(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function isValidChannelName(value: unknown): value is string {
  return (
    typeof value === "string" &&
    value.length > 0 &&
    value.length <= 64 &&
    /^[a-zA-Z0-9 !#$%&()+,\-.:;<=>?@[\]^_{|}~]+$/.test(value)
  );
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return response({ error: "method_not_allowed" }, 405);
  }
  if (!request.headers.get("Authorization")?.startsWith("Bearer ")) {
    return response({ error: "missing_authorization" }, 401);
  }
  if (!APP_ID || !APP_CERTIFICATE) {
    return response({ error: "agora_server_not_configured" }, 500);
  }

  try {
    const payload = await request.json();
    const channelName = payload?.channelName;
    if (!isValidChannelName(channelName)) {
      return response({ error: "invalid_channel_name" }, 400);
    }

    // The SDK joins with uid 0, which asks Agora to assign a unique numeric UID.
    // The caller is still authenticated by Supabase JWT at the function gateway.
    const token = RtcTokenBuilder.buildTokenWithUid(
      APP_ID,
      APP_CERTIFICATE,
      channelName,
      0,
      RtcRole.PUBLISHER,
      TOKEN_TTL_SECONDS,
      TOKEN_TTL_SECONDS,
    );

    return response({
      token,
      appId: APP_ID,
      channelName,
      uid: 0,
      expiresIn: TOKEN_TTL_SECONDS,
    });
  } catch (_) {
    return response({ error: "invalid_request" }, 400);
  }
});
