# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

locals {
  config_vars                        = yamldecode(file(var.config_file_path))
  config_bigquery                    = local.config_vars.bigquery
  feature_store_project_id           = local.config_vars.bigquery.dataset.feature_store.project_id
  purchase_propensity_project_id     = local.config_vars.bigquery.dataset.purchase_propensity.project_id
  audience_segmentation_project_id   = local.config_vars.bigquery.dataset.audience_segmentation.project_id
  customer_lifetime_value_project_id = local.config_vars.bigquery.dataset.customer_lifetime_value.project_id
  project_id                         = local.feature_store_project_id
  source_root_dir                    = "../.."
  sql_dir                            = "${local.source_root_dir}/sql"
  builder_repository_id              = "marketing-data-engine-base-repo"
  cloud_build_service_account_name   = "cloud-builder-runner"
  cloud_build_service_account_email  = "${local.cloud_build_service_account_name}@${local.project_id}.iam.gserviceaccount.com"
}

module "project_services" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "14.1.0"

  disable_dependent_services  = true
  disable_services_on_destroy = false

  project_id = local.feature_store_project_id

  activate_apis = [
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "aiplatform.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "bigquery.googleapis.com",
    "bigquerystorage.googleapis.com",
    "storage.googleapis.com",
    "sourcerepo.googleapis.com",
    "storage-api.googleapis.com",
  ]
}

resource "google_artifact_registry_repository" "cloud_builder_repository" {
  project       = local.feature_store_project_id
  location      = var.region
  repository_id = local.builder_repository_id
  description   = "Custom builder images for Marketing Data Engine"
  format        = "DOCKER"
  depends_on = [
    module.project_services.wait
  ]
}

module "cloud_build_service_account" {
  source     = "terraform-google-modules/service-accounts/google"
  version    = "~> 3.0"
  project_id = local.project_id
  prefix     = "mde"
  names      = [local.cloud_build_service_account_name]
  project_roles = [
    "${local.project_id}=>roles/artifactregistry.writer",
    "${local.project_id}=>roles/cloudbuild.builds.editor",
    "${local.project_id}=>roles/iap.tunnelResourceAccessor",
    "${local.project_id}=>roles/compute.osLogin",
    "${local.project_id}=>roles/bigquery.jobUser",
    "${local.project_id}=>roles/bigquery.dataEditor",
    "${local.project_id}=>roles/storage.objectViewer",
    "${local.project_id}=>roles/storage.objectCreator",
    "${local.project_id}=>roles/aiplatform.user",
    "${local.project_id}=>roles/pubsub.publisher",
  ]
  display_name = "cloud build runner"
  description  = "Marketing Data Engine Cloud Build Account"
}
