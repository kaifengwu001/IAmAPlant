import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

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
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const dateStr = yesterday.toISOString().split("T")[0];

    const { data: partialSummaries } = await supabase
      .from("daily_summary")
      .select("*")
      .eq("date", dateStr)
      .eq("status", "partial");

    if (!partialSummaries || partialSummaries.length === 0) {
      return new Response(
        JSON.stringify({ message: "No partial summaries to aggregate", date: dateStr }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    let aggregated = 0;

    for (const summary of partialSummaries) {
      await supabase
        .from("daily_summary")
        .update({ status: "complete" })
        .eq("id", summary.id);
      aggregated++;
    }

    return new Response(
      JSON.stringify({
        message: `Aggregated ${aggregated} summaries`,
        date: dateStr,
      }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
