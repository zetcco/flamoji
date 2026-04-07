EXECUTABLE_NAME = flamoji
JSON_URL = https://raw.githubusercontent.com/muan/emojilib/main/dist/emoji-en-US.json
JSON_DEST = Sources/emojis.json
INSTALL_DIR = $(HOME)/.flamoji

.PHONY: all fetch build install start stop clean

all: fetch build

fetch:
	@if [ ! -f $(JSON_DEST) ]; then \
		echo "🔥 Fetching emoji dictionary..."; \
		curl -sL $(JSON_URL) -o $(JSON_DEST); \
	fi

build: fetch
	@echo "🔥 Compiling $(EXECUTABLE_NAME)..."
	@swift build -c release

install: build
	@echo "🥷 Stashing binary in $(INSTALL_DIR)..."
	@mkdir -p $(INSTALL_DIR)
	@cp .build/release/$(EXECUTABLE_NAME) $(INSTALL_DIR)/
	@cp -R .build/release/$(EXECUTABLE_NAME)_$(EXECUTABLE_NAME).bundle $(INSTALL_DIR)/ 2>/dev/null || true
	@echo "✅ Installed! Binary is permanently located at $(INSTALL_DIR)/$(EXECUTABLE_NAME)"

start:
	@echo "🔥 Starting Flamoji in the background..."
	@killall $(EXECUTABLE_NAME) 2>/dev/null || true
	@nohup $(INSTALL_DIR)/$(EXECUTABLE_NAME) > /dev/null 2>&1 &
	@echo "✅ Running! You can safely close this terminal."

stop:
	@echo "🛑 Stopping Flamoji..."
	@killall $(EXECUTABLE_NAME) 2>/dev/null || true

clean: stop
	@echo "🧹 Cleaning up build artifacts..."
	@rm -rf .build
	@rm -rf $(INSTALL_DIR)
	@rm -f $(JSON_DEST)
