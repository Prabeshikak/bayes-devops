## Question1: Using terraform (0.12) and the terraform module terraform-aws-vpc how would you create a production ready VPC? What are the design choices you make?

- Terraform modules will create a VPC with public / private subnet pairs across multiple availability zones. It will also create NAT gateways to allow outbound internet traffic for instances on the private subnets.

- Vpc and subnet-pair modules in the repo are responsible for creating the VPC, private and public subnets, NAT Gateways, routes, and security groups.

- A highly available cluster with Kubernetes masters in eu-central-1a, eu-central-1b, eu-central-1c is created.

- For networking infrastructure, hosted zone for our cluster domain name in Route53 is created.

- Kops also requires an S3 bucket for storing the state of the cluster. A bucket is created as part of our Terraform configuration.

- To create our infrastructure we need to provide credentials for an IAM user that has sufficient privileges to create all of these resources. I am using a user that has the following policies associated:

  - AmazonEC2FullAccess
  - IAMFullAccess
  - AmazonS3FullAccess
  - AmazonVPCFullAccess
  - AmazonRoute53FullAccess

## Question 2: How would you create a kubernetes cluster on this VPC? What are the design choices you make? You can use any tool you want (except EKS, Rancher, Supergiant).

- At this point, VPC is created. We will create some environment variable that is to be used in the subsequent steps.

      export NAME=$(terraform output cluster_name)

      export KOPS_STATE_STORE=$(terraform output state_store)

      export ZONES=eu-central-1a,eu-central-1b,eu-central-1c

  Alternatively we could also use `jq` retrieve zones from terraform output.

      export ZONES=$(terraform output -json availability_zones | jq -r '.value|join(",")')

- Validating that the $NAME and $KOPS_STATE_STORE variables are populated by our Terraform outputs.

      $ echo $NAME` production.Demo.com
      $ echo $KOPS_STATE_STORE` s3://Demo.com-state

- Using KOPS Command to create the cluster,

      kops create cluster
      --master-zones $ZONES
      --zones $ZONES
      --topology private
      --dns-zone $(terraform output public_zone_id)
      --networking calico
      --vpc $(terraform output vpc_id)
      --target=terraform
      --out=.
      \${NAME}

- Edit configuration to replace subnets section with actual vpc and subnet information that was created

      kops edit cluster \${NAME}

- After editing and saving our cluster configuration with the updated subnets section, update the cluster configuration stored in the S3 state store.

      kops update cluster
      --out=.
      --target=terraform
      \${NAME}

- `Terraform plan` to see everthing is fine.

- `Terraform apply -var name=production.Demo.com` to get the fully functional kubernetes cluster

- `kops validate cluster`

## Question 3: How would you deploy Istio to this cluster? Please provide some instructions.

- Download istio from the official page and add istioctl client to PATH

- Check the earlier created kubenetes cluster
  `kubectl get nodes`
  `kubectl get ns`

- Verify if the created cluster is suitable for istio installation
  `instioctl verify install`. If everything goes well, below mesage should appear
  `Cluster is ready for istio installation`

- To install, we need to choose one of the profile. For production we would generally choose default.

  `istioctl manifest apply --set profile=demo`

- Generate a manifest file of components
  `istioctl manifest generate --set profile=demo > istio.yaml`

- Check if `istio-system` namespace is populated,
  `kubectl get ns`,

- Check if containers are getting created.
  `watch -x kubectl -n istio-system get pods`

- Verify if istio is installed successfully
  `istioctl verify-install -f istio.yaml`

- As futher test check if Kiali pops up.
  `istioctl dashboard kiali`

## Question 4: How would you respond and resolve a situation where you have utilization imbalance in your cluster where one node is critically overloaded?

There are different solutions to make the node utilization balanced; according to the design aspect.
The Kubernetes scheduler’s default behavior works well for most cases as it ensures that pods are only placed on nodes that have sufficient free resources, it ties to spread pods from the same set (ReplicaSet, StatefulSet, etc.) across nodes.

But there may be times when cluster gets imbalanced such as one node is critically getting overloaded; then it can happen again and again with same or other nodes:

- I need to gather data from all parts of the Kubernetes cluster, to get a high-level view of cluster health and get insights such as resource utilization, configuration mistakes, and other issues in real-time.

- Need to review Pod Distribution Across Nodes with the help of advanced scheduling features: node affinity/anti-affinity, taints and tolerations, pod affinity/anti-affinity, custom schedulers, resource Hard limits and selectors that are there in my design and optimize them.

- Look back at our limit and request settings. If our scheduler doesn’t have the right information about what pods need, it is going to do a bad job of scheduling and end up all pods crowding in one node.

- Set CPU and Memory Requests and Limits on all Pods.Kubernetes will not allow our pod to use more CPU and memory than we have defined in the limit.

- Audit Provisioned Resources: We need to check if we have under or over-provisioned our resources. If we have a surplus of available CPU and memory, then we are under consuming, and likely paying too much. On the other hand, if we are getting close to 100 percent utilization, we might run into problems when we need to scale or have an unexpected load.