# -----------------------------
# Config
# -----------------------------
TYPE_SPEED        ?= 24
PAUSE_AFTER_CMD   ?= 0.6
HELLOWORLD_SCRIPT ?= docs/hello-world.sh
HELLOWORLD_CAST   ?= docs/hello-world.cast
HELLOWORLD_GIF   ?= docs/hello-world.gif
HELLOWORLD_MP4   ?= docs/hello-world.mp4
HELLOWORLD_TITLE  ?= Confidential Hello World
CONFIGMAP_SCRIPT  ?= docs/configmap.sh
CONFIGMAP_CAST    ?= docs/configmap.cast
CONFIGMAP_GIF    ?= docs/configmap.gif
CONFIGMAP_MP4    ?= docs/configmap.mp4
CONFIGMAP_TITLE   ?= Confidential ConfigMap
WEBSERVER_SCRIPT  ?= docs/web-server.sh
WEBSERVER_CAST    ?= docs/web-server.cast
WEBSERVER_GIF    ?= docs/web-server.gif
WEBSERVER_MP4    ?= docs/web-server.mp4
WEBSERVER_TITLE   ?= Confidential Web Server
FLASKREDIS_SCRIPT ?= docs/flask-redis.sh
FLASKREDIS_CAST   ?= docs/flask-redis.cast
FLASKREDIS_GIF    ?= docs/flask-redis.gif
FLASKREDIS_MP4    ?= docs/flask-redis.mp4
FLASKREDIS_TITLE  ?= Flask Redis Demo
NETWORKPOLICY_SCRIPT ?= docs/network-policy.sh
NETWORKPOLICY_CAST   ?= docs/network-policy.cast
NETWORKPOLICY_GIF    ?= docs/network-policy.gif
NETWORKPOLICY_MP4    ?= docs/network-policy.mp4
NETWORKPOLICY_TITLE  ?= Network Policy Demo
COLS              ?= 100
ROWS              ?= 50

DEPS := asciinema agg ffmpeg

