# Developer Environment Setup

Full from-scratch setup scripts by language. For per-tool install commands, see the onboarding flow in SKILL.md.

## Python path

**macOS:**
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
uv python install 3.13
uv tool install ruff
uv tool install ty
brew install --cask docker
brew install gh
gh auth login
npm install -g @nimblebrain/mpak
```

**Linux:**
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
uv python install 3.13
uv tool install ruff
uv tool install ty
# Docker: see https://docs.docker.com/engine/install/
sudo apt install gh   # Debian/Ubuntu
gh auth login
npm install -g @nimblebrain/mpak
```

## TypeScript path

**macOS:**
```bash
brew install node
npm install -g @biomejs/biome
npm install -g vitest
brew install --cask docker
brew install gh
gh auth login
npm install -g @nimblebrain/mpak
```

**Linux:**
```bash
nvm install --lts
npm install -g @biomejs/biome
npm install -g vitest
# Docker: see https://docs.docker.com/engine/install/
sudo apt install gh   # Debian/Ubuntu
gh auth login
npm install -g @nimblebrain/mpak
```
