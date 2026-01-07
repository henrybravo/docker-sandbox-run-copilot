# Makefile for Docker Sandbox Template for GitHub Copilot CLI
.PHONY: build run test push clean help

# Default image name
IMAGE_NAME ?= ghcr.io/henrybravo/docker-sandbox-run-copilot
VERSION ?= latest

# Build the Docker image
build:
	@echo "Building Docker image..."
	docker build -t $(IMAGE_NAME):$(VERSION) .

# Build for multiple platforms
build-multi:
	@echo "Building multi-platform Docker image..."
	docker buildx build --platform linux/amd64,linux/arm64 -t $(IMAGE_NAME):$(VERSION) .

# Run interactively with current directory mounted
run:
	@echo "Running Copilot CLI sandbox..."
	docker run -it --rm \
		-v $(PWD):/workspace \
		-e GITHUB_TOKEN=$(GITHUB_TOKEN) \
		-e GIT_USER_NAME="$(shell git config user.name)" \
		-e GIT_USER_EMAIL="$(shell git config user.email)" \
		$(IMAGE_NAME):$(VERSION)

# Run with bash shell
shell:
	@echo "Starting bash shell in sandbox..."
	docker run -it --rm \
		-v $(PWD):/workspace \
		-e GITHUB_TOKEN=$(GITHUB_TOKEN) \
		$(IMAGE_NAME):$(VERSION) bash

# Run tests
test:
	@echo "Running tests..."
	docker build -t $(IMAGE_NAME):test .
	docker run --rm $(IMAGE_NAME):test bash -c '\
		echo "=== Testing Copilot Sandbox ===" && \
		echo "Node: $$(node --version)" && \
		echo "npm: $$(npm --version)" && \
		echo "Copilot CLI: $$(which copilot)" && \
		echo "GitHub CLI: $$(gh --version | head -1)" && \
		echo "Git: $$(git --version)" && \
		echo "Python: $$(python3 --version)" && \
		echo "Go: $$(go version)" && \
		echo "Docker CLI: $$(docker --version)" && \
		echo "=== All tests passed ===" \
	'

# Push to registry
push:
	@echo "Pushing to registry..."
	docker push $(IMAGE_NAME):$(VERSION)

# Push with latest tag
push-latest: build
	docker tag $(IMAGE_NAME):$(VERSION) $(IMAGE_NAME):latest
	docker push $(IMAGE_NAME):latest

# Clean up local images
clean:
	@echo "Cleaning up..."
	-docker rmi $(IMAGE_NAME):$(VERSION)
	-docker rmi $(IMAGE_NAME):test
	-docker rmi $(IMAGE_NAME):latest

# Show help
help:
	@echo "Docker Sandbox Template for GitHub Copilot CLI"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build       Build the Docker image"
	@echo "  build-multi Build for multiple platforms (amd64, arm64)"
	@echo "  run         Run Copilot CLI interactively"
	@echo "  shell       Start a bash shell in the sandbox"
	@echo "  test        Run tests to verify the image"
	@echo "  push        Push to container registry"
	@echo "  push-latest Tag and push as latest"
	@echo "  clean       Remove local images"
	@echo "  help        Show this help message"
	@echo ""
	@echo "Environment variables:"
	@echo "  IMAGE_NAME  Container image name (default: $(IMAGE_NAME))"
	@echo "  VERSION     Image version tag (default: $(VERSION))"
	@echo "  GITHUB_TOKEN  GitHub token for Copilot CLI authentication"
