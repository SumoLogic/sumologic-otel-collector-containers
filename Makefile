#################################################################################
# General variables
#################################################################################

ACTIONLINT ?= actionlint
ACTIONLINT_PKG ?= github.com/rhysd/actionlint/cmd/actionlint
ACTIONLINT_VERSION ?= latest

AWS ?= aws

CRANE ?= crane
CRANE_PKG ?= github.com/google/go-containerregistry/cmd/crane
CRANE_VERSION ?= 0.20.6

#################################################################################
# Amazon ECR variables
#################################################################################

ECR_CI_ID ?= 663229565520
ECR_CI_REGION ?= us-east-1
ECR_CI_REGISTRY ?= $(ECR_CI_ID).dkr.ecr.$(ECR_CI_REGION).amazonaws.com
ECR_CI_REPO ?= sumologic/sumologic-otel-collector-ci-builds
ECR_CI_URI ?= $(ECR_CI_REGISTRY)/$(ECR_CI_REPO)

ECR_RC_ID ?= 663229565520
ECR_RC_REGION ?= us-east-1
ECR_RC_REGISTRY ?= $(ECR_RC_ID).dkr.ecr.$(ECR_RC_REGION).amazonaws.com
ECR_RC_REPO ?= sumologic/sumologic-otel-collector-release-candidates
ECR_RC_URI ?= $(ECR_RC_REGISTRY)/$(ECR_RC_REPO)

ECR_TEST_ID ?= 663229565520
ECR_TEST_REGION ?= us-east-1
ECR_TEST_REGISTRY ?= $(ECR_TEST_ID).dkr.ecr.$(ECR_TEST_REGION).amazonaws.com
ECR_TEST_REPO ?= sumologic/sumologic-otel-collector-testing-a
ECR_TEST_URI ?= $(ECR_TEST_REGISTRY)/$(ECR_TEST_REPO)

ECR_STABLE_REGION ?= us-east-1
ECR_STABLE_REGISTRY ?= public.ecr.aws
ECR_STABLE_REPO ?= sumologic/sumologic-otel-collector
ECR_STABLE_URI ?= $(ECR_STABLE_REGISTRY)/$(ECR_STABLE_REPO)

#################################################################################
# Docker Hub variables
#################################################################################

DH_RC_REGISTRY ?= docker.io
DH_RC_REPO ?= sumologic/sumologic-otel-collector-release-candidates
DH_RC_URI ?= $(DH_RC_REGISTRY)/$(DH_RC_REPO)

DH_STABLE_REGISTRY ?= docker.io
DH_STABLE_REPO ?= sumologic/sumologic-otel-collector
DH_STABLE_URI ?= $(DH_STABLE_REGISTRY)/$(DH_STABLE_REPO)

#################################################################################
# Default target
#################################################################################

.PHONY: all
all: lint

#################################################################################
# System CLI tool targets
#################################################################################

.PHONY: install-actionlint
install-actionlint:
	@which $(ACTIONLINT) || go install $(ACTIONLINT_PKG)@$(ACTIONLINT_VERSION)

.PHONY: install-crane
install-crane:
	@which $(CRANE) || go install $(CRANE_PKG)@v$(CRANE_VERSION)

#################################################################################
# Lint & testing targets
#################################################################################

.PHONY: lint
lint: actionlint

.PHONY: actionlint
actionlint: install-actionlint
actionlint:
	@echo "Running actionlint..."
	@$(ACTIONLINT) -color

#################################################################################
# ECR helper targets
#################################################################################

.PHONY: _login-ecr
_login-ecr: install-crane
_login-ecr:
	@$(AWS) $(ECR_SUBCMD) get-login-password --region $(AWS_REGION) \
		| $(CRANE) auth login -u AWS --password-stdin $(REGISTRY)

#################################################################################
# ECR targets
#################################################################################

