# aws_ecs_task_definition: diff on every plan when a container uses FireLens without `user`

Minimal reproduction for a `terraform-provider-aws` bug.

## Problem

When a container definition has a `firelensConfiguration` block and no `user`,
the Amazon ECS API stores the task definition with `"user": "0"` on that
container. Terraform compares the stored definition with the configuration,
sees `user` as a difference, and plans to **replace** the task definition on
every run, even though nothing changed.

## Reproduce

Requirements: Terraform >= 1.5 and an AWS CLI profile. Only one ECS task
definition is registered (no service, no tasks), so it costs nothing.

```bash
echo 'aws_profile = "<your-profile>"' > terraform.tfvars

terraform init
terraform apply      # registers revision 1
terraform plan       # expected: no changes
```

### Expected

```
No changes. Your infrastructure matches the configuration.
```

### Actual

Right after `terraform apply`, with no changes to the configuration
(Terraform 1.9.5, AWS provider 6.72.0):

```
  # aws_ecs_task_definition.repro must be replaced
-/+ resource "aws_ecs_task_definition" "repro" {
      ~ container_definitions    = jsonencode(
          ~ [
              ~ {
                  - environment      = []
                  - mountPoints      = []
                    name             = "app"
                  - portMappings     = []
                  - systemControls   = []
                  - volumesFrom      = []
                    # (3 unchanged attributes hidden)
                },
              ~ {
                  - environment           = []
                  - mountPoints           = []
                    name                  = "log_router"
                  - portMappings          = []
                  - systemControls        = []
                  - user                  = "0"
                  - volumesFrom           = []
                    # (3 unchanged attributes hidden)
                },
            ] # forces replacement
        )
        ...
    }

Plan: 1 to add, 0 to change, 1 to destroy.
```

The empty lists (`environment = []` and so on) are only shown as context. The
provider already treats them as equal to unset. `user = "0"` is the only real
difference: with `user = "0"` added to the `log_router` container, the same
`terraform plan` reports `No changes`.

### What ECS stored

```bash
aws ecs describe-task-definition --task-definition tf-firelens-user-repro \
  --query 'taskDefinition.containerDefinitions[?name==`log_router`].user'
```

```json
[
    "0"
]
```

The configuration never sets `user`, so ECS added it.

## Workaround

Set `"user": "0"` explicitly on the FireLens container.

## Clean up

```bash
terraform destroy
```

`terraform destroy` deregisters the revision, which then stays as INACTIVE.
INACTIVE revisions cost nothing. To remove them completely, run
`aws ecs delete-task-definitions --task-definitions tf-firelens-user-repro:<revision>`.

## Related

- hashicorp/terraform-provider-aws#41394: a fix that was proposed and closed without being merged
