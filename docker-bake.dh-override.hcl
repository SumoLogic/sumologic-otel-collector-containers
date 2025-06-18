#################################################################################
# Variables
#################################################################################

variable "REPO" {
  type = string
  default = "docker.io/sumologic/sumologic-otel-collector-ci-builds"
}

#################################################################################
# Base targets & overrides
#################################################################################

target "_common" {
  output = [
    {
      type = "image"
      name = "${REPO}"
      name-canonical = true
      push = true
      push-by-digest = true
    }
  ]
  args = {
    foo = "${BAKE_LOCAL_PLATFORM}"
  }
}
