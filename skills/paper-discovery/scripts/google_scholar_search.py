#!/usr/bin/env python3
"""
Google Scholar Search Script using scholarly library
Usage: python google_scholar_search.py "query" [limit] [year_min]
"""

import sys
import json
import time
from scholarly import scholarly, ProxyGenerator

def search_scholar(query, limit=10, year_min=None):
    """
    Search Google Scholar for papers
    """
    try:
        # Setup proxy to avoid blocking (optional)
        # pg = ProxyGenerator()
        # pg.FreeProxies()
        # scholarly.use_proxy(pg)

        # Search for papers
        search_query = scholarly.search_pubs(query)

        papers = []
        count = 0

        for paper in search_query:
            if count >= limit:
                break

            try:
                # Extract paper info
                paper_data = {
                    'paper_id': paper.get('pub_url', ''),
                    'title': paper.get('bib', {}).get('title', ''),
                    'authors': [{'name': author} for author in paper.get('bib', {}).get('author', [])],
                    'year': paper.get('bib', {}).get('pub_year', 0),
                    'abstract': paper.get('bib', {}).get('abstract', ''),
                    'venue': paper.get('bib', {}).get('venue', ''),
                    'citation_count': paper.get('num_citations', 0),
                    'doi': '',
                    'url': paper.get('pub_url', ''),
                    'pdf_url': paper.get('eprint_url', ''),
                    'source': 'Google Scholar'
                }

                # Filter by year if specified
                if year_min and paper_data['year']:
                    try:
                        if int(paper_data['year']) < int(year_min):
                            continue
                    except:
                        pass

                papers.append(paper_data)
                count += 1

                # Be nice to the server
                time.sleep(0.5)

            except Exception as e:
                print(f"Error processing paper: {e}", file=sys.stderr)
                continue

        output = {
            'query': query,
            'limit': limit,
            'year_min': year_min,
            'count': len(papers),
            'source': 'google_scholar',
            'papers': papers
        }

        # Force UTF-8 output
        import io
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
        print(json.dumps(output, indent=2, ensure_ascii=False))

    except Exception as e:
        error_output = {
            'query': query,
            'error': str(e),
            'source': 'google_scholar',
            'papers': []
        }
        import io
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
        print(json.dumps(error_output, indent=2))
        sys.exit(1)

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python google_scholar_search.py <query> [limit] [year_min]", file=sys.stderr)
        sys.exit(1)

    query = sys.argv[1]
    limit = int(sys.argv[2]) if len(sys.argv) > 2 else 10
    year_min = int(sys.argv[3]) if len(sys.argv) > 3 else None

    search_scholar(query, limit, year_min)
