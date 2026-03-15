# Ansible Structure

File wiht default password and private ssh key would need to exist prior running the playbook for the first time with these then being referenced in the playbook itself. If the password fails it will failover to the key. 

Ansible would test private key works prior to disabling password auth with something like
```yml
- name: Verify key auth works before disabling password auth
  ansible.builtin.ping:
  vars:
    ansible_password: ""
    ansible_ssh_private_key_file: ~/.ssh/id_rsa
```

playbooks would look like this
```yml
[defaults]
vault_password_file = ~/.vault_pass
private_key_file = ~/.ssh/id_rsa

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
```



## Inventory
### hosts.yml
contains host specific configurations
### group_vars/all_nodes.yml
standard config that would apply to all home lab nodes regardless of what they are being deployed for
### group_vars/k3s_nodes.yml
standard configs for nodes that are designed to be apart of the k3s cluster

## Roles
### /k3s
#### /tasks/main.yml
All tasks related to a node that is a part of the k3s cluster
#### /handlers/main.yml
All service or daemon restart or reload tasks, fire only if something changed in the task to prevent service bouncing for no reason

### /standard
#### /tasks/main.yml
All tasks related to any node that will be deployed to the home lab
#### /handlers/main.yml
All service or daemon restart or reload tasks, fire only if something changed in the task to prevent service bouncing for no reason

## Site.yml
Ansible Entry Point