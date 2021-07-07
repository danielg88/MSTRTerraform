Terraform Infrastructure for MicroStrategy Test Deployment on Azure
=====

Terraform configuration files for MicroStrategy Deployment on Azure.

This allows you to create as many Intelligence Servers and Webserver machines as needed. Inbound traffic to Webservers is handled by an Azure Application Gateway.

You can expect an infrastructure like the following:

![Example of the architecture that can be deployed with the configuration file](/diagram.png "Architecture Diagram")

* One virtual network with two subnets.  
* Virtual machines connected to the same private network.  
* One Application Gateway accesible from public IP Address.  
* Application Gateway traffic to port 80 redirected to webservers VMs port 8080. 

Virtual Machines use CentOS as OS and username is mstr, Ansible tags are added to help with MicroStrategy installation.


How to use
-----

Edit the [`terraform.tfvars`](/terraform.tfvars "Open file on GitHub") file to change the resource group name, azure region and the number and types of machines you want to deploy.

From the folder with the configuration run the following commands:

```bash 
terraform init 
terraform plan 
terraform apply
```


VMachines variable
---

You can specify the name, the size (Azure VM Sizes) and the role of each os the machines.

The following roles are allowed: `intelligence` or `webserver`