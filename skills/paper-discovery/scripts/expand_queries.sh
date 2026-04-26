#!/usr/bin/env bash
# Expand search queries with survey/benchmark/comparison variants
# Usage: bash expand_queries.sh "research topic" [output_file.json]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./init.sh
source "$SCRIPT_DIR/init.sh"

TOPIC="${1:-}"
OUTPUT_FILE="${2:--}"

if [ -z "$TOPIC" ]; then
    echo "Usage: expand_queries.sh <research topic> [output_file.json|-]" >&2
    echo "Example: expand_queries.sh 'LLM security'" >&2
    exit 1
fi

if [[ -z "${PYTHON_BIN:-}" ]]; then
    echo "Error: python3/python not found in PATH" >&2
    exit 1
fi

# 创建临时 Python 脚本
TMP_PY=$(mktemp)
trap "rm -f $TMP_PY" EXIT

cat > "$TMP_PY" << 'PYEOF'
import json
import re
import sys

def extract_keywords(text, max_words=6):
    """Extract meaningful keywords from topic, removing stop words."""
    stop_words = {
        'a', 'an', 'the', 'of', 'for', 'in', 'on', 'and', 'or', 'with',
        'to', 'by', 'from', 'its', 'is', 'are', 'was', 'be', 'as', 'at',
        'via', 'using', 'based', 'study', 'analysis', 'empirical',
        'towards', 'toward', 'into', 'exploring', 'comparison', 'tasks',
        'effectiveness', 'investigation', 'comprehensive', 'novel',
        'challenge', 'challenges', 'gaps', 'gap', 'critical', 'survey', 'review',
        'propose', 'proposed', 'approach', 'method', 'methods'
    }

    # Split on non-alphanumeric
    words = re.split(r'[^a-zA-Z0-9]+', text)
    keywords = [w for w in words if w and len(w) > 1 and w.lower() not in stop_words]
    return keywords[:max_words]

def clean_query(query, max_chars=60):
    """Shorten query to max_chars by keeping core keywords."""
    if len(query) <= max_chars:
        return query

    suffixes = ['benchmark', 'survey', 'seminal', 'state of the art']
    suffix = ''
    core = query

    for s in suffixes:
        if query.lower().endswith(s):
            suffix = s
            core = query[:-len(s)].strip()
            break

    keywords = extract_keywords(core, max_words=6)
    shortened = ' '.join(keywords)
    if suffix:
        shortened = f"{shortened} {suffix}"

    return shortened[:max_chars]

def expand_queries(topic, output_file=None):
    # Extract keywords from topic
    all_keywords = extract_keywords(topic, max_words=10)

    # Build expanded queries
    queries = []
    seen = set()

    # Original topic (cleaned)
    original_clean = clean_query(topic)
    if original_clean.lower() not in seen:
        queries.append({
            'query': original_clean,
            'type': 'original',
            'keywords': all_keywords[:6]
        })
        seen.add(original_clean.lower())

    # Core keywords only
    if len(all_keywords) >= 3:
        core_kw = ' '.join(all_keywords[:4])
        if core_kw.lower() not in seen:
            queries.append({
                'query': core_kw,
                'type': 'core_keywords',
                'keywords': all_keywords[:4]
            })
            seen.add(core_kw.lower())

        # Shifted window for diversity
        if len(all_keywords) >= 5:
            shifted = ' '.join(all_keywords[1:5])
            if shifted.lower() not in seen:
                queries.append({
                    'query': shifted,
                    'type': 'shifted_window',
                    'keywords': all_keywords[1:5]
                })
                seen.add(shifted.lower())

    # Survey variant
    if all_keywords:
        survey_q = f"{' '.join(all_keywords[:4])} survey"
        survey_clean = clean_query(survey_q)
        if survey_clean.lower() not in seen:
            queries.append({
                'query': survey_clean,
                'type': 'survey',
                'keywords': all_keywords[:4] + ['survey']
            })
            seen.add(survey_clean.lower())

    # Benchmark variant
    if all_keywords:
        bench_q = f"{' '.join(all_keywords[:4])} benchmark"
        bench_clean = clean_query(bench_q)
        if bench_clean.lower() not in seen:
            queries.append({
                'query': bench_clean,
                'type': 'benchmark',
                'keywords': all_keywords[:4] + ['benchmark']
            })
            seen.add(bench_clean.lower())

    # Comparison variant
    if all_keywords:
        comp_q = f"{' '.join(all_keywords[:4])} comparison"
        comp_clean = clean_query(comp_q)
        if comp_clean.lower() not in seen:
            queries.append({
                'query': comp_clean,
                'type': 'comparison',
                'keywords': all_keywords[:4] + ['comparison']
            })
            seen.add(comp_clean.lower())

    # Recent advances
    if all_keywords:
        recent_q = f"{' '.join(all_keywords[:4])} recent advances"
        recent_clean = clean_query(recent_q)
        if recent_clean.lower() not in seen:
            queries.append({
                'query': recent_clean,
                'type': 'recent',
                'keywords': all_keywords[:4] + ['recent', 'advances']
            })
            seen.add(recent_clean.lower())

    # Deep learning / neural variant (for ML topics)
    ml_keywords = {'neural', 'deep', 'learning', 'network', 'model', 'transformer', 'llm'}
    if any(kw in ' '.join(all_keywords).lower() for kw in ml_keywords):
        dl_q = f"{' '.join(all_keywords[:3])} deep learning"
        dl_clean = clean_query(dl_q)
        if dl_clean.lower() not in seen:
            queries.append({
                'query': dl_clean,
                'type': 'method_focused',
                'keywords': all_keywords[:3] + ['deep learning']
            })
            seen.add(dl_clean.lower())

    output = {
        'original_topic': topic,
        'extracted_keywords': all_keywords,
        'query_count': len(queries),
        'queries': queries
    }

    result = json.dumps(output, indent=2)
    if output_file and output_file != '-':
        with open(output_file, 'w') as f:
            f.write(result)
        print(f"[expand] Generated {len(queries)} expanded queries from '{topic[:50]}...' -> {output_file}", file=sys.stderr)
    else:
        print(result)
        print(f"[expand] Generated {len(queries)} expanded queries from '{topic[:50]}...'", file=sys.stderr)

if __name__ == '__main__':
    topic = sys.argv[1] if len(sys.argv) > 1 else ''
    output_file = sys.argv[2] if len(sys.argv) > 2 else None
    expand_queries(topic, output_file)
PYEOF

# 执行 Python 脚本
"$PYTHON_BIN" "$TMP_PY" "$TOPIC" "$OUTPUT_FILE"
