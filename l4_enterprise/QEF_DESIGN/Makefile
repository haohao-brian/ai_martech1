# QEF_DESIGN Makefile
#
# Two responsibilities:
#   1. Pipeline dispatcher → forwards everything else to scripts/update_scripts/Makefile
#      (keeps `make config-merge`, `make run`, `make status`, etc working)
#   2. Deployment targets → adapted from MAMBA/Makefile per #579, GitHub-flow:
#      `make deploy-sync` → `make deploy-push` → Posit Connect rebuilds from GitHub repo
#
# Deployment commands:
#   make deploy-sync      # rsync dev tree → deployment/, materialize symlinks
#   make deploy-push      # commit + push → triggers Posit Connect rebuild
#   make deploy-status    # show git status of deployment/
#   make deploy-diff      # show git diff --stat
#   make deploy-manifest  # regenerate manifest.json
#   make deploy-init      # bootstrap deployment/ git repo + reminder to gh repo create

PROJECT_ROOT := $(CURDIR)
PIPELINE_DIR := $(CURDIR)/scripts/update_scripts
GLOBAL_SCRIPTS := $(CURDIR)/scripts/global_scripts

DEPLOY_DIR := deployment/qef_design-analytics
GITHUB_REPO := kiki830621/ai_martech_l4_QEF_DESIGN_deploy

.PHONY: help deploy-init deploy-sync deploy-push deploy-status deploy-diff deploy-manifest

help:
	@echo "QEF_DESIGN — pipeline + deployment commands"
	@echo ""
	@echo "  Pipeline (dispatched to scripts/update_scripts/Makefile):"
	@echo "    make config-merge    - merge base + company config"
	@echo "    make run             - run all enabled pipelines"
	@echo "    make status          - check pipeline progress"
	@echo "    make e2e             - run E2E tests"
	@echo ""
	@echo "  Deployment (GitHub-flow, account: kyle-lin):"
	@echo "    make deploy-sync     - sync dev → $(DEPLOY_DIR) (rsync -avL resolves symlinks)"
	@echo "    make deploy-push     - commit + push → Posit Connect auto-rebuild"
	@echo "    make deploy-diff     - show changes about to push"
	@echo "    make deploy-status   - show git status of $(DEPLOY_DIR)"
	@echo "    make deploy-manifest - regenerate manifest.json"
	@echo ""
	@echo "  First-time setup:"
	@echo "    make deploy-init     - bootstrap $(DEPLOY_DIR) + git repo (run once)"

# ========== Deployment ==========

deploy-sync:
	@echo "Syncing dev -> $(DEPLOY_DIR)..."
	@test -d $(DEPLOY_DIR) || (echo "[ERR] Deploy dir missing - run 'make deploy-init' first" && exit 1)
	@# Core app files
	@cp app.R $(DEPLOY_DIR)/app.R
	@cp app_config.yaml $(DEPLOY_DIR)/app_config.yaml
	@cp .Rprofile $(DEPLOY_DIR)/.Rprofile 2>/dev/null || true
	@cp .rsconnectignore $(DEPLOY_DIR)/.rsconnectignore
	@cp .env $(DEPLOY_DIR)/.env 2>/dev/null || true
	@# manifest.json (from dev — regenerate via deploy-manifest if needed)
	@cp manifest.json $(DEPLOY_DIR)/manifest.json 2>/dev/null || true
	@# www static assets (-L resolves symlinks)
	@mkdir -p $(DEPLOY_DIR)/www
	@rsync -avL --delete www/ $(DEPLOY_DIR)/www/ 2>/dev/null || true
	@# scripts (rsync -avL resolves symlinks to real files; DM_R063 deny *.duckdb)
	@rsync -avL --delete \
		--exclude='.DS_Store' \
		--exclude='*.duckdb' \
		--exclude='*.wal' \
		--exclude='.git' \
		--exclude='.gitrepo' \
		--exclude='__pycache__' \
		--exclude='.Rproj.user' \
		scripts/global_scripts/ $(DEPLOY_DIR)/scripts/global_scripts/
	@rsync -avL --delete \
		--exclude='.DS_Store' \
		--exclude='.git' \
		--exclude='.gitrepo' \
		scripts/nsql/ $(DEPLOY_DIR)/scripts/nsql/ 2>/dev/null || true
	@# Parameters metadata (df_product_line.csv etc — not duckdb, must ship)
	@mkdir -p $(DEPLOY_DIR)/data/app_data/parameters
	@rsync -avL --delete \
		--exclude='.DS_Store' \
		--exclude='*.duckdb' \
		--exclude='*.wal' \
		data/app_data/parameters/ $(DEPLOY_DIR)/data/app_data/parameters/ 2>/dev/null || true
	@# NOTE: meta_data.duckdb intentionally NOT shipped (DM_R063 deploy bundle purity).
	@# Posit Connect runs database.mode: supabase, reads metadata from Supabase.
	@echo ""
	@echo "[OK] Sync complete. Run 'make deploy-push' to commit + push."

