#!/bin/bash
# Validate skill frontmatter against the mpak registry schema

set -e

# Fetch schema from API
SCHEMA=$(curl -s https://api.mpak.dev/docs/json | \
  jq '.paths["/v1/skills/announce"].post.requestBody.content["application/json"].schema.properties.skill')

if [ "$SCHEMA" = "null" ] || [ -z "$SCHEMA" ]; then
  echo "❌ Failed to fetch schema from API"
  exit 1
fi

echo "$SCHEMA" > /tmp/skill-schema.json
echo "Fetched schema from registry"

# Check for ajv
if ! command -v ajv &> /dev/null; then
  echo "Installing ajv-cli..."
  npm install -g ajv-cli ajv-formats
fi

ERRORS=0

# Validate each skill
for dir in */; do
  if [ -f "$dir/SKILL.md" ]; then
    SKILL="${dir%/}"

    # Extract YAML frontmatter and convert to JSON
    FRONTMATTER=$(awk '/^---$/{if(f){exit}f=1;next}f' "$dir/SKILL.md" | yq -o=json '.')

    if [ -z "$FRONTMATTER" ] || [ "$FRONTMATTER" = "null" ]; then
      echo "❌ $SKILL: No valid frontmatter"
      ERRORS=$((ERRORS + 1))
      continue
    fi

    echo "$FRONTMATTER" > /tmp/frontmatter.json

    if ajv validate -s /tmp/skill-schema.json -d /tmp/frontmatter.json --spec=draft2020 --strict=false 2>&1 | grep -q "invalid"; then
      echo "❌ $SKILL: Schema validation failed"
      ajv validate -s /tmp/skill-schema.json -d /tmp/frontmatter.json --spec=draft2020 --strict=false 2>&1
      ERRORS=$((ERRORS + 1))
    else
      echo "✓ $SKILL"
    fi
  fi
done

echo ""
if [ $ERRORS -gt 0 ]; then
  echo "❌ $ERRORS skill(s) failed validation"
  exit 1
fi

echo "✅ All skills valid"
