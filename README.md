# Universal Terraform Provisioner Image

Docker image for terraform provisioning that supports provider plugin caching and declarative binary installation via mise.

# Contents

<details>
<summary>Table of Contents</summary>
<!---toc start-->

* [Universal Terraform Provisioner Image](#universal-terraform-provisioner-image)
* [Contents](#contents)
* [Benefits](#benefits)
* [How](#how)
* [Usage](#usage)
  * [Manual Providers](#manual-providers)
* [Local Testing](#local-testing)
* [Troubleshooting](#troubleshooting)
  * [TF_LOG](#tf_log)
  * [DEBUG_ON](#debug_on)
  * [Missing Terraform Providers](#missing-terraform-providers)

<!---toc end-->
</details>

# Benefits

This project pipeline caches terraform provider plugin versions into the docker image. This will accomplish 2 things:

1. Reduce provisioner pipeline run time - Eliminates the near constant re-downloading of these external binary packages from the terraform registry.
2. Reduce external dependencies - The terraform registry has gone down at least 1 time in the last few years. This causes an unresolvable provisioning outages.

# How
  - Pre-caching providers for multiple terraform provisioner pipelines via declarative yaml in `config/provisioners.yml`
  - Declarative terraform and other binaries versions via [mise](https://mise.jdx.dev) and `mise.toml`

# Usage

Clone this repo into your organization then make updates as needed.

1. Update the `config/provisioners.yml` file with all of your downstream terraform provisioning projects, their branches, and target folders that will be processed by the pipeline.
2. Update the `mise.toml` file to include the terraform and other binary versions you wish to have included.

> **NOTE** The order of versions in `mise.toml` matter. The first one in the list will be used by default. [Configuration of mise](https://mise.jdx.dev/configuration.html)

3. Build then use your image. You can force binary version changes declaratively in your downstream pipelines by including local versions of `mise.toml` file with the versions you need to use.

## Manual Providers

Edit the local `config/provisioners.yml` file to add a local path with a terraform `version.tf` file. Examples are provided in this project (that can be removed)

# Local Testing

To see how this will work locally you can use the task command. 

`task providers`

This should produce a local `tempproviders` folder with all of the plugins for your downstream terraform provisioners.

Additionally, helper tasks for building and shelling into the image are included.

```bash
task docker:build docker:shell
```

# Troubleshooting

There are a few tools you can use to trace out where issues might be happening.

## TF_LOG

Set this to DEBUG when you manually run a provisioner pipeline to get more output.

## DEBUG_ON

Set this to TRUE to allow for the temp directory that remote git repos are cloned into to not be deleted after processing has completed.

## Missing Terraform Providers

If you run into missing providers in your downstream terraform provisioners when using this image you may need to simply build another version of this image to pull in any changes done to the provisioner itself (upgrades to terraform providers specifically).
