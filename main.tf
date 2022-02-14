resource "azurerm_resource_group" "new_rg" {
  name     = var.resource_group
  location = var.region
}


resource "azurerm_kubernetes_cluster" "k8s" {
  timeouts {
    read   = "60m"
    create = "60m"
    delete = "60m"
  }
  name                            = var.aks_cluster_name
  location                        = var.region
  resource_group_name             = azurerm_resource_group.new_rg.name
  kubernetes_version              = var.aks_version
  dns_prefix                      = var.dns_prefix
  local_account_disabled          = var.local_account_disabled
  sku_tier                        = var.sku_tier
  api_server_authorized_ip_ranges = var.allowed_ips_to_api
  automatic_channel_upgrade       = var.automatic_channel_upgrade


  linux_profile {
    admin_username = var.node_admin_username

    ssh_key {
      key_data = var.node_admin_ssh_pub_key
    }
  }

  addon_profile {
    azure_policy {
      enabled = var.azure_policy
    }
    http_application_routing {
      enabled = var.http_application_routing
    }
  }

  network_profile {
    network_plugin     = var.network_plugin
    network_policy     = var.network_policy
    service_cidr       = var.service_cidr
    docker_bridge_cidr = var.docker_bridge_cidr
    dns_service_ip     = var.dns_service_ip
  }

  default_node_pool {
    name                = "nodepool1"
    node_count          = var.node_count
    availability_zones  = var.node_availability_zones
    vm_size             = var.cluster_node_vm_size
    enable_auto_scaling = var.cluster_auto_scaling_enabled
    min_count           = var.cluster_auto_scaling_min_nodes
    max_count           = var.cluster_auto_scaling_max_nodes
    os_disk_size_gb     = var.cluster_node_vm_disk_size
    vnet_subnet_id      = data.azurerm_subnet.k8s_subnet.id
    max_pods            = var.max_pods
  }

  identity {
    type = "SystemAssigned"
  }

  maintenance_window {
    allowed {
      day   = var.maintenance_window_day
      hours = var.maintenance_window_time_frame
    }
  }

  role_based_access_control {
    enabled = var.k8s_rbac_enabled
    dynamic "azure_active_directory" {
      for_each = var.azure_ad_rbac_enabled ? [1] : []
      content {
        managed                = true
        admin_group_object_ids = var.aad_admin_group
      }
    }
  }
  tags = {
    Environment = var.environment_tag
  }
}

resource "azurerm_user_assigned_identity" "managed_identity" {
  count               = length(var.managed_identities)
  resource_group_name = azurerm_kubernetes_cluster.k8s.node_resource_group
  location            = var.region
  name                = element(var.managed_identities, count.index)
}
