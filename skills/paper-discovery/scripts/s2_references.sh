#!/bin/bash
# Semantic Scholar 参考文献扩展
# 用法: bash scripts/s2_references.sh "paper_id" [limit] [offset]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./init.sh
source "$SCRIPT_DIR/init.sh"

PAPER_ID="${1:-}"
LIMIT="${2:-20}"
OFFSET="${3:-0}"
ARXIV_THRESHOLD="${ARXIV_CITATION_THRESHOLD:-100}"

if [[ -z "$PAPER_ID" ]]; then
    echo '{"error": "Usage: bash scripts/s2_references.sh \"paper_id\" [limit] [offset]"}' >&2
    exit 1
fi

if ! [[ "$LIMIT" =~ ^[1-9][0-9]*$ ]] || ! [[ "$OFFSET" =~ ^[0-9]+$ ]]; then
    echo '{"error": "limit must be a positive integer and offset must be a non-negative integer"}' >&2
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

ENCODED_ID="$(printf '%s' "$PAPER_ID" | jq -sRr @uri)"
FIELDS="paperId,title,year,authors,venue,journal,citationCount,externalIds,url,abstract"

rate_limit_wait

RESPONSE=$(curl -s -w "\n%{http_code}" \
    "https://api.semanticscholar.org/graph/v1/paper/${ENCODED_ID}/references?fields=${FIELDS}&limit=${LIMIT}&offset=${OFFSET}" \
    ${S2_API_KEY:+-H "x-api-key: $S2_API_KEY"} \
    --max-time 30 2>/dev/null)

date +%s > "${S2_RATE_LIMIT_FILE}"

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

case "$HTTP_CODE" in
    200)
        echo "$BODY" | jq --arg threshold "$ARXIV_THRESHOLD" '
            [.data[]?.citedPaper
             | select(.paperId != null)
             | (.venue // .journal.name // .journal // "") as $venue
             | ((.externalIds.ArXiv != null) or ($venue | test("(?i)arxiv"))) as $is_arxiv
             | (if $is_arxiv and .citationCount < ($threshold | tonumber) then
                    "caution"
                elif $is_arxiv and .citationCount >= ($threshold | tonumber) then
                    "recommended"
                else
                    "normal"
                end) as $arxiv_status
             | {
                    paperId: .paperId,
                    title: .title,
                    year: .year,
                    venue: ($venue // "N/A"),
                    citations: .citationCount,
                    doi: .externalIds.DOI,
                    arxiv_id: .externalIds.ArXiv,
                    url: .url,
                    abstract: (.abstract // ""),
                    is_arxiv: $is_arxiv,
                    arxiv_status: $arxiv_status,
                    authors: [.authors[]? | {
                        name: .name,
                        id: .authorId
                    }][:5]
               }]
            | sort_by((.citations // 0), (.year // 0))
            | reverse
            | .[]'
        ;;
    404)
        echo '{"error": "Paper not found. Try searching the title/DOI first to get a valid Semantic Scholar paperId."}' >&2
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
