# HashiCorp Vault blast radius scoring policy for terraform plan files

package terraform.analysis

import input as tfplan

import data.terraform

# acceptable score for automated authorization
blast_radius := default_blast_radius
default_blast_radius := 50
blast_radius := sprintf("%v", [opa.runtime().env.OPA_THRESHOLD]) {
	opa.runtime().env.OPA_THRESHOLD != ""
}

user_id := sprintf("%v", [opa.runtime().env.GITHUB_USER_ID]) {
	opa.runtime().env.GITHUB_USER_ID != ""
}

# weights assigned for each operation on each resource-type
weights = {
	"vault_ad_secret_backend": {"delete": 100, "create": 10, "modify": 10},
	"vault_ad_secret_backend_library": {"delete": 50, "create": 5, "modify": 10},
	"vault_ad_secret_backend_role": {"delete": 20, "create": 5, "modify": 1},
	"vault_ad_secret_role": {"delete": 20, "create": 5, "modify": 1},
	"vault_ad_secret_library": {"delete": 50, "create": 5, "modify": 10},
	"vault_approle_auth_backend_role": {"delete": 50, "create": 15, "modify": 15},
	"vault_audit": {"delete": 100, "create": 10, "modify": 100},
	"vault_auth_backend": {"delete": 100, "create": 10, "modify": 25},
	"vault_aws_auth_backend_role": {"delete": 50, "create": 1, "modify": 1},
	"vault_aws_auth_backend_sts_role": {"delete": 20, "create": 1, "modify": 5},
	"vault_aws_secret_backend": {"delete": 100, "create": 10, "modify": 20},
	"vault_aws_secret_backend_role": {"delete": 20, "create": 1, "modify": 5},
	"vault_egp_policy": {"delete": 50, "create": 1, "modify": 10},
	"vault_generic_endpoint": {"delete": 100, "create": 1, "modify": 20},
	"vault_generic_secret": {"delete": 100, "create": 1, "modify": 10},
	"vault_identity_entity": {"delete": 20, "create": 1, "modify": 1},
	"vault_identity_entity_alias": {"delete": 20, "create": 1, "modify": 1},
	"vault_identity_entity_policies": {"delete": 20, "create": 1, "modify": 10},
	"vault_identity_group": {"delete": 20, "create": 1, "modify": 1},
	"vault_identity_group_alias": {"delete": 20, "create": 1, "modify": 1},
	"vault_identity_group_member_entity_ids": {"delete": 10, "create": 1, "modify": 1},
	"vault_identity_group_policies": {"delete": 20, "create": 1, "modify": 10},
	"vault_jwt_auth_backend": {"delete": 100, "create": 10, "modify": 20},
	"vault_jwt_auth_backend_role": {"delete": 20, "create": 1, "modify": 5},
	"vault_kubernetes_auth_backend_config": {"delete": 20, "create": 10, "modify": 10},
	"vault_kubernetes_auth_backend_role": {"delete": 20, "create": 1, "modify": 5},
	"vault_mount": {"delete": 100, "create": 1, "modify": 5},
	"vault_namespace": {"delete": 100, "create": 1, "modify": 20},
	"vault_password_policy": {"delete": 50, "create": 10, "modify": 50},
	"vault_policy": {"delete": 20, "create": 1, "modify": 5},
	"vault_policy_document": {"delete": 5, "create": 1, "modify": 5},
	"vault_quota_rate_limit": {"delete": 20, "create": 1, "modify": 5},
	"vault_ldap_secret_backend": {"delete": 100, "create": 1, "modify": 20},
	"vault_ldap_secret_backend_dynamic_role": {"delete": 20, "create": 1, "modify": 5},
	"vault_ldap_secret_backend_library_set": {"delete": 20, "create": 1, "modify": 5},
	"vault_ldap_secret_backend_static_role": {"delete": 20, "create": 1, "modify": 5},
	"vault_pki_secret_backend_config_urls": {"delete": 50, "create": 1, "modify": 5},
	"vault_pki_secret_backend_role": {"delete": 100, "create": 1, "modify": 20},
	"vault_pki_secret_backend_config_cluster": {"delete": 100, "create": 1, "modify": 10},
	"vault_ssh_secret_backend_ca": {"delete": 20, "create": 1, "modify": 10},
	"vault_ssh_secret_backend_role": {"delete": 20, "create": 1, "modify": 10},
	"vault_token_auth_backend_role": {"delete": 20, "create": 1, "modify": 5},
	"vault_transit_secret_backend_cache_config": {"delete": 20, "create": 1, "modify": 10},
	"vault_transit_secret_backend_key": {"delete": 50, "create": 1, "modify": 50},
	"null_resource": {"delete": 5, "create": 1, "modify": 1},
}

#########
# Policy
#########

# Authorization holds if score for the plan is acceptable
default authz = false

authz {
	score < blast_radius
}

# Compute the score for a Terraform plan as the weighted sum of deletions, creations, modifications
score = s {
	all := [x |
		some resource_type
		crud := weights[resource_type]
		del := crud.delete * num_deletes[resource_type]
		new := crud.create * num_creates[resource_type]
		mod := crud.modify * num_modifies[resource_type]
		x := (del + new) + mod
	]

	s := sum(all)
}

####################
# Terraform Library
####################

# list of all resources of a given type
resources[resource_type] = all {
	some resource_type
	weights[resource_type]
	all := [name |
		name := tfplan.resource_changes[_]
		name.type == resource_type
	]
}

# number of creations of resources of a given type
num_creates[resource_type] = num {
	some resource_type
	weights[resource_type]
	all := resources[resource_type]
	creates := [res | res := all[_]; res.change.actions[_] == "create"]
	num := count(creates)
}

# number of deletions of resources of a given type
num_deletes[resource_type] = num {
	some resource_type
	weights[resource_type]
	all := resources[resource_type]
	deletions := [res | res := all[_]; res.change.actions[_] == "delete"]
	num := count(deletions)
}

# number of modifications to resources of a given type
num_modifies[resource_type] = num {
	some resource_type
	weights[resource_type]
	all := resources[resource_type]
	modifies := [res | res := all[_]; res.change.actions[_] == "update"]
	num := count(modifies)
}

# Rule to check if there are too many resource changes in the Terraform plan
too_many_resources = num {
	num := count(tfplan.resource_changes) > 500
}

# This rule calculates the percentage of the current state being modified
# percentage_modified = percent {
#   total_resources := count(tfplan.before.values.root_module.resources)
#   modified_resources := count([x | x := tfplan.resource_changes[_]; x.change.actions[_] != "no-op"])
#   percent := modified_resources * 100 / total_resources
# }

# List of all unknown resource types in the Terraform plan
unknown_resource_types := {
	res.type | res := tfplan.resource_changes[_]; not weights[res.type]
}

resource_in_scoring_list(resource) {
	weights[resource.type]
}

# Deny rule if there are any unknown resource types
deny[msg] {
	resource := tfplan.resource_changes[_]
	not resource_in_scoring_list(resource)
	msg := sprintf("Resource type '%s' not found in scoring list", [resource.type])
}

## Example deny rules

# deny[msg] {
# 	score > blast_radius
# 	msg := sprintf("Blast radius score %d is too high (threshold: %d)", [score, blast_radius])
# }

# deny[msg] {
# 	user_id == "eviltom"
# 	msg := sprintf("Current pipeline user %s is not authorized!", [user_id])
# }
