# Releasing

## How to release

### Check end-to-end tests

Check if the Sumo internal e2e tests are passing.

### Determine the Workflow Run ID to release

We can begin the process of creating a release once QE has given a thumbs up for
a given package version and the [collector release steps][collector_release]
have already been performed. We can determine the Workflow Run ID to use for a
release using the following steps:

#### Find the package build number

Each package has a build number and it's included in the package version &
filename. For example, if the package version that QE validates is 0.130.1-2195
then the build number is 2195.

#### Find the collector workflow run

We can find the workflow used to build the packages by using the package build
number.

The build number corresponds directly to the GitHub Run Number for a packaging
workflow run in GitHub Actions. Unfortunately, there does not currently appear to
be a way to reference a workflow run using the run number. Instead, we can use
one of two methods to find the workflow run:

#### Option 1 - Use the `gh` cli tool to find the workflow

Run the following command (be sure to replace `BUILD_NUMBER` with the build
number of the package):

```shell
PAGER=""; BUILD_NUMBER="2195"; \
gh run list -R sumologic/sumologic-otel-collector-packaging -s success \
-w build_packages.yml -L 200 -b main --json displayTitle,number,url \
-q ".[] | select(.number == ${BUILD_NUMBER})"
```

This will output a number of fields, for example:

```json
{
  "displayTitle": "Build for Remote Workflow: 16640244460\n",
  "number": 2195,
  "url": "https://github.com/SumoLogic/sumologic-otel-collector-packaging/actions/runs/16640314426"
}
```

We need the number to the right of `Build for Remote Workflow`. This number is
the ID of the workflow run, in the collector repository, that built the binaries
used in the package.

We can now find the workflow run that was used to build the containers by
running:

```shell
PAGER=""; WORKFLOW_ID="16640244460"; \
gh run list -R sumologic/sumologic-otel-collector-containers -s success \
-w build-and-push.yml -L 200 -b main --json displayTitle,databaseId,url \
-q ".[] | select(.displayTitle == \"Build for Remote Workflow: ${WORKFLOW_ID}\n\")"
```

The number in the `databaseId` field is the ID for the workflow run that built
the containers.

The workflow run can be viewed by visiting the URL in the `url` field.

#### Option 2 - Search the GitHub website manually

Manually search for the run number on the
[Build packages workflow][build_workflow] page. Search for the build number
(e.g. 2195) until you find the corresponding workflow.

![Finding the packaging workflow run][release_0]

Once you've found the packaging workflow run, we need the number to the right of
`Build for Remote Workflow`. This number is the ID of the workflow run that built
the binaries used in the package.

![Finding the collector workflow ID][release_1]

### Trigger the release

Now that we have the Workflow Run ID we can trigger a release. There are two
methods of doing this.

#### Option 1 - Use the `gh` cli tool to trigger the release

A release can be triggered by using the following command (be sure to replace
`WORKFLOW_ID` with the Workflow Run ID from the previous step):

```shell
PAGER=""; WORKFLOW_ID="16640314265"; \
gh workflow run releases.yml \
-R sumologic/sumologic-otel-collector-containers -f workflow_id=${WORKFLOW_ID}
```

The status of running workflows can be viewed with the `gh run watch` command.
You will have to manually select the correct workflow run. The name of the run
should have a title similar to `Publish Release for Workflow: x`). Once you have
selected the correct run the screen will periodically update to show the status
of the run's jobs.

#### Option 2 - Use the GitHub website to trigger the release

Navigate to the [Publish release][releases_workflow] workflow in GitHub Actions.
Find and click the `Run workflow` button on the right-hand side of the page.
Fill in the Workflow Run ID from the previous step. If the release should be
considered to be the latest version, click the checkbox for `Latest version`.
Click the `Run workflow` button to trigger the release.

![Triggering a release][release_2]

### Publish GitHub release

The GitHub release is created as draft by the
[releases](../.github/workflows/releases.yml) GitHub Action.

After the release draft is created, go to [GitHub releases](https://github.com/SumoLogic/sumologic-otel-collector-containers/releases),
edit the release draft and fill in missing information:

- Specify versions for upstream OT core and contrib releases
- Copy and paste the Changelog entry for this release from [CHANGELOG.md][changelog]

After verifying that the release text and all links are good, publish the release.

[build_workflow]: https://github.com/SumoLogic/sumologic-otel-collector-packaging/actions/workflows/build_packages.yml?query=branch%3Amain
[changelog]: https://github.com/SumoLogic/sumologic-otel-collector/blob/main/CHANGELOG.md
[collector_release]: https://github.com/SumoLogic/sumologic-otel-collector/blob/main/docs/release.md
[release_0]: ../images/release_0.png
[release_1]: ../images/release_1.png
[release_1]: ../images/release_2.png
[releases_workflow]: https://github.com/SumoLogic/sumologic-otel-collector-containers/actions/workflows/releases.yml
