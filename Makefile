# -----------------------------
# Config
# -----------------------------
TYPE_SPEED        ?= 24
PAUSE_AFTER_CMD   ?= 0.6
HELLOWORLD_SCRIPT ?= docs/hello-world.sh
HELLOWORLD_CAST   ?= docs/hello-world.cast
HELLOWORLD_WEBM   ?= docs/hello-world.webm
HELLOWORLD_TITLE  ?= Confidential Hello World
CONFIGMAP_SCRIPT  ?= docs/configmap.sh
CONFIGMAP_CAST    ?= docs/configmap.cast
CONFIGMAP_WEBM    ?= docs/configmap.webm
CONFIGMAP_TITLE   ?= Confidential ConfigMap
WEBSERVER_SCRIPT  ?= docs/web-server.sh
WEBSERVER_CAST    ?= docs/web-server.cast
WEBSERVER_WEBM    ?= docs/web-server.webm
WEBSERVER_TITLE   ?= Confidential Web Server
COLS              ?= 100

DEPS := asciinema agg

RED   := \033[0;31m
GREEN := \033[0;32m
YELLOW:= \033[1;33m
RESET := \033[0m

.PHONY: all record webm configmap-record configmap-webm web-server-record web-server-webm check-deps clean help
all: record webm configmap-record configmap-webm web-server-record web-server-webm

# -----------------------------
# Record
# -----------------------------

$(HELLOWORLD_CAST): $(HELLOWORLD_SCRIPT) | check-deps
	@echo "$(YELLOW)Recording to $(HELLOWORLD_CAST)…$(RESET)"
	@TYPE_SPEED=$(TYPE_SPEED) PAUSE_AFTER_CMD=$(PAUSE_AFTER_CMD) \
	asciinema rec --overwrite -q -t "$(HELLOWORLD_TITLE)" -c "$(HELLOWORLD_SCRIPT)" $@
	@echo "$(GREEN)✓ Recorded: $(HELLOWORLD_CAST)$(RESET)"

# -----------------------------
# Render WEBM
# -----------------------------

$(HELLOWORLD_WEBM): $(HELLOWORLD_CAST) | check-deps
	@echo "$(YELLOW)Exporting WEBM to $(HELLOWORLD_WEBM)…$(RESET)"
	@agg "$(HELLOWORLD_CAST)" "$(HELLOWORLD_WEBM)"
	@echo "$(GREEN)✓ WEBM created: $(HELLOWORLD_WEBM)$(RESET)"

$(CONFIGMAP_CAST): $(CONFIGMAP_SCRIPT) | check-deps
	@echo "$(YELLOW)Recording to $(CONFIGMAP_CAST)…$(RESET)"
	@TYPE_SPEED=$(TYPE_SPEED) PAUSE_AFTER_CMD=$(PAUSE_AFTER_CMD) \
	asciinema rec --overwrite -q -t "$(CONFIGMAP_TITLE)" -c "$(CONFIGMAP_SCRIPT)" $@
	@echo "$(GREEN)✓ Recorded: $(CONFIGMAP_CAST)$(RESET)"

$(CONFIGMAP_WEBM): $(CONFIGMAP_CAST) | check-deps
	@echo "$(YELLOW)Exporting WEBM to $(CONFIGMAP_WEBM)…$(RESET)"
	@agg "$(CONFIGMAP_CAST)" "$(CONFIGMAP_WEBM)"
	@echo "$(GREEN)✓ WEBM created: $(CONFIGMAP_WEBM)$(RESET)"

$(WEBSERVER_CAST): $(WEBSERVER_SCRIPT) | check-deps
	@echo "$(YELLOW)Recording to $(WEBSERVER_CAST)…$(RESET)"
	@TYPE_SPEED=$(TYPE_SPEED) PAUSE_AFTER_CMD=$(PAUSE_AFTER_CMD) \
	asciinema rec --overwrite -q -t "$(WEBSERVER_TITLE)" -c "$(WEBSERVER_SCRIPT)" $@
	@echo "$(GREEN)✓ Recorded: $(WEBSERVER_CAST)$(RESET)"

$(WEBSERVER_WEBM): $(WEBSERVER_CAST) | check-deps
	@echo "$(YELLOW)Exporting WEBM to $(WEBSERVER_WEBM)…$(RESET)"
	@agg "$(WEBSERVER_CAST)" "$(WEBSERVER_WEBM)"
	@echo "$(GREEN)✓ WEBM created: $(WEBSERVER_WEBM)$(RESET)"

# Front-door targets, matching your original names
record:  $(HELLOWORLD_CAST)
webm:    $(HELLOWORLD_WEBM)
configmap-record: $(CONFIGMAP_CAST)
configmap-webm:    $(CONFIGMAP_WEBM)
web-server-record: $(WEBSERVER_CAST)
web-server-webm:    $(WEBSERVER_WEBM)

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
	@rm -f "$(HELLOWORLD_CAST)" "$(HELLOWORLD_WEBM)" "$(CONFIGMAP_CAST)" "$(CONFIGMAP_WEBM)" "$(WEBSERVER_CAST)" "$(WEBSERVER_WEBM)"
	@echo "$(GREEN)Cleaned$(RESET)"

help:
	@echo "Targets: record | webm | configmap-record | configmap-webm | web-server-record | web-server-webm | check-deps | clean | all"
	@echo "Vars: TYPE_SPEED PAUSE_AFTER_CMD HELLOWORLD_* CONFIGMAP_* WEBSERVER_* COLS"