.PHONY: login-ecr-ci
login-ecr-ci:
	@$(MAKE) _login-ecr \
		ECR_SUBCMD="ecr" \
		AWS_REGION="$(ECR_CI_REGION)" \
		REGISTRY="$(ECR_CI_REGISTRY)"

.PHONY: login-ecr-rc
login-ecr-rc:
	@$(MAKE) _login-ecr \
		ECR_SUBCMD="ecr" \
		AWS_REGION="$(ECR_RC_REGION)" \
		REGISTRY="$(ECR_RC_REGISTRY)"

.PHONY: login-ecr-test
login-ecr-rc:
	@$(MAKE) _login-ecr \
		ECR_SUBCMD="ecr" \
		AWS_REGION="$(ECR_TEST_REGION)" \
		REGISTRY="$(ECR_TEST_REGISTRY)"

.PHONY: login-ecr-stable
login-ecr-stable:
	@$(MAKE) _login-ecr \
		ECR_SUBCMD="ecr-public" \
		AWS_REGION="$(ECR_STABLE_REGION)" \
		REGISTRY="$(ECR_STABLE_REGISTRY)"

#################################################################################
# Crane helper targets
#
# NOTE: These are helper targets and should not be called directly.
#################################################################################

## _crane-copy
#
# Description: Copies a remote container image from one registry/repository to
# another.
#
# Required Variables:
#   SRC_IMAGE
#     The source image with the format: registry/repository:tag.
#
#   DST_IMAGE
#     The destination image with the format: registry/repository:tag.
.PHONY: _crane-copy
_crane-copy: install-crane
_crane-copy:
ifeq ($(SRC_IMAGE),)
	@$(error SRC_IMAGE must be set for crane copy)
endif
ifeq ($(DST_IMAGE),)
	@$(error DST_IMAGE must be set for crane copy)
endif
	@echo "Copying image '$(SRC_IMAGE)' to '$(DST_IMAGE)'"
	@$(CRANE) copy "$(SRC_IMAGE)" "$(DST_IMAGE)"

## _crane-tag
#
# Description: Tags a remote container image with a new tag.
#
# Required Variables:
#   SRC_IMAGE
#     Must be set to the source image name including the registry, repository,
#     and tag.
#
#   TAG_NAME
#     Must be set to the new tag name to apply to the source image. The tag name
#     should not include the registry or repository, only the tag itself.
.PHONY: _crane-tag
_crane-tag: install-crane
_crane-tag:
ifeq ($(SRC_IMAGE),)
	@$(error SRC_IMAGE must be set for crane tag)
endif
ifeq ($(TAG_NAME),)
	@$(error TAG_NAME must be set for crane tag)
endif
	@echo "Tagging image '$(SRC_IMAGE)' with tag '$(TAG_NAME)'"
	@$(CRANE) tag "$(SRC_IMAGE)" "$(TAG_NAME)"

## _create-tag
#
# Description: Creates a tag for a container image / index in the given
# repository.
#
# Required Variables:
#   REPO
#     Repository where the image to be tagged is located.
#
#   RUN_ID
#     GitHub Actions Run ID of the workflow that built the image.
#
#   TAG_NAME
#     Name to tag the image with.
#
# Optional Variables:
#   TAG_SUFFIX
#     Suffix to be appended to the source tag name.
.PHONY: _create-tag
_create-tag:
ifeq ($(REPO),)
	@$(error REPO must be set for tagging)
endif
ifeq ($(TAG_NAME),)
	@$(error TAG_NAME must be set for tagging)
endif
ifeq ($(RUN_ID),)
	@$(error RUN_ID must be set for tagging. It should be equal to the GitHub \
		Actions Run ID of the workflow in the \
		sumologic-otel-collector-containers repository that built the container \
		image to be promoted)
endif
	@$(MAKE) _crane-tag \
		SRC_IMAGE="$(REPO):$(RUN_ID)$(TAG_SUFFIX)" \
		TAG_NAME="$(TAG_NAME)$(TAG_SUFFIX)"

