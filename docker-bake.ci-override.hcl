#################################################################################
# Base targets & overrides
#################################################################################

# https://github.com/docker/metadata-action#bake-definition
target "docker-metadata-action" {
  attest = [
    {
      type = "provenance",
      disabled = true,
    },
    {
      type = "sbom",
      disabled = true,
    },
  ]
}

target "_common" {
  inherits = ["docker-metadata-action"]
}
