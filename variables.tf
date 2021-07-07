variable "resource_group_name" {
    type = string
}

variable "azure_region" {
    type = string
}


variable "VMachines" {
    type = list(object({
        name = string
        role = string
        size = string
  }))
}