## _create-tags
#
# Description: Creates multiple tags for a container image / index in the given
# repository.
#
# Required Variables:
#   REPO
#     Repository where the image to be tagged is located.
#
#   RUN_ID
#     GitHub Actions Run ID of the workflow that built the image.
#
# Optional Variables:
#   TAG_SUFFIX
#     Suffix to be appended to the source & destination tag names. Defaults to
#     empty.
.PHONY: _create-tags
_create-tags:
ifeq ($(GITHUB_SHA),)
	@$(error GITHUB_SHA must be set for tagging)
endif
ifeq ($(OTC_GIT_REF),)
	@$(error OTC_GIT_REF must be set for tagging)
endif
ifeq ($(OTC_VERSION),)
	@$(error OTC_VERSION must be set for tagging)
endif
	@$(MAKE) _create-tag TAG_NAME="$(GITHUB_SHA)"
	@$(MAKE) _create-tag TAG_NAME="$(OTC_GIT_REF)"
	@$(MAKE) _create-tag TAG_NAME="$(OTC_VERSION)"
	@$(MAKE) _create-tag TAG_NAME="latest"

## _promote-container-image
#
# Description: Promotes a container image from one registry/repository to
# another.
#
# Required Variables:
#   SRC_REGISTRY
#     Registry where the source repository is located.
#
#   SRC_REPO
#     Repository where the source image is located.
#
#   DST_REGISTRY
#     Registry where the destination repository is located.
#
#   DST_REPO
#     Repository where the destination image will be copied to.
#
#   RUN_ID
#     GitHub Actions Run ID of the workflow that built the source image.
#
# Optional Variables:
#   TAG_SUFFIX
#     Suffix to be appended to the tag name. Defaults to empty.
#
#   TAG_NAME
#     Name of the image tag to promote. If not set, defaults to RUN_ID with
#     TAG_SUFFIX.
.PHONY: _promote-container-image
_promote-container-image: TAG_NAME = $(RUN_ID)$(TAG_SUFFIX)
_promote-container-image:
ifeq ($(SRC_REGISTRY),)
	@$(error SRC_REGISTRY must be set for container image promotion)
endif
ifeq ($(SRC_REPO),)
	@$(error SRC_REPO must be set for container image promotion)
endif
ifeq ($(DST_REGISTRY),)
	@$(error DST_REGISTRY must be set for container image promotion)
endif
ifeq ($(DST_REPO),)
	@$(error DST_REPO must be set for container image promotion)
endif
ifeq ($(RUN_ID),)
	@$(error RUN_ID must be set for container image promotion. It should be \
		equal to the GitHub Actions Run ID of the workflow in the \
		sumologic-otel-collector-containers repository that built the container \
		image to be promoted)
endif
	@$(MAKE) _crane-copy \
		SRC_IMAGE="$(SRC_REGISTRY)/$(SRC_REPO):$(TAG_NAME)" \
		DST_IMAGE="$(DST_REGISTRY)/$(DST_REPO):$(TAG_NAME)"

## _promote-image-ci-to-rc
#
# Description: Promotes an image from ci-builds to release-candidates.
#
# Required Variables:
#   SRC_REGISTRY
#     Registry where the source repository is located.
#
#   CONTAINER_REPO_CI
#     Repository where the source image is located.
#
#   DST_REGISTRY
#     Registry where the destination repo is located.
#
#   CONTAINER_REPO_RC
#     Repository where the destination image will be copied to.
.PHONY: _promote-image-ci-to-rc
_promote-image-ci-to-rc:
	@$(MAKE) _promote-container-image \
		SRC_REGISTRY="$(SRC_REGISTRY)" \
		SRC_REPO="$(CONTAINER_REPO_CI)" \
		DST_REGISTRY="$(DST_REGISTRY)" \
		DST_REPO="$(CONTAINER_REPO_RC)"

