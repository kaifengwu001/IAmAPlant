import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RESCUETIME_API_BASE = "https://www.rescuetime.com/anapi";

interface ProxyRequest {
  start_date: string;
  end_date: string;
  data_type: "daily_summary" | "minute_data" | "activity_gaps";
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    const authHeader = req.headers.get("authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
    }

    const { data: settings } = await supabase
      .from("user_settings")
      .select("rescuetime_api_key")
      .eq("user_id", user.id)
      .single();

    if (!settings?.rescuetime_api_key) {
      return new Response(
        JSON.stringify({ error: "RescueTime API key not configured" }),
        { status: 400 }
      );
    }

    const apiKey = settings.rescuetime_api_key;
    const { start_date, end_date, data_type }: ProxyRequest = await req.json();

    let result;

    switch (data_type) {
      case "daily_summary":
        result = await fetchDailySummary(apiKey, start_date, end_date);
        break;
      case "minute_data":
        result = await fetchMinuteData(apiKey, start_date, end_date);
        break;
      case "activity_gaps":
        result = await fetchActivityGaps(apiKey, start_date, end_date);
        break;
      default:
        return new Response(
          JSON.stringify({ error: `Unknown data_type: ${data_type}` }),
          { status: 400 }
        );
    }

    return new Response(JSON.stringify(result), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});

async function fetchDailySummary(apiKey: string, startDate: string, endDate: string) {
  const url = `${RESCUETIME_API_BASE}/data?key=${apiKey}&format=json&perspective=interval&restrict_kind=productivity&restrict_begin=${startDate}&restrict_end=${endDate}&resolution_time=day`;
  const response = await fetch(url);
  const data = await response.json();

  let productiveMinutes = 0;
  let distractingMinutes = 0;

  for (const row of data.rows || []) {
    const seconds = row[1];
    const productivity = row[3];
    if (productivity >= 1) {
      productiveMinutes += Math.round(seconds / 60);
    } else if (productivity <= -1) {
      distractingMinutes += Math.round(seconds / 60);
    }
  }

  return { productive_minutes: productiveMinutes, distracting_minutes: distractingMinutes };
}

async function fetchMinuteData(apiKey: string, startDate: string, endDate: string) {
  const url = `${RESCUETIME_API_BASE}/data?key=${apiKey}&format=json&perspective=interval&restrict_kind=activity&restrict_begin=${startDate}&restrict_end=${endDate}&resolution_time=minute`;
  const response = await fetch(url);
  const data = await response.json();

  const rows = (data.rows || []).map((row: any[]) => [{
    timestamp: row[0],
    seconds: row[1],
    activity: row[3],
    category: row[4],
    productivity: row[5],
  }]);

  return { rows };
}

async function fetchActivityGaps(apiKey: string, startDate: string, endDate: string) {
  const url = `${RESCUETIME_API_BASE}/data?key=${apiKey}&format=json&perspective=interval&restrict_kind=activity&restrict_begin=${startDate}&restrict_end=${endDate}&resolution_time=minute`;
  const response = await fetch(url);
  const data = await response.json();

  const timestamps = (data.rows || [])
    .map((row: any[]) => new Date(row[0]).getTime())
    .sort((a: number, b: number) => a - b);

  const gaps: { start: string; end: string; duration_minutes: number }[] = [];
  const minGapMs = 3 * 60 * 60 * 1000; // 3 hours

  for (let i = 1; i < timestamps.length; i++) {
    const gapMs = timestamps[i] - timestamps[i - 1];
    if (gapMs >= minGapMs) {
      gaps.push({
        start: new Date(timestamps[i - 1]).toISOString(),
        end: new Date(timestamps[i]).toISOString(),
        duration_minutes: Math.round(gapMs / 60000),
      });
    }
  }

  return { activity_gaps: gaps };
}
