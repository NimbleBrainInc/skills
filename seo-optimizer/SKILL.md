---
name: seo-optimizer
description: Analyzes and optimizes content for search engine visibility. Use when reviewing blog posts for SEO, optimizing landing pages, checking meta descriptions, analyzing keyword usage, or improving content discoverability. Triggers include "optimize for SEO", "check SEO", "improve search ranking", or "keyword analysis".
metadata:
  version: 1.0.6
  category: marketing
  tags:
    - seo
    - content
    - marketing
    - optimization
    - search
  triggers:
    - optimize for SEO
    - check SEO
    - improve search ranking
    - keyword analysis
    - review for search
    - SEO audit
    - meta description
  surfaces:
    - claude-code
    - claude-ai
  author:
    name: NimbleBrain
    url: https://www.nimblebrain.ai
---

# SEO Optimizer

Analyze and optimize content for search engine visibility. Focus on actionable improvements that balance search optimization with reader experience.

## Quick Start

When reviewing content, produce this assessment:

```markdown
## SEO Analysis: [Title]

**Target Keyword:** [identified or suggested]
**Current Score:** X/100

### Critical Issues
1. [Most impactful problem]
2. [Second most impactful]

### Quick Wins
- [ ] [Specific change with expected impact]
- [ ] [Specific change with expected impact]
```

## Analysis Framework

### Phase 1: Keyword Analysis

**Primary Keyword Identification**
- What term should this content rank for?
- Is the keyword in the title, H1, URL, and first 100 words?
- What's the search intent? (Informational, transactional, navigational)

**Keyword Placement Checklist**
```
[ ] Title tag (front-loaded preferred)
[ ] H1 heading
[ ] First paragraph (within first 100 words)
[ ] At least one H2 subheading
[ ] Meta description
[ ] URL slug
[ ] Image alt text (where relevant)
[ ] Natural usage throughout (2-3% density max)
```

**Keyword Variants**
- List 3-5 semantic variations / LSI keywords
- Check if content naturally incorporates these
- Suggest additions where forced phrasing can be avoided

### Phase 2: On-Page Elements

**Title Tag (50-60 characters)**
```
Current: [existing title]
Length: X characters
Issues: [too long/short, keyword missing, not compelling]
Suggested: [optimized version]
```

**Meta Description (150-160 characters)**
```
Current: [existing or "MISSING"]
Length: X characters
Issues: [no CTA, keyword missing, truncated]
Suggested: [optimized version with CTA]
```

**URL Structure**
```
Current: [URL]
Issues: [too long, no keyword, unnecessary parameters]
Suggested: [clean URL with keyword]
```

**Heading Structure**
```
H1: [text] - [assessment]
  H2: [text] - [assessment]
    H3: [text] - [assessment]
  H2: [text] - [assessment]

Issues:
- [ ] Multiple H1s (should be exactly one)
- [ ] Skipped heading levels
- [ ] Keywords missing from subheadings
- [ ] Generic headings ("Introduction", "Conclusion")
```

### Phase 3: Content Quality Signals

**Content Depth**
- Word count: X words
- Competitor average: ~Y words (estimate or research)
- Assessment: [thin/adequate/comprehensive]
- Recommendation: [specific sections to expand]

**E-E-A-T Signals (Experience, Expertise, Authoritativeness, Trust)**
```
[ ] Author byline with credentials
[ ] First-hand experience demonstrated
[ ] External authoritative sources cited
[ ] Internal links to related content
[ ] Updated date shown
[ ] Contact/about information accessible
```

**Content Freshness**
- Published date: [date]
- Last updated: [date or "not shown"]
- Outdated references: [list any]
- Recommendation: [update needed / current]

### Phase 4: Technical SEO Elements

**Image Optimization**
```
| Image | Alt Text | File Size | Format | Issues |
|-------|----------|-----------|--------|--------|
| [name] | [text or MISSING] | [size] | [format] | [issues] |
```

**Internal Linking**
- Outbound internal links: X
- Assessment: [too few / adequate / excessive]
- Suggested additions: [specific pages to link]

**External Linking**
- Outbound external links: X
- Link to authoritative sources: [yes/no]
- Broken links found: [list]

**Schema Markup Opportunities**
- Article schema: [present/missing]
- FAQ schema: [applicable/not applicable]
- How-to schema: [applicable/not applicable]
- Other relevant schema: [suggestions]

