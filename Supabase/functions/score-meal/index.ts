import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const CLAUDE_API_KEY = Deno.env.get("CLAUDE_API_KEY")!;
const CLAUDE_API_URL = "https://api.anthropic.com/v1/messages";

interface MealScoreRequest {
  image_base64: string;
  timestamp: string;
}

interface MealScoreResponse {
  meal_type: string;
  time: string;
  score: number;
  brief_description: string;
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
    const { image_base64, timestamp }: MealScoreRequest = await req.json();

    if (!image_base64) {
      return new Response(JSON.stringify({ error: "No image provided" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const response = await fetch(CLAUDE_API_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": CLAUDE_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-sonnet-4-20250514",
        max_tokens: 256,
        messages: [
          {
            role: "user",
            content: [
              {
                type: "image",
                source: {
                  type: "base64",
                  media_type: "image/jpeg",
                  data: image_base64,
                },
              },
              {
                type: "text",
                text: `You are a nutritionist scoring a meal photo. Respond with ONLY valid JSON, no other text.

Evaluate this meal and return:
{
  "meal_type": "breakfast" | "lunch" | "dinner" | "snack",
  "score": <1-10 number, where 10 is extremely healthy and balanced>,
  "brief_description": "<15 words max describing the meal>"
}

Scoring guide:
- 9-10: Excellent balance of whole foods, vegetables, lean protein, whole grains
- 7-8: Good nutritional value with minor areas for improvement
- 5-6: Average, some healthy elements but could be more balanced
- 3-4: Below average, high in processed foods or lacking key nutrients
- 1-2: Very unhealthy, highly processed or extreme portions`,
              },
            ],
          },
        ],
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Claude API error: ${response.status} - ${errorText}`);
    }

    const claudeResponse = await response.json();
    const content = claudeResponse.content[0].text;
    const parsed: MealScoreResponse = JSON.parse(content);
    parsed.time = timestamp;

    return new Response(JSON.stringify(parsed), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      }
    );
  }
});
