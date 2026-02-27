# -----------------------------
# Config
# -----------------------------
TYPE_SPEED        ?= 24
PAUSE_AFTER_CMD   ?= 0.6
HELLOWORLD_SCRIPT ?= docs/hello-world.sh
HELLOWORLD_CAST   ?= docs/hello-world.cast
HELLOWORLD_SVG    ?= docs/hello-world.svg
HELLOWORLD_TITLE  ?= Confidential Hello World
CONFIGMAP_SCRIPT  ?= docs/configmap.sh
CONFIGMAP_CAST    ?= docs/configmap.cast
CONFIGMAP_SVG     ?= docs/configmap.svg
CONFIGMAP_TITLE   ?= Confidential ConfigMap
WEBSERVER_SCRIPT  ?= docs/web-server.sh
WEBSERVER_CAST    ?= docs/web-server.cast
WEBSERVER_SVG     ?= docs/web-server.svg
WEBSERVER_TITLE   ?= Confidential Web Server
COLS              ?= 100

DEPS := asciinema svg-term

RED   := \033[0;31m
GREEN := \033[0;32m
YELLOW:= \033[1;33m
RESET := \033[0m

.PHONY: all record svg configmap-record configmap-svg web-server-record web-server-svg check-deps clean help
all: record svg configmap-record configmap-svg web-server-record web-server-svg

# -----------------------------
# Record
# -----------------------------

$(HELLOWORLD_CAST): $(HELLOWORLD_SCRIPT) $(HELLOWORLD_CAST) | check-deps
	@echo "$(YELLOW)Recording to $(HELLOWORLD_CAST)…$(RESET)"
	@TYPE_SPEED=$(TYPE_SPEED) PAUSE_AFTER_CMD=$(PAUSE_AFTER_CMD) \
	asciinema rec --overwrite -q -t "$(HELLOWORLD_TITLE)" -c "$(HELLOWORLD_SCRIPT)" $@
	@echo "$(GREEN)✓ Recorded: $(HELLOWORLD_CAST)$(RESET)"

# -----------------------------
# Render SVG
# -----------------------------

$(HELLOWORLD_SVG): $(HELLOWORLD_CAST) | check-deps
	@echo "$(YELLOW)Exporting SVG to $(HELLOWORLD_SVG)…$(RESET)"
	@cat "$(HELLOWORLD_CAST)" | NODE_OPTIONS="--max-old-space-size=8192" svg-term --out "$(HELLOWORLD_SVG)" --window --no-cursor  --width $(COLS)
	@echo "$(GREEN)✓ SVG created: $(HELLOWORLD_SVG)$(RESET)"

$(CONFIGMAP_CAST): $(CONFIGMAP_SCRIPT) | check-deps
	@echo "$(YELLOW)Recording to $(CONFIGMAP_CAST)…$(RESET)"
	@TYPE_SPEED=$(TYPE_SPEED) PAUSE_AFTER_CMD=$(PAUSE_AFTER_CMD) \
	asciinema rec --overwrite -q -t "$(CONFIGMAP_TITLE)" -c "$(CONFIGMAP_SCRIPT)" $@
	@echo "$(GREEN)✓ Recorded: $(CONFIGMAP_CAST)$(RESET)"

$(CONFIGMAP_SVG): $(CONFIGMAP_CAST) | check-deps
	@echo "$(YELLOW)Exporting SVG to $(CONFIGMAP_SVG)…$(RESET)"
	@cat "$(CONFIGMAP_CAST)" | NODE_OPTIONS="--max-old-space-size=8192" svg-term --out "$(CONFIGMAP_SVG)" --window --no-cursor --width $(COLS)
	@echo "$(GREEN)✓ SVG created: $(CONFIGMAP_SVG)$(RESET)"

$(WEBSERVER_CAST): $(WEBSERVER_SCRIPT) | check-deps
	@echo "$(YELLOW)Recording to $(WEBSERVER_CAST)…$(RESET)"
	@TYPE_SPEED=$(TYPE_SPEED) PAUSE_AFTER_CMD=$(PAUSE_AFTER_CMD) \
	asciinema rec --overwrite -q -t "$(WEBSERVER_TITLE)" -c "$(WEBSERVER_SCRIPT)" $@
	@echo "$(GREEN)✓ Recorded: $(WEBSERVER_CAST)$(RESET)"

$(WEBSERVER_SVG): $(WEBSERVER_CAST) | check-deps
	@echo "$(YELLOW)Exporting SVG to $(WEBSERVER_SVG)…$(RESET)"
	@cat "$(WEBSERVER_CAST)" | NODE_OPTIONS="--max-old-space-size=8192"  svg-term --out "$(WEBSERVER_SVG)" --window --no-cursor --width $(COLS)
	@echo "$(GREEN)✓ SVG created: $(WEBSERVER_SVG)$(RESET)"

# Front-door targets, matching your original names
record:  $(HELLOWORLD_CAST)
svg:    $(HELLOWORLD_SVG)
configmap-record: $(CONFIGMAP_CAST)
configmap-svg:    $(CONFIGMAP_SVG)
web-server-record: $(WEBSERVER_CAST)
web-server-svg:    $(WEBSERVER_SVG)

# -----------------------------
# Dependency checks
# -----------------------------
check-deps:
	@missing=""
	@for cmd in $(DEPS); do command -v $$cmd >/dev/null 2>&1 || missing="$$missing $$cmd"; done; \
	if [ -n "$$missing" ]; then \
	  echo "$(RED)Missing tools:$$missing$(RESET)\n"; \
	  echo "Install:"; \
	  echo "  asciinema : (Linux) your pkg mgr | (macOS) brew install asciinema | (PyPI 2.x) pipx install asciinema"; \
	  echo "  svg-term  : npm install -g svg-term-cli"; \
	  exit 1; \
	else \
	  echo "$(GREEN)All dependencies available: $(DEPS)$(RESET)"; \
	fi

# -----------------------------
# Utilities
# -----------------------------
clean:
	@rm -f "$(HELLOWORLD_CAST)" "$(HELLOWORLD_SVG)" "$(CONFIGMAP_CAST)" "$(CONFIGMAP_SVG)" "$(WEBSERVER_CAST)" "$(WEBSERVER_SVG)"
	@echo "$(GREEN)Cleaned$(RESET)"

help:
	@echo "Targets: record | svg | configmap-record | configmap-svg | web-server-record | web-server-svg | check-deps | clean | all"
	@echo "Vars: TYPE_SPEED PAUSE_AFTER_CMD HELLOWORLD_* CONFIGMAP_* WEBSERVER_* COLS"
