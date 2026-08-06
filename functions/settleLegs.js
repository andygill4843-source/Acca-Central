const { onSchedule } = require("firebase-functions/v2/scheduler");
const { getFirestore } = require("firebase-admin/firestore");

const db = getFirestore();
const SPORTMONKS_TOKEN = process.env.SPORTMONKS_API_TOKEN;

const FINISHED_STATES = ["FT", "AET", "FT_PEN", "ABAN", "CANCL"];

function determineOutcome(leg, homeTeam, awayTeam, homeGoals, awayGoals) {
  const selection = leg.selectionDescription.toLowerCase();

  if (leg.betType === "Match Winner") {
    const homeWon = homeGoals > awayGoals;
    const awayWon = awayGoals > homeGoals;
    const isDraw = homeGoals === awayGoals;

    if (selection.includes(homeTeam.toLowerCase())) return homeWon ? "won" : "lost";
    if (selection.includes(awayTeam.toLowerCase())) return awayWon ? "won" : "lost";
    if (selection.includes("draw")) return isDraw ? "won" : "lost";
    return "pending";
  }

  if (leg.betType === "Over/Under Goals") {
    const totalGoals = homeGoals + awayGoals;
    const match = selection.match(/(\d+(\.\d+)?)/);
    if (!match) return "pending";
    const line = parseFloat(match[1]);
    if (selection.includes("over")) return totalGoals > line ? "won" : "lost";
    if (selection.includes("under")) return totalGoals < line ? "won" : "lost";
    return "pending";
  }

  return "pending";
}

exports.settleLegs = onSchedule("every 15 minutes", async () => {
  const pendingSnap = await db.collection("legs")
    .where("outcome", "==", "pending")
    .get();

  for (const legDoc of pendingSnap.docs) {
    const leg = legDoc.data();
    if (!leg.sportmonksFixtureId) continue;

    const url = `https://api.sportmonks.com/v3/football/fixtures/${leg.sportmonksFixtureId}?api_token=${SPORTMONKS_TOKEN}&include=participants;scores;state`;
    const response = await fetch(url);
    if (!response.ok) continue;

    const json = await response.json();
    const fixture = json.data;
    if (!fixture) continue;

    if (!FINISHED_STATES.includes(fixture.state?.short_name)) continue;

    const home = fixture.participants?.find((p) => p.meta?.location === "home");
    const away = fixture.participants?.find((p) => p.meta?.location === "away");
    if (!home || !away) continue;

    const homeScore = fixture.scores?.find((s) => s.description === "CURRENT" && s.score.participant === "home");
    const awayScore = fixture.scores?.find((s) => s.description === "CURRENT" && s.score.participant === "away");
    if (!homeScore || !awayScore) continue;

    const outcome = determineOutcome(leg, home.name, away.name, homeScore.score.goals, awayScore.score.goals);
    if (outcome === "pending") continue;

    await legDoc.ref.update({ outcome });
  }
});