## _promote-image-rc-to-stable
# Description: Promotes an image from release-candidates to stable.
#
# Required Variables:
#   SRC_REGISTRY
#     Registry where the source repository is located.
#
#   CONTAINER_REPO_RC
#     Repository where the source image is located.
#
#   DST_REGISTRY
#     Registry where the destination repository is located.
#
#   CONTAINER_REPO_STABLE
#     Repository where the destination image will be copied to.
.PHONY: _promote-image-rc-to-stable
_promote-image-rc-to-stable:
	@$(MAKE) _promote-container-image \
		SRC_REGISTRY="$(SRC_REGISTRY)" \
		SRC_REPO="$(CONTAINER_REPO_RC)" \
		DST_REGISTRY="$(DST_REGISTRY)" \
		DST_REPO="$(CONTAINER_REPO_STABLE)"

## _promote-image-ci-to-test
#
# Description: Promotes an image from ci-builds to testing-a.
#
# Required Variables:
#   SRC_REGISTRY
#     Registry where the source repository is located.
#
#   CONTAINER_REPO_CI
#     Repository where the source image is located.
#
#   DST_REGISTRY
#     Registry where the destination repo is located.
#
#   CONTAINER_REPO_RC
#     Repository where the destination image will be copied to.
.PHONY: _promote-image-ci-to-test
_promote-image-ci-to-test:
	@$(MAKE) _promote-container-image \
		SRC_REGISTRY="$(SRC_REGISTRY)" \
		SRC_REPO="$(CONTAINER_REPO_CI)" \
		DST_REGISTRY="$(DST_REGISTRY)" \
		DST_REPO="$(CONTAINER_REPO_TEST)"

#################################################################################
# Image removal helper targets
#
# NOTE: These targets are helpers and should not be called directly.
#################################################################################

.PHONY: _remove-image-rc
_remove-image-rc:
	@echo TODO: implement me

.PHONY: _remove-image-stable
_remove-image-stable:
	@echo TODO: implement me

#################################################################################
# ECR promotion targets
#################################################################################

# Promotes an image from ci-builds to release-candidates.
.PHONY: promote-ecr-image-ci-to-rc
promote-ecr-image-ci-to-rc:
	@$(MAKE) _promote-image-ci-to-rc \
		SRC_REGISTRY="$(ECR_CI_REGISTRY)" \
		DST_REGISTRY="$(ECR_RC_REGISTRY)" \
		CONTAINER_REPO_CI="$(ECR_CI_REPO)" \
		CONTAINER_REPO_RC="$(ECR_RC_REPO)"

# Promotes an image from release-candidates to stable.
.PHONY: promote-ecr-image-rc-to-stable
promote-ecr-image-rc-to-stable:
	@$(MAKE) _promote-image-rc-to-stable \
		SRC_REGISTRY="$(ECR_RC_REGISTRY)" \
		DST_REGISTRY="$(ECR_STABLE_REGISTRY)" \
		CONTAINER_REPO_RC="$(ECR_RC_REPO)" \
		CONTAINER_REPO_STABLE="$(ECR_STABLE_REPO)"

# Promotes an image from ci-builds to testing-a.
.PHONY: promote-ecr-image-ci-to-test
promote-ecr-image-ci-to-test:
	@$(MAKE) _promote-image-ci-to-test \
		SRC_REGISTRY="$(ECR_CI_REGISTRY)" \
		DST_REGISTRY="$(ECR_TEST_REGISTRY)" \
		CONTAINER_REPO_CI="$(ECR_CI_REPO)" \
		CONTAINER_REPO_RC="$(ECR_TEST_REPO)"

.PHONY: create-ecr-tags-rc
create-ecr-tags-rc:
	@$(MAKE) _create-tags REPO="$(ECR_RC_URI)"

.PHONY: create-ecr-tags-stable
create-ecr-tags-stable:
	@$(MAKE) _create-tags REPO="$(ECR_STABLE_URI)"

.PHONY: create-ecr-tags-test
create-ecr-tags-test:
	@$(MAKE) _create-tags REPO="$(ECR_TEST_URI)"

