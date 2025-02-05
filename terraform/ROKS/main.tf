# terraform init > validate > plan > apply

# Specify the Terraform provider for IBM Cloud
terraform {
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "~> 1.57.0" # Update this to the latest version if needed
    }
  }
}

provider "ibm" {
  region = "ca-tor"
  ibmcloud_api_key = "<api_key>"
}

# Create a Cloud Object Storage instance
resource "ibm_resource_instance" "cos_instance" {
  name              = "lee-test99-openshift-backup-cos"
  service           = "cloud-object-storage"
  plan              = "standard"
  location          = "global"
  resource_group_id = "29843993547a4f1986a2d8caf5a612b4" # lee-test resource ID https://cloud.ibm.com/account/resource-groups
  tags              = ["openshift", "backup"]
}

# Create a bucket for storing backups
resource "ibm_cos_bucket" "backup_bucket" {
  bucket_name          = "lee-test99-openshift-registry-backup"
  resource_instance_id = ibm_resource_instance.cos_instance.id
  storage_class        = "standard"
  region_location      = "ca-tor"
}

# Output the Cloud Resource Name (CRN)
output "cos_instance_crn" {
  value = ibm_resource_instance.cos_instance.crn
}

output "cos_bucket_name" {
  value = ibm_cos_bucket.backup_bucket.bucket_name
}

# Define the resource group where the cluster will be created
data "ibm_resource_group" "resource_group" {
  name = "lee_test" # Replace with your resource group name
}

# Define the ROKS cluster
resource "ibm_container_vpc_cluster" "roks_cluster" {
  name               = "performance-roks-cluster"
  vpc_id             = "r038-850e2aaa-b83c-4bcb-bb81-a3c7ea900463" # Replace with your VPC ID https://cloud.ibm.com/infrastructure/network/vpcs
  kube_version       = "4.16_openshift" # Replace with your desired OpenShift version
  entitlement        = "ocp_entitled" 
  cos_instance_crn   = ibm_resource_instance.cos_instance.crn
  flavor             = "bx2.4x16"
 
  # https://cloud.ibm.com/infrastructure/network/subnets
  zones {
      subnet_id = "02q7-bcb265a3-c7e3-480b-9be2-dd52535cecc1" 
      name      = "ca-tor-1"
  }

   zones {
      subnet_id = "02r7-83dfd2b4-bf3d-4aeb-ae82-4871831ed17e" 
      name      = "ca-tor-2"
  }

   zones {
      subnet_id = "02s7-304031f2-7b48-4356-94eb-2f9c813f53b1"
      name      = "ca-tor-3"
  }

  disable_public_service_endpoint = true
}

# Define a worker pool
resource "ibm_container_worker_pool" "worker_pool" {
  cluster        = ibm_container_vpc_cluster.roks_cluster.id
  machine_type   = "bx2.4x16" # Adjust based on your requirements
  worker_pool_name = "lee-worker-pool"
  size_per_zone  = 1
}

output "cluster_id" {
  value = ibm_container_vpc_cluster.roks_cluster.id
}

output "worker_pool_id" {
  value = ibm_container_worker_pool.worker_pool.id
}
