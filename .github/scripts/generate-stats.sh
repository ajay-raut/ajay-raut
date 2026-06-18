#!/bin/bash
# Generates github-stats.svg and github-langs.svg using GitHub API directly
# No Vercel dependency — runs entirely in GitHub Actions

set -euo pipefail

USERNAME="ajay-raut"
GH_TOKEN="${GH_TOKEN:secrets.STATS_PAT}"

# ── Colors (matching existing theme) ──
BG="#0d1117"
TITLE="#f77333"
ICON="#f77333"
TEXT="#c9d1d9"
BORDER="#f7733340"
GRAY="#8b949e"
RADIUS="10"

# ═══════════════════════════════════════════════════════════
# 1. FETCH DATA FROM GITHUB API
# ═══════════════════════════════════════════════════════════

echo "📡 Fetching user data..."
USER_DATA=$(curl -sf -H "Authorization: token $GH_TOKEN" "https://api.github.com/users/$USERNAME")
PUBLIC_REPOS=$(echo "$USER_DATA" | jq -r '.public_repos // 0')
FOLLOWERS=$(echo "$USER_DATA" | jq -r '.followers // 0')

echo "📡 Fetching contribution data via GraphQL..."
GRAPHQL_QUERY=$(cat <<'GQL'
{
  user(login: "AjayRaut") {
    contributionsCollection {
      totalCommitContributions
      restrictedContributionsCount
      totalPullRequestContributions
      totalIssueContributions
      contributionCalendar { totalContributions }
    }
    repositories(first: 100, ownerAffiliations: OWNER, orderBy: {field: STARGAZERS, direction: DESC}) {
      totalCount
      nodes { stargazerCount forkCount primaryLanguage { name color } languages(first: 10, orderBy: {field: SIZE, direction: DESC}) { edges { size node { name color } } } }
    }
  }
}
GQL
)

