# -----------------------------
# Config
# -----------------------------
TYPE_SPEED        ?= 24
PAUSE_AFTER_CMD   ?= 0.6
HELLOWORLD_SCRIPT ?= docs/hello-world.sh
HELLOWORLD_CAST   ?= docs/hello-world.cast
HELLOWORLD_GIF   ?= docs/hello-world.gif
HELLOWORLD_TITLE  ?= Confidential Hello World
CONFIGMAP_SCRIPT  ?= docs/configmap.sh
CONFIGMAP_CAST    ?= docs/configmap.cast
CONFIGMAP_GIF    ?= docs/configmap.gif
CONFIGMAP_TITLE   ?= Confidential ConfigMap
WEBSERVER_SCRIPT  ?= docs/web-server.sh
WEBSERVER_CAST    ?= docs/web-server.cast
WEBSERVER_GIF    ?= docs/web-server.gif
WEBSERVER_TITLE   ?= Confidential Web Server
COLS              ?= 100
ROWS              ?= 50

DEPS := asciinema agg

RED   := \033[0;31m
GREEN := \033[0;32m
YELLOW:= \033[1;33m
RESET := \033[0m

.PHONY: all record gif configmap-record configmap-gif web-server-record web-server-gif check-deps clean help
all: record gif configmap-record configmap-gif web-server-record web-server-gif

# -----------------------------
# Record
# -----------------------------

$(HELLOWORLD_CAST): $(HELLOWORLD_SCRIPT) | check-deps
	@echo "$(YELLOW)Recording to $(HELLOWORLD_CAST)…$(RESET)"
	@TYPE_SPEED=$(TYPE_SPEED) PAUSE_AFTER_CMD=$(PAUSE_AFTER_CMD) \
	asciinema rec --cols "$(COLS)" --rows "$(ROWS)" --overwrite -q -t "$(HELLOWORLD_TITLE)" -c "$(HELLOWORLD_SCRIPT)" $@
	@echo "$(GREEN)✓ Recorded: $(HELLOWORLD_CAST)$(RESET)"

# -----------------------------
# Render GIF
# -----------------------------

$(HELLOWORLD_GIF): $(HELLOWORLD_CAST) | check-deps
	@echo "$(YELLOW)Exporting GIF to $(HELLOWORLD_GIF)…$(RESET)"
	@agg --cols "$(COLS)" --rows "$(ROWS)" "$(HELLOWORLD_CAST)" "$(HELLOWORLD_GIF)"
	@echo "$(GREEN)✓ GIF created: $(HELLOWORLD_GIF)$(RESET)"

$(CONFIGMAP_CAST): $(CONFIGMAP_SCRIPT) | check-deps
	@echo "$(YELLOW)Recording to $(CONFIGMAP_CAST)…$(RESET)"
	@TYPE_SPEED=$(TYPE_SPEED) PAUSE_AFTER_CMD=$(PAUSE_AFTER_CMD) \
	asciinema rec --cols "$(COLS)" --rows "$(ROWS)" --overwrite -q -t "$(CONFIGMAP_TITLE)" -c "$(CONFIGMAP_SCRIPT)" $@
	@echo "$(GREEN)✓ Recorded: $(CONFIGMAP_CAST)$(RESET)"

$(CONFIGMAP_GIF): $(CONFIGMAP_CAST) | check-deps
	@echo "$(YELLOW)Exporting GIF to $(CONFIGMAP_GIF)…$(RESET)"
	@agg --cols "$(COLS)" --rows "$(ROWS)" "$(CONFIGMAP_CAST)" "$(CONFIGMAP_GIF)"
	@echo "$(GREEN)✓ GIF created: $(CONFIGMAP_GIF)$(RESET)"

$(WEBSERVER_CAST): $(WEBSERVER_SCRIPT) | check-deps
	@echo "$(YELLOW)Recording to $(WEBSERVER_CAST)…$(RESET)"
	@TYPE_SPEED=$(TYPE_SPEED) PAUSE_AFTER_CMD=$(PAUSE_AFTER_CMD) \
	asciinema rec --cols "$(COLS)" --rows "$(ROWS)" --overwrite -q -t "$(WEBSERVER_TITLE)" -c "$(WEBSERVER_SCRIPT)" $@
	@echo "$(GREEN)✓ Recorded: $(WEBSERVER_CAST)$(RESET)"

$(WEBSERVER_GIF): $(WEBSERVER_CAST) | check-deps
	@echo "$(YELLOW)Exporting GIF to $(WEBSERVER_GIF)…$(RESET)"
	@agg --cols "$(COLS)" --rows "$(ROWS)" "$(WEBSERVER_CAST)" "$(WEBSERVER_GIF)"
	@echo "$(GREEN)✓ GIF created: $(WEBSERVER_GIF)$(RESET)"

# Front-door targets, matching your original names
record:  $(HELLOWORLD_CAST)
gif:    $(HELLOWORLD_GIF)
configmap-record: $(CONFIGMAP_CAST)
configmap-gif:    $(CONFIGMAP_GIF)
web-server-record: $(WEBSERVER_CAST)
web-server-gif:    $(WEBSERVER_GIF)

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
	  echo "  agg       : https://github.com/asciinema/agg"; \
	  exit 1; \
	else \
	  echo "$(GREEN)All dependencies available: $(DEPS)$(RESET)"; \
	fi

# -----------------------------
# Utilities
# -----------------------------
clean:
	@rm -f "$(HELLOWORLD_CAST)" "$(HELLOWORLD_GIF)" "$(CONFIGMAP_CAST)" "$(CONFIGMAP_GIF)" "$(WEBSERVER_CAST)" "$(WEBSERVER_GIF)"
	@echo "$(GREEN)Cleaned$(RESET)"

help:
	@echo "Targets: record | gif | configmap-record | configmap-gif | web-server-record | web-server-gif | check-deps | clean | all"
	@echo "Vars: TYPE_SPEED PAUSE_AFTER_CMD HELLOWORLD_* CONFIGMAP_* WEBSERVER_* COLS"
