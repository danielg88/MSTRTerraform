resource_group_name = "TerraformMSTRDeployment"

azure_region = "westeurope"

VMachines = [
    {
      name = "intelligence"
      role = "intelligence"
      size = "Standard_D2as_v4"
    },
    {
      name = "webserver"
      role = "webserver"
      size = "Standard_D1_v2"
    },
    {
      name = "webserver2"
      role = "webserver"
      size = "Standard_B2s"
    }

]