GRAPHQL_DATA=$(curl -sf -H "Authorization: bearer $GH_TOKEN" \
  -d "$(jq -n --arg q "$GRAPHQL_QUERY" '{query: $q}')" \
  https://api.github.com/graphql)

COMMITS=$(echo "$GRAPHQL_DATA" | jq '[.data.user.contributionsCollection.totalCommitContributions, .data.user.contributionsCollection.restrictedContributionsCount] | add // 0')
PRS=$(echo "$GRAPHQL_DATA" | jq '.data.user.contributionsCollection.totalPullRequestContributions // 0')
ISSUES=$(echo "$GRAPHQL_DATA" | jq '.data.user.contributionsCollection.totalIssueContributions // 0')
TOTAL=$(echo "$GRAPHQL_DATA" | jq '.data.user.contributionsCollection.contributionCalendar.totalContributions // 0')
STARS=$(echo "$GRAPHQL_DATA" | jq '[.data.user.repositories.nodes[].stargazerCount] | add // 0')
TOTAL_REPOS=$(echo "$GRAPHQL_DATA" | jq '.data.user.repositories.totalCount // 0')

echo "  Stars=$STARS Commits=$COMMITS PRs=$PRS Issues=$ISSUES Repos=$TOTAL_REPOS"

# ═══════════════════════════════════════════════════════════
# 2. GENERATE STATS SVG
# ═══════════════════════════════════════════════════════════

cat > github-stats.svg << STATSEOF
<svg width="495" height="220" viewBox="0 0 495 220" fill="none" xmlns="http://www.w3.org/2000/svg">
  <style>
    .title { font: 600 18px 'Segoe UI', Ubuntu, sans-serif; fill: ${TITLE}; }
    .stat-label { font: 400 14px 'Segoe UI', Ubuntu, sans-serif; fill: ${TEXT}; }
    .stat-value { font: 700 14px 'Segoe UI', Ubuntu, sans-serif; fill: ${TEXT}; }
    .icon { fill: ${ICON}; }
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    .row { opacity: 0; animation: fadeIn 0.3s ease-in-out forwards; }
    .row:nth-child(1) { animation-delay: 0.1s; }
    .row:nth-child(2) { animation-delay: 0.2s; }
    .row:nth-child(3) { animation-delay: 0.3s; }
    .row:nth-child(4) { animation-delay: 0.4s; }
    .row:nth-child(5) { animation-delay: 0.5s; }
  </style>
  <rect x="0.5" y="0.5" rx="${RADIUS}" width="494" height="219" fill="${BG}" stroke="${BORDER}" stroke-opacity="1"/>
  <text x="25" y="35" class="title">${USERNAME}'s GitHub Stats</text>
  <g transform="translate(30, 55)">
    <g class="row" transform="translate(0, 0)">
      <svg class="icon" width="16" height="16" viewBox="0 0 16 16"><path d="M8 .25a.75.75 0 01.673.418l1.882 3.815 4.21.612a.75.75 0 01.416 1.279l-3.046 2.97.719 4.192a.75.75 0 01-1.088.791L8 12.347l-3.766 1.98a.75.75 0 01-1.088-.79l.72-4.194L.818 6.374a.75.75 0 01.416-1.28l4.21-.611L7.327.668A.75.75 0 018 .25z"/></svg>
      <text x="25" y="13" class="stat-label">Total Stars Earned:</text>
      <text x="220" y="13" class="stat-value">${STARS}</text>
    </g>
    <g class="row" transform="translate(0, 30)">
      <svg class="icon" width="16" height="16" viewBox="0 0 16 16"><path d="M1.643 3.143L.427 1.927A.25.25 0 000 2.104V5.75c0 .138.112.25.25.25h3.646a.25.25 0 00.177-.427L2.715 4.215a6.5 6.5 0 11-1.18 4.458.75.75 0 10-1.493.154 8.001 8.001 0 101.6-5.684zM7.75 4a.75.75 0 01.75.75v2.992l2.028.812a.75.75 0 01-.557 1.392l-2.5-1A.75.75 0 017 8.25v-3.5A.75.75 0 017.75 4z"/></svg>
      <text x="25" y="13" class="stat-label">Total Commits (${YEAR:-2025}):</text>
      <text x="220" y="13" class="stat-value">${COMMITS}</text>
    </g>
    <g class="row" transform="translate(0, 60)">
      <svg class="icon" width="16" height="16" viewBox="0 0 16 16"><path d="M7.177 3.073L9.573.677A.25.25 0 0110 .854v4.792a.25.25 0 01-.427.177L7.177 3.427a.25.25 0 010-.354zM3.75 2.5a.75.75 0 100 1.5.75.75 0 000-1.5zm-2.25.75a2.25 2.25 0 113 2.122v5.256a2.251 2.251 0 11-1.5 0V5.372A2.25 2.25 0 011.5 3.25zM11 2.5h-1V4h1a1 1 0 011 1v5.628a2.251 2.251 0 101.5 0V5A2.5 2.5 0 0011 2.5zm1 10.25a.75.75 0 111.5 0 .75.75 0 01-1.5 0zM3.75 12a.75.75 0 100 1.5.75.75 0 000-1.5z"/></svg>
      <text x="25" y="13" class="stat-label">Total PRs:</text>
      <text x="220" y="13" class="stat-value">${PRS}</text>
    </g>
    <g class="row" transform="translate(0, 90)">
      <svg class="icon" width="16" height="16" viewBox="0 0 16 16"><path d="M8 9.5a1.5 1.5 0 100-3 1.5 1.5 0 000 3z"/><path fill-rule="evenodd" d="M8 0a8 8 0 100 16A8 8 0 008 0zM1.5 8a6.5 6.5 0 1113 0 6.5 6.5 0 01-13 0z"/></svg>
      <text x="25" y="13" class="stat-label">Total Issues:</text>
      <text x="220" y="13" class="stat-value">${ISSUES}</text>
    </g>
    <g class="row" transform="translate(0, 120)">
      <svg class="icon" width="16" height="16" viewBox="0 0 16 16"><path fill-rule="evenodd" d="M2 2.5A2.5 2.5 0 014.5 0h8.75a.75.75 0 01.75.75v12.5a.75.75 0 01-.75.75h-2.5a.75.75 0 110-1.5h1.75v-2h-8a1 1 0 00-.714 1.7.75.75 0 01-1.072 1.05A2.495 2.495 0 012 11.5v-9zm10.5-1h-8a1 1 0 00-1 1v6.708A2.486 2.486 0 014.5 9h8V1.5z"/></svg>
      <text x="25" y="13" class="stat-label">Contributed to:</text>
      <text x="220" y="13" class="stat-value">${TOTAL} this year</text>
    </g>
  </g>
</svg>
STATSEOF

echo "✅ github-stats.svg generated ($(wc -c < github-stats.svg) bytes)"

# ═══════════════════════════════════════════════════════════
# 3. GENERATE LANGUAGES SVG
# ═══════════════════════════════════════════════════════════

echo "📡 Aggregating language data..."

# Extract language data and aggregate
LANG_JSON=$(echo "$GRAPHQL_DATA" | jq -r '
  [.data.user.repositories.nodes[].languages.edges[] | {name: .node.name, color: .node.color, size: .size}]
  | group_by(.name)
  | map({name: .[0].name, color: .[0].color, size: (map(.size) | add)})
  | sort_by(-.size)
  | .[0:8]
')

TOTAL_SIZE=$(echo "$LANG_JSON" | jq '[.[].size] | add // 1')
LANG_COUNT=$(echo "$LANG_JSON" | jq 'length')

# Build language rows and progress bar segments
LANG_ROWS=""
BAR_SEGMENTS=""
BAR_X=0

for i in $(seq 0 $((LANG_COUNT - 1))); do
  NAME=$(echo "$LANG_JSON" | jq -r ".[$i].name")
  COLOR=$(echo "$LANG_JSON" | jq -r ".[$i].color // \"#8b949e\"")
  SIZE=$(echo "$LANG_JSON" | jq -r ".[$i].size")
  PCT=$(echo "scale=2; $SIZE * 100 / $TOTAL_SIZE" | bc)
  BAR_W=$(echo "scale=2; $SIZE * 410 / $TOTAL_SIZE" | bc)
  
  ROW=$((i / 2))
  COL=$((i % 2))
  X=$((COL * 210))
  Y=$((ROW * 28))
  
  LANG_ROWS="$LANG_ROWS
    <g transform=\"translate($X, $Y)\" style=\"animation-delay: ${i}00ms\" class=\"row\">
      <rect x=\"0\" y=\"2\" width=\"12\" height=\"12\" rx=\"6\" fill=\"$COLOR\"/>
      <text x=\"18\" y=\"13\" class=\"lang-name\">$NAME</text>
      <text x=\"150\" y=\"13\" class=\"lang-pct\">${PCT}%</text>
    </g>"
  
  BAR_SEGMENTS="$BAR_SEGMENTS
    <rect x=\"$BAR_X\" y=\"0\" width=\"$BAR_W\" height=\"8\" rx=\"0\" fill=\"$COLOR\"/>"
  BAR_X=$(echo "$BAR_X + $BAR_W" | bc)
done

CARD_HEIGHT=$((90 + (((LANG_COUNT + 1) / 2)) * 28 + 10))

cat > github-langs.svg << LANGSEOF
<svg width="460" height="${CARD_HEIGHT}" viewBox="0 0 460 ${CARD_HEIGHT}" fill="none" xmlns="http://www.w3.org/2000/svg">
  <style>
    .title { font: 600 18px 'Segoe UI', Ubuntu, sans-serif; fill: ${TITLE}; }
    .lang-name { font: 400 12px 'Segoe UI', Ubuntu, sans-serif; fill: ${TEXT}; }
    .lang-pct { font: 600 12px 'Segoe UI', Ubuntu, sans-serif; fill: ${GRAY}; }
    @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
    .row { opacity: 0; animation: fadeIn 0.3s ease-in-out forwards; }
    @keyframes grow { from { width: 0; } }
    .bar rect { animation: grow 0.6s ease-in-out forwards; }
  </style>
  <rect x="0.5" y="0.5" rx="${RADIUS}" width="459" height="$((CARD_HEIGHT - 1))" fill="${BG}" stroke="${BORDER}" stroke-opacity="1"/>
  <text x="25" y="35" class="title">Most Used Languages</text>
  <g transform="translate(25, 50)" class="bar">
    <rect x="0" y="0" width="410" height="8" rx="4" fill="#333"/>
    <clipPath id="bar-clip"><rect x="0" y="0" width="410" height="8" rx="4"/></clipPath>
    <g clip-path="url(#bar-clip)">
      ${BAR_SEGMENTS}
    </g>
  </g>
  <g transform="translate(25, 72)">
    ${LANG_ROWS}
  </g>
</svg>
LANGSEOF

echo "✅ github-langs.svg generated ($(wc -c < github-langs.svg) bytes)"

echo "🎉 All stats generated successfully!"