.PHONY: dashboard-presence-gate
# MP165 Dashboard-Presence Gate (Tier 2 deploy gate)
# Runs the per-company contract suite before deploy-push commits +
# pushes. Critical contract failure refuses the deploy. See spectra
# change dashboard-presence-verification (issue #599).
# Override: set MP165_SKIP=true to bypass (emergency only — use sparingly).
dashboard-presence-gate:
	@if [ "$(MP165_SKIP)" = "true" ]; then \
		echo "[WARN] MP165 deploy gate SKIPPED via MP165_SKIP=true (emergency override)"; \
	else \
		echo "[INFO] Running MP165 dashboard-presence gate for QEF_DESIGN..."; \
		Rscript scripts/global_scripts/23_deployment/dashboard_presence_gate.R \
			--company QEF_DESIGN --app-dir $(CURDIR) --dry-run \
		|| { echo "[ERR] MP165 deploy gate refused deploy"; exit 1; }; \
		echo "[OK] MP165 gate passed (dry-run; full Shiny eval pending #588)."; \
	fi

deploy-push: dashboard-presence-gate
	@echo "Committing + pushing deployment..."
	@test -d $(DEPLOY_DIR)/.git || (echo "[ERR] $(DEPLOY_DIR) is not a git repo - run 'make deploy-init' first" && exit 1)
	@cd $(DEPLOY_DIR) && \
		git add -A && \
		if git diff --cached --quiet; then \
			echo "[INFO] No changes to push"; \
		else \
			git commit -m "Deploy: $$(date '+%Y-%m-%d %H:%M')" && \
			git push && \
			echo "[OK] Pushed. Posit Connect will rebuild from $(GITHUB_REPO)."; \
		fi

deploy-diff:
	@cd $(DEPLOY_DIR) && git diff --stat

deploy-status:
	@cd $(DEPLOY_DIR) && git status

deploy-manifest:
	@echo "Regenerating manifest.json..."
	@cd $(DEPLOY_DIR) && \
		Rscript -e "rsconnect::writeManifest(appDir = '.', appPrimaryDoc = 'app.R')"
	@echo "[OK] manifest.json regenerated"

deploy-init:
	@echo "Initializing QEF_DESIGN deploy directory..."
	@test ! -d $(DEPLOY_DIR)/.git || (echo "[ERR] $(DEPLOY_DIR) already initialized - delete first if rebuilding" && exit 1)
	@mkdir -p $(DEPLOY_DIR)/scripts
	@cp deployment/.gitignore.deploy $(DEPLOY_DIR)/.gitignore
	@$(MAKE) deploy-sync
	@cd $(DEPLOY_DIR) && \
		git init && \
		git add -A && \
		git commit -m "Initial deployment: QEF_DESIGN Enterprise"
	@echo ""
	@echo "[OK] Deploy directory initialized."
	@echo ""
	@echo "Next steps (USER ACTIONS - AI cannot do these):"
	@echo "  1. Create GitHub deploy repo:"
	@echo "     cd $(DEPLOY_DIR) && gh repo create $(GITHUB_REPO) --private --source=. --push"
	@echo ""
	@echo "  2. On Posit Connect Cloud (https://connect.posit.cloud):"
	@echo "     Publish -> Shiny -> select $(GITHUB_REPO) -> enable git auto-rebuild on push"
	@echo ""
	@echo "  3. Populate Connect Variable Set (mirrors local .env):"
	@echo "     OPENAI_API_KEY, PGHOST/PGPORT/PGUSER/PGPASSWORD/PGDATABASE/PGSSLMODE,"
	@echo "     SUPABASE_URL/SUPABASE_ANON_KEY, APP_PASSWORD"

# ========== Pipeline dispatcher (catch-all) ==========
# Forwards anything not explicitly defined above to the pipeline Makefile.
%:
	@$(MAKE) -f scripts/update_scripts/Makefile $@ \
		PROJECT_ROOT="$(PROJECT_ROOT)" \
		PIPELINE_DIR="$(PIPELINE_DIR)" \
		GLOBAL_SCRIPTS="$(GLOBAL_SCRIPTS)"