#################################################################################
# Docker Hub promotion targets
#################################################################################

# Promotes an image from ci-builds to release-candidates. The CI repository is
# not used in DH so the promotion happens from the ci-builds repository in ECR
# to the release-candidates repository in DH.
.PHONY: promote-dh-image-ci-to-rc
promote-dh-image-ci-to-rc:
	@$(MAKE) _promote-image-ci-to-rc \
		SRC_REGISTRY="$(ECR_CI_REGISTRY)" \
		DST_REGISTRY="$(DH_RC_REGISTRY)" \
		CONTAINER_REPO_CI="$(ECR_CI_REPO)" \
		CONTAINER_REPO_RC="$(DH_RC_REPO)"

# Promotes an image from release-candidates to stable.
.PHONY: promote-dh-image-rc-to-stable
promote-dh-image-rc-to-stable:
	@$(MAKE) _promote-image-rc-to-stable \
		SRC_REGISTRY="$(DH_RC_REGISTRY)" \
		DST_REGISTRY="$(DH_STABLE_REGISTRY)" \
		CONTAINER_REPO_RC="$(DH_RC_REPO)" \
		CONTAINER_REPO_STABLE="$(DH_STABLE_REPO)"

.PHONY: create-dh-tags-rc
create-dh-tags-rc:
	@$(MAKE) _create-tags REPO="$(DH_RC_URI)"

.PHONY: create-dh-tags-stable
create-dh-tags-stable:
	@$(MAKE) _create-tags REPO="$(DH_STABLE_URI)"

.PHONY: create-dh-tags-test
create-dh-tags-test:
	@$(MAKE) _create-tags REPO="$(DH_TEST_URI)"

#################################################################################
# General promotion targets
#################################################################################

# Promotes all images for a build from ci-builds to release-candidates. This
# includes the main image and any additional images with suffixes like -fips,
# -ubi, and -ubi-fips.
.PHONY: promote-images-ci-to-rc
promote-images-ci-to-rc:
	@$(MAKE) promote-ecr-image-ci-to-rc
	@$(MAKE) promote-ecr-image-ci-to-rc TAG_SUFFIX="-fips"
	@$(MAKE) promote-ecr-image-ci-to-rc TAG_SUFFIX="-ubi"
	@$(MAKE) promote-ecr-image-ci-to-rc TAG_SUFFIX="-ubi-fips"
	@$(MAKE) promote-dh-image-ci-to-rc
	@$(MAKE) promote-dh-image-ci-to-rc TAG_SUFFIX="-fips"
	@$(MAKE) promote-dh-image-ci-to-rc TAG_SUFFIX="-ubi"
	@$(MAKE) promote-dh-image-ci-to-rc TAG_SUFFIX="-ubi-fips"

# Promotes all images for a build from release-candidates to stable. This
# includes the main image and any additional images with suffixes like -fips,
# -ubi, and -ubi-fips.
.PHONY: promote-images-rc-to-stable
promote-images-rc-to-stable:
	@$(MAKE) promote-ecr-image-rc-to-stable
	@$(MAKE) promote-ecr-image-rc-to-stable TAG_SUFFIX="-fips"
	@$(MAKE) promote-ecr-image-rc-to-stable TAG_SUFFIX="-ubi"
	@$(MAKE) promote-ecr-image-rc-to-stable TAG_SUFFIX="-ubi-fips"
	@$(MAKE) promote-dh-image-rc-to-stable
	@$(MAKE) promote-dh-image-rc-to-stable TAG_SUFFIX="-fips"
	@$(MAKE) promote-dh-image-rc-to-stable TAG_SUFFIX="-ubi"
	@$(MAKE) promote-dh-image-rc-to-stable TAG_SUFFIX="-ubi-fips"