### Phase 5: User Experience Factors

**Readability**
- Flesch-Kincaid Grade: X
- Target for topic: Y
- Assessment: [appropriate / too complex / too simple]

**Scannability**
```
[ ] Short paragraphs (3-4 sentences max)
[ ] Bullet points for lists
[ ] Bold/emphasis on key points
[ ] Table of contents for long content
[ ] Clear section breaks
```

**Mobile Considerations**
- Long unbroken paragraphs: [count]
- Wide tables that may not render: [count]
- Recommendation: [specific fixes]

## Output Format

### SEO Audit Report

```markdown
# SEO Audit: [Page Title]

**URL:** [url]
**Target Keyword:** [keyword]
**Overall Score:** X/100

---

## Executive Summary

[2-3 sentences: Main strengths and the single most impactful improvement needed]

---

## Scores by Category

| Category | Score | Priority |
|----------|-------|----------|
| Keyword Optimization | X/20 | [High/Med/Low] |
| On-Page Elements | X/20 | [High/Med/Low] |
| Content Quality | X/25 | [High/Med/Low] |
| Technical SEO | X/20 | [High/Med/Low] |
| User Experience | X/15 | [High/Med/Low] |
| **Total** | **X/100** | |

---

## Critical Issues (Fix First)

1. **[Issue]**
   - Current: [state]
   - Impact: [why it matters]
   - Fix: [specific action]

2. **[Issue]**
   - Current: [state]
   - Impact: [why it matters]
   - Fix: [specific action]

---

## Quick Wins (Easy Improvements)

- [ ] [Specific change] - [expected impact]
- [ ] [Specific change] - [expected impact]
- [ ] [Specific change] - [expected impact]

---

## Detailed Findings

### Keyword Optimization
[Detailed analysis]

### On-Page Elements
[Detailed analysis with suggested rewrites]

### Content Quality
[Detailed analysis with expansion suggestions]

### Technical SEO
[Detailed analysis]

### User Experience
[Detailed analysis]

---

## Competitor Gap Analysis

[If applicable: What top-ranking competitors cover that this content doesn't]

---

## Recommended Next Steps

1. [Highest priority action]
2. [Second priority action]
3. [Third priority action]
```

## Scoring Rubric

**Keyword Optimization (20 points)**
- Primary keyword in title: 5 pts
- Keyword in H1 and first 100 words: 5 pts
- Keyword in URL and meta: 5 pts
- Natural keyword density: 5 pts

**On-Page Elements (20 points)**
- Optimized title tag: 5 pts
- Compelling meta description: 5 pts
- Clean URL structure: 5 pts
- Proper heading hierarchy: 5 pts

**Content Quality (25 points)**
- Sufficient depth for topic: 8 pts
- E-E-A-T signals present: 7 pts
- Original insights/value: 5 pts
- Current/fresh content: 5 pts

**Technical SEO (20 points)**
- Image optimization: 5 pts
- Internal linking: 5 pts
- External linking to authority: 5 pts
- Schema opportunity utilized: 5 pts

**User Experience (15 points)**
- Appropriate readability: 5 pts
- Scannable formatting: 5 pts
- Mobile-friendly structure: 5 pts

## Anti-Patterns

**Don't:**
- Recommend keyword stuffing (>3% density is spam)
- Suggest clickbait titles that don't match content
- Prioritize SEO over reader experience
- Ignore search intent in recommendations
- Recommend thin content just to hit word counts

**Do:**
- Balance optimization with natural language
- Consider the reader's actual questions
- Recommend substantive improvements over tricks
- Acknowledge when content is already well-optimized
- Suggest topic clusters and internal linking strategy

## Tools Integration

When available, use these to enhance analysis:
- Web search: Research competitor content and current rankings
- Web fetch: Analyze competitor pages for comparison
- Check current search results for target keyword

## Common Issues by Content Type

**Blog Posts**
- Missing author byline
- No internal links to related content
- Generic headings
- No clear CTA or next step

**Landing Pages**
- Thin content (under 500 words)
- Missing schema markup
- No trust signals
- Keyword-stuffed headings

**Documentation**
- Missing meta descriptions
- Poor heading structure
- No breadcrumb schema
- Outdated information
