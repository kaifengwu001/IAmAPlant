import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const CLAUDE_API_KEY = Deno.env.get("CLAUDE_API_KEY")!;
const CLAUDE_API_URL = "https://api.anthropic.com/v1/messages";

interface MealScoreRequest {
  image_base64: string;
  timestamp: string;
}

interface MealScoreResponse {
  score: number;
  brief_description: string;
  time: string;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers":
          "authorization, x-client-info, apikey, content-type",
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
                text: `Score this meal photo for nutritional quality. Respond with ONLY valid JSON, no other text.

If food is clearly visible, respond with:
{
  "score": <number from 1 to 10>,
  "brief_description": "<20 words max: what the meal is>"
}

If no food is visible in the image, respond with:
{
  "score": null,
  "brief_description": "No food detected"
}

Use these reference meals to calibrate your score:

10: Grilled salmon with quinoa, roasted vegetables, and a side salad
10: Tofu stir-fry with brown rice and steamed greens
10: Grilled chicken breast with sweet potato and broccoli
9.5: Lentil soup with whole grain bread and a side of vegetables
9.5: Oatmeal with fresh berries, nuts, and seeds
9.5: Home-cooked pasta with tomato sauce, vegetables, and lean meat
9: Rice bowl with eggs and sauteed vegetables
9: Sandwich on whole grain bread with lean protein and greens
7.5: Simple home-cooked meal, protein with rice or noodles, no vegetables
7: Takeout fried rice or basic fast-casual meal
5: Pizza, burger with fries, or similar
4: Large portion of fried food or heavily processed meal
3: Pure fast food combo meal
2: Bag of chips, candy, or soda as a meal

Key principle: if a meal has protein + vegetables + reasonable carbs, it should score 8 or above. Home-cooked meals with good ingredients should be rewarded generously.`,
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
    const parsed = JSON.parse(content);

    if (parsed.score === null || parsed.score === undefined) {
      return new Response(
        JSON.stringify({ error: parsed.brief_description || "No food detected in image" }),
        { status: 422, headers: { "Content-Type": "application/json" } }
      );
    }

    const result: MealScoreResponse = {
      score: parsed.score,
      brief_description: parsed.brief_description,
      time: String(timestamp),
    };

    return new Response(JSON.stringify(result), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