# Promotes all images for a build from ci-builds to testing-a. This includes
# the main image and any additional images with suffixes like -fips, -ubi, and
# -ubi-fips.
.PHONY: promote-images-ci-to-test
promote-images-ci-to-test:
	@$(MAKE) promote-ecr-image-ci-to-test
	@$(MAKE) promote-ecr-image-ci-to-test TAG_SUFFIX="-fips"
	@$(MAKE) promote-ecr-image-ci-to-test TAG_SUFFIX="-ubi"
	@$(MAKE) promote-ecr-image-ci-to-test TAG_SUFFIX="-ubi-fips"
	@$(MAKE) promote-dh-image-ci-to-test
	@$(MAKE) promote-dh-image-ci-to-test TAG_SUFFIX="-fips"
	@$(MAKE) promote-dh-image-ci-to-test TAG_SUFFIX="-ubi"
	@$(MAKE) promote-dh-image-ci-to-test TAG_SUFFIX="-ubi-fips"

.PHONY: create-tags-rc
create-tags-rc:
	@$(MAKE) create-ecr-tags-rc
	@$(MAKE) create-ecr-tags-rc TAG_SUFFIX="-fips"
	@$(MAKE) create-ecr-tags-rc TAG_SUFFIX="-ubi"
	@$(MAKE) create-ecr-tags-rc TAG_SUFFIX="-ubi-fips"
	@$(MAKE) create-dh-tags-rc
	@$(MAKE) create-dh-tags-rc TAG_SUFFIX="-fips"
	@$(MAKE) create-dh-tags-rc TAG_SUFFIX="-ubi"
	@$(MAKE) create-dh-tags-rc TAG_SUFFIX="-ubi-fips"

.PHONY: create-tags-stable
create-tags-stable:
	@$(MAKE) create-ecr-tags-stable
	@$(MAKE) create-ecr-tags-stable TAG_SUFFIX="-fips"
	@$(MAKE) create-ecr-tags-stable TAG_SUFFIX="-ubi"
	@$(MAKE) create-ecr-tags-stable TAG_SUFFIX="-ubi-fips"
	@$(MAKE) create-dh-tags-stable
	@$(MAKE) create-dh-tags-stable TAG_SUFFIX="-fips"
	@$(MAKE) create-dh-tags-stable TAG_SUFFIX="-ubi"
	@$(MAKE) create-dh-tags-stable TAG_SUFFIX="-ubi-fips"

.PHONY: create-tags-test
create-tags-test:
	@$(MAKE) create-ecr-tags-test
	@$(MAKE) create-ecr-tags-test TAG_SUFFIX="-fips"
	@$(MAKE) create-ecr-tags-test TAG_SUFFIX="-ubi"
	@$(MAKE) create-ecr-tags-test TAG_SUFFIX="-ubi-fips"
	@$(MAKE) create-dh-tags-test
	@$(MAKE) create-dh-tags-test TAG_SUFFIX="-fips"
	@$(MAKE) create-dh-tags-test TAG_SUFFIX="-ubi"
	@$(MAKE) create-dh-tags-test TAG_SUFFIX="-ubi-fips"

#################################################################################
# Print targets
#################################################################################

# Print the supported platforms for the given image in the specified registry.
.PHONY: _print-image-platforms
_print-image-platforms:
	@echo Supported platforms for $(REGISTRY):$(TAG)
	@docker buildx imagetools inspect --raw \
		$(REGISTRY):$(TAG) | jq -f ci/jq/platforms.jq
	@echo

# Print the supported platforms for the ECR images.
.PHONY: print-ecr-image-platforms
print-ecr-image-platforms:
	@$(MAKE) _print-image-platforms REGISTRY=$(ECR_REPO_CI) TAG=latest
	@$(MAKE) _print-image-platforms REGISTRY=$(ECR_REPO_CI) TAG=latest-fips
	@$(MAKE) _print-image-platforms REGISTRY=$(ECR_REPO_CI) TAG=latest-ubi
	@$(MAKE) _print-image-platforms REGISTRY=$(ECR_REPO_CI) TAG=latest-ubi-fips
