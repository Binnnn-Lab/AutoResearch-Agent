#!/bin/bash
# Semantic Scholar 推荐搜索
# 用法:
#   bash scripts/s2_recommend.sh "paper_id1,paper_id2" [negative_paper_ids] [limit]
# 示例:
#   bash scripts/s2_recommend.sh "CorpusId:123,ARXIV:2401.12345" "" 20
#   bash scripts/s2_recommend.sh "649def34f8be52c8b66281af98ae884c09aef38b" "CorpusId:11111" 15

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./init.sh
source "$SCRIPT_DIR/init.sh"

POSITIVE_IDS_RAW="${1:-}"
NEGATIVE_IDS_RAW="${2:-}"
LIMIT="${3:-20}"
ARXIV_THRESHOLD="${ARXIV_CITATION_THRESHOLD:-100}"

if [[ -z "$POSITIVE_IDS_RAW" ]]; then
    echo '{"error": "Usage: bash scripts/s2_recommend.sh \"paper_id1,paper_id2\" [negative_paper_ids] [limit]"}' >&2
    exit 1
fi

if ! [[ "$LIMIT" =~ ^[1-9][0-9]*$ ]]; then
    echo '{"error": "limit must be a positive integer"}' >&2
    exit 1
fi

rate_limit_wait() {
    local last_time current_time elapsed
    if [[ -f "${S2_RATE_LIMIT_FILE}" ]]; then
        last_time=$(cat "${S2_RATE_LIMIT_FILE}" 2>/dev/null || echo "0")
        current_time=$(date +%s)
        elapsed=$((current_time - last_time))
        if [[ $elapsed -lt ${S2_MIN_INTERVAL} ]]; then
            sleep $((S2_MIN_INTERVAL - elapsed))
        fi
    fi
}

split_ids() {
    printf '%s' "$1" | jq -R 'split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0))'
}

POSITIVE_JSON="$(split_ids "$POSITIVE_IDS_RAW")"
NEGATIVE_JSON="$(split_ids "$NEGATIVE_IDS_RAW")"
POSITIVE_COUNT="$(echo "$POSITIVE_JSON" | jq 'length')"

if [[ "$POSITIVE_COUNT" -eq 0 ]]; then
    echo '{"error": "At least one positive paper ID is required"}' >&2
    exit 1
fi

FIELDS="paperId,title,year,authors,venue,journal,citationCount,externalIds,url,openAccessPdf,abstract"

rate_limit_wait

if [[ "$POSITIVE_COUNT" -eq 1 ]] && [[ "$(echo "$NEGATIVE_JSON" | jq 'length')" -eq 0 ]]; then
    PAPER_ID="$(echo "$POSITIVE_JSON" | jq -r '.[0]')"
    ENCODED_ID="$(printf '%s' "$PAPER_ID" | jq -sRr @uri)"
    RESPONSE=$(curl -s -w "\n%{http_code}" \
        "https://api.semanticscholar.org/recommendations/v1/papers/forpaper/${ENCODED_ID}?limit=${LIMIT}&fields=${FIELDS}" \
        ${S2_API_KEY:+-H "x-api-key: $S2_API_KEY"} \
        --max-time 30 2>/dev/null)
else
    PAYLOAD="$(jq -n --argjson positive "$POSITIVE_JSON" --argjson negative "$NEGATIVE_JSON" '
        {positivePaperIds: $positive}
        + (if ($negative | length) > 0 then {negativePaperIds: $negative} else {} end)
    ')"
    RESPONSE=$(curl -s -w "\n%{http_code}" \
        -X POST "https://api.semanticscholar.org/recommendations/v1/papers?limit=${LIMIT}&fields=${FIELDS}" \
        -H "Content-Type: application/json" \
        ${S2_API_KEY:+-H "x-api-key: $S2_API_KEY"} \
        -d "$PAYLOAD" \
        --max-time 30 2>/dev/null)
fi

date +%s > "${S2_RATE_LIMIT_FILE}"

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

case "$HTTP_CODE" in
    200)
        echo "$BODY" | jq --arg threshold "$ARXIV_THRESHOLD" '
            .recommendedPapers[]? |
            (.venue // .journal.name // .journal // "") as $venue |
            ((.externalIds.ArXiv != null) or ($venue | test("(?i)arxiv"))) as $is_arxiv |
            (if $is_arxiv and .citationCount < ($threshold | tonumber) then
                "caution"
            elif $is_arxiv and .citationCount >= ($threshold | tonumber) then
                "recommended"
            else
                "normal"
            end) as $arxiv_status |
                        (.externalIds.DOI // "") as $doi |
                        (.externalIds.ArXiv // "") as $arxiv |
                        ((if $doi != "" then ("https://doi.org/" + $doi)
                            elif $arxiv != "" then ("https://arxiv.org/abs/" + $arxiv)
                            elif (.openAccessPdf.url // "") != "" then .openAccessPdf.url
                            else (.url // "") end)) as $best_url |
                        {
                                paperId: .paperId,
                                paper_id: .paperId,
                title: .title,
                year: .year,
                venue: ($venue // "N/A"),
                citations: .citationCount,
                                citation_count: (.citationCount // 0),
                                doi: ($doi | if . == "" then null else . end),
                                arxiv_id: ($arxiv | if . == "" then null else . end),
                                url: $best_url,
                                pdf_url: (.openAccessPdf.url // null),
                abstract: (.abstract // ""),
                is_arxiv: $is_arxiv,
                arxiv_status: $arxiv_status,
                                source: "semantic_scholar",
                authors: [.authors[]? | {
                    name: .name,
                    id: .authorId
                }][:5]
            }'
        ;;
    400)
        echo "{\"error\": \"HTTP 400: $(echo "$BODY" | jq -r '.message // .error // "Bad request"')\"}" >&2
        exit 1
        ;;
    404)
        echo '{"error": "Seed paper not found. Try searching the title/DOI first to get a valid Semantic Scholar paperId."}' >&2
        exit 1
        ;;
    429)
        echo '{"error": "Rate limit exceeded. Wait 1-2 seconds and retry."}' >&2
        exit 1
        ;;
    *)
        echo "{\"error\": \"HTTP $HTTP_CODE: $(echo "$BODY" | jq -r '.message // .error // "Unknown error"')\"}" >&2
        exit 1
        ;;
esac