RED   := \033[0;31m
GREEN := \033[0;32m
YELLOW:= \033[1;33m
RESET := \033[0m

.PHONY: all record gif mp4 configmap-record configmap-gif configmap-mp4 web-server-record web-server-gif web-server-mp4 flask-redis-record flask-redis-gif flask-redis-mp4 network-policy-record network-policy-gif network-policy-mp4 check-deps clean help
all: record gif mp4 configmap-record configmap-gif configmap-mp4 web-server-record web-server-gif web-server-mp4 flask-redis-record flask-redis-gif flask-redis-mp4 network-policy-record network-policy-gif network-policy-mp4

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

$(HELLOWORLD_MP4): $(HELLOWORLD_GIF) | check-deps
	@echo "$(YELLOW)Exporting MP4 to $(HELLOWORLD_MP4)…$(RESET)"
	@ffmpeg -y -i "$(HELLOWORLD_GIF)" -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -movflags +faststart -pix_fmt yuv420p "$(HELLOWORLD_MP4)" >/dev/null 2>&1
	@echo "$(GREEN)✓ MP4 created: $(HELLOWORLD_MP4)$(RESET)"

$(CONFIGMAP_CAST): $(CONFIGMAP_SCRIPT) | check-deps
	@echo "$(YELLOW)Recording to $(CONFIGMAP_CAST)…$(RESET)"
	@TYPE_SPEED=$(TYPE_SPEED) PAUSE_AFTER_CMD=$(PAUSE_AFTER_CMD) \
	asciinema rec --cols "$(COLS)" --rows "$(ROWS)" --overwrite -q -t "$(CONFIGMAP_TITLE)" -c "$(CONFIGMAP_SCRIPT)" $@
	@echo "$(GREEN)✓ Recorded: $(CONFIGMAP_CAST)$(RESET)"

$(CONFIGMAP_GIF): $(CONFIGMAP_CAST) | check-deps
	@echo "$(YELLOW)Exporting GIF to $(CONFIGMAP_GIF)…$(RESET)"
	@agg --cols "$(COLS)" --rows "$(ROWS)" "$(CONFIGMAP_CAST)" "$(CONFIGMAP_GIF)"
	@echo "$(GREEN)✓ GIF created: $(CONFIGMAP_GIF)$(RESET)"

$(CONFIGMAP_MP4): $(CONFIGMAP_GIF) | check-deps
	@echo "$(YELLOW)Exporting MP4 to $(CONFIGMAP_MP4)…$(RESET)"
	@ffmpeg -y -i "$(CONFIGMAP_GIF)" -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -movflags +faststart -pix_fmt yuv420p "$(CONFIGMAP_MP4)" >/dev/null 2>&1
	@echo "$(GREEN)✓ MP4 created: $(CONFIGMAP_MP4)$(RESET)"

$(WEBSERVER_CAST): $(WEBSERVER_SCRIPT) | check-deps
	@echo "$(YELLOW)Recording to $(WEBSERVER_CAST)…$(RESET)"
	@TYPE_SPEED=$(TYPE_SPEED) PAUSE_AFTER_CMD=$(PAUSE_AFTER_CMD) \
	asciinema rec --cols "$(COLS)" --rows "$(ROWS)" --overwrite -q -t "$(WEBSERVER_TITLE)" -c "$(WEBSERVER_SCRIPT)" $@
	@echo "$(GREEN)✓ Recorded: $(WEBSERVER_CAST)$(RESET)"

$(WEBSERVER_GIF): $(WEBSERVER_CAST) | check-deps
	@echo "$(YELLOW)Exporting GIF to $(WEBSERVER_GIF)…$(RESET)"
	@agg --cols "$(COLS)" --rows "$(ROWS)" "$(WEBSERVER_CAST)" "$(WEBSERVER_GIF)"
	@echo "$(GREEN)✓ GIF created: $(WEBSERVER_GIF)$(RESET)"

$(WEBSERVER_MP4): $(WEBSERVER_GIF) | check-deps
	@echo "$(YELLOW)Exporting MP4 to $(WEBSERVER_MP4)…$(RESET)"
	@ffmpeg -y -i "$(WEBSERVER_GIF)" -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -movflags +faststart -pix_fmt yuv420p "$(WEBSERVER_MP4)" >/dev/null 2>&1
	@echo "$(GREEN)✓ MP4 created: $(WEBSERVER_MP4)$(RESET)"

$(FLASKREDIS_CAST): $(FLASKREDIS_SCRIPT) | check-deps
	@echo "$(YELLOW)Recording to $(FLASKREDIS_CAST)…$(RESET)"
	@TYPE_SPEED=$(TYPE_SPEED) PAUSE_AFTER_CMD=$(PAUSE_AFTER_CMD) \
	asciinema rec --cols "$(COLS)" --rows "$(ROWS)" --overwrite -q -t "$(FLASKREDIS_TITLE)" -c "$(FLASKREDIS_SCRIPT)" $@
	@echo "$(GREEN)✓ Recorded: $(FLASKREDIS_CAST)$(RESET)"

$(FLASKREDIS_GIF): $(FLASKREDIS_CAST) | check-deps
	@echo "$(YELLOW)Exporting GIF to $(FLASKREDIS_GIF)…$(RESET)"
	@agg --cols "$(COLS)" --rows "$(ROWS)" "$(FLASKREDIS_CAST)" "$(FLASKREDIS_GIF)"
	@echo "$(GREEN)✓ GIF created: $(FLASKREDIS_GIF)$(RESET)"

$(FLASKREDIS_MP4): $(FLASKREDIS_GIF) | check-deps
	@echo "$(YELLOW)Exporting MP4 to $(FLASKREDIS_MP4)…$(RESET)"
	@ffmpeg -y -i "$(FLASKREDIS_GIF)" -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -movflags +faststart -pix_fmt yuv420p "$(FLASKREDIS_MP4)" >/dev/null 2>&1
	@echo "$(GREEN)✓ MP4 created: $(FLASKREDIS_MP4)$(RESET)"

$(NETWORKPOLICY_CAST): $(NETWORKPOLICY_SCRIPT) | check-deps
	@echo "$(YELLOW)Recording to $(NETWORKPOLICY_CAST)…$(RESET)"
	@TYPE_SPEED=$(TYPE_SPEED) PAUSE_AFTER_CMD=$(PAUSE_AFTER_CMD) \
	asciinema rec --cols "$(COLS)" --rows "$(ROWS)" --overwrite -q -t "$(NETWORKPOLICY_TITLE)" -c "$(NETWORKPOLICY_SCRIPT)" $@
	@echo "$(GREEN)✓ Recorded: $(NETWORKPOLICY_CAST)$(RESET)"

$(NETWORKPOLICY_GIF): $(NETWORKPOLICY_CAST) | check-deps
	@echo "$(YELLOW)Exporting GIF to $(NETWORKPOLICY_GIF)…$(RESET)"
	@agg --cols "$(COLS)" --rows "$(ROWS)" "$(NETWORKPOLICY_CAST)" "$(NETWORKPOLICY_GIF)"
	@echo "$(GREEN)✓ GIF created: $(NETWORKPOLICY_GIF)$(RESET)"

$(NETWORKPOLICY_MP4): $(NETWORKPOLICY_GIF) | check-deps
	@echo "$(YELLOW)Exporting MP4 to $(NETWORKPOLICY_MP4)…$(RESET)"
	@ffmpeg -y -i "$(NETWORKPOLICY_GIF)" -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -movflags +faststart -pix_fmt yuv420p "$(NETWORKPOLICY_MP4)" >/dev/null 2>&1
	@echo "$(GREEN)✓ MP4 created: $(NETWORKPOLICY_MP4)$(RESET)"

# Front-door targets, matching your original names
record:  $(HELLOWORLD_CAST)
gif:    $(HELLOWORLD_GIF)
mp4:    $(HELLOWORLD_MP4)
configmap-record: $(CONFIGMAP_CAST)
configmap-gif:    $(CONFIGMAP_GIF)
configmap-mp4:    $(CONFIGMAP_MP4)
web-server-record: $(WEBSERVER_CAST)
web-server-gif:    $(WEBSERVER_GIF)
web-server-mp4:    $(WEBSERVER_MP4)
flask-redis-record: $(FLASKREDIS_CAST)
flask-redis-gif:    $(FLASKREDIS_GIF)
flask-redis-mp4:    $(FLASKREDIS_MP4)
network-policy-record: $(NETWORKPOLICY_CAST)
network-policy-gif:    $(NETWORKPOLICY_GIF)
network-policy-mp4:    $(NETWORKPOLICY_MP4)

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
	  echo "  ffmpeg    : https://ffmpeg.org/download.html"; \
	  exit 1; \
	else \
	  echo "$(GREEN)All dependencies available: $(DEPS)$(RESET)"; \
	fi

# -----------------------------
# Utilities
# -----------------------------
clean:
	@rm -f "$(HELLOWORLD_CAST)" "$(HELLOWORLD_GIF)" "$(HELLOWORLD_MP4)" "$(CONFIGMAP_CAST)" "$(CONFIGMAP_GIF)" "$(CONFIGMAP_MP4)" "$(WEBSERVER_CAST)" "$(WEBSERVER_GIF)" "$(WEBSERVER_MP4)" "$(FLASKREDIS_CAST)" "$(FLASKREDIS_GIF)" "$(FLASKREDIS_MP4)" "$(NETWORKPOLICY_CAST)" "$(NETWORKPOLICY_GIF)" "$(NETWORKPOLICY_MP4)"
	@echo "$(GREEN)Cleaned$(RESET)"

help:
	@echo "Targets: record | gif | mp4 | configmap-record | configmap-gif | configmap-mp4 | web-server-record | web-server-gif | web-server-mp4 | flask-redis-record | flask-redis-gif | flask-redis-mp4 | network-policy-record | network-policy-gif | network-policy-mp4 | check-deps | clean | all"
	@echo "Vars: TYPE_SPEED PAUSE_AFTER_CMD HELLOWORLD_* CONFIGMAP_* WEBSERVER_* FLASKREDIS_* NETWORKPOLICY_* COLS ROWS"
