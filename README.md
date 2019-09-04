# k8s_setup

This is a set of bash scripts to automatically set up a single-node bare metal kubernetes cluster. 

## Approach

The objective is to have a set of scripts that rely **just on bash** to deploy an on-prem kubernetes cluster. The code is supposed to be readable to a `bash` novice.

## Does this have bugs?

Probably. This code comes with no warranty or guarantees whatsoever. Feel free to create an issue if you find one.

## Prerequisites

At least two new CentOS installs, with static IP addresses, unique hostnames, and a `sudo` user names `centos-master`.

## End Result

- Base OS: `CentOS 7`
- Docker version: `docker-ce-18.06.2.ce`
- Kubeadm version: `1.15`
- Persisitent proxy configuration for `yum`, `docker` and master node `.bashrc`.
- MetalLB load balancer.
- Traefik reverse proxy ingress.
- NFS-backed client provisioner.
- Cockpit server and cluster management webUI, running on `master`.
- Minio object storage in distributed mode.
- Jupyterhub (two namespaces - sandbox, and workbench) with Gitlab OAuth.
- Airflow **not yet implemented**.
- Velero backup, backing up weekly to Minio.
- NFS backups, backing up weekly to Minio.

## Instructions

1. Clone this repo to your local machine.
2. Edit `set_variables.sh` to suit your environment.
3. Check that the `kubernetes_deploy.sh` script will install everything you want (comment out what you don't want)
4. `bash kubernetes_deploy.sh`
5. Enter ssh passwords a few times while keys get swapped around.


## Why not...?

### Why not SaltStack, or Ansible?

These bash scripts were built incrementally while I manually set up my personal cluster. There are **definitely** more efficient, flexible, configurable ways to do this. It works for me, and I think it's kinda cool that it's all just good 'ol bash.

### Why not EKS or GKE?

I was given a constraint - no cloud under any circumstances. If you have access to cloud, use it.

### Why not Kubernetes the hard way?

[Kubernetes the hard way](https://github.com/kelseyhightower/kubernetes-the-hard-way) is a great way to learn the ins and outs of how kubernetes works. This repo is not about learning things (or, I guess, it is about learning the quickest way to get up a bare-metal cluster :)). If you are studying for the Kubernetes Certified Administrator exam, go with Kubernetes the Hard Way.
