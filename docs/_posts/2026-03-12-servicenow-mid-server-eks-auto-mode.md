---
layout: single
title: "ServiceNow MID Server on AWS EKS Auto Mode with Pod Identity"
date: 2026-03-12
permalink: /servicenow-mid-server-eks/
categories: [aws, servicenow, eks]
tags: [eks, pod-identity, mid-server, servicenow, aws, cdk, discovery]
toc: true
toc_sticky: true
excerpt: "Run the ServiceNow MID Server in a container on EKS Auto Mode using a patched JAR for EKS Pod Identity - credential-less, pod-scoped, auto-rotated AWS credentials for cloud discovery."
header:
  overlay_color: "#2c3e50"
  overlay_filter: "0.5"
---

<link rel="stylesheet" href="{{ '/assets/css/custom.css' | relative_url }}">

> **Demo only** — This is a proof-of-concept. Do not deploy to production without vetting security guardrails and understanding the unsupported JAR patch.

## The Problem

ServiceNow MID Server discovers AWS resources by calling AWS APIs. It needs AWS credentials. The official MID Server only supports two methods: static IAM user keys and EC2 Instance Profile (IMDSv2). Neither works on EKS Auto Mode — there are no user-managed nodes for Instance Profiles, and static keys are a security anti-pattern.

EKS Pod Identity solves this by injecting temporary, pod-scoped credentials. But the MID Server's credential resolver doesn't know about Pod Identity. So we patch `mid.jar` to check Pod Identity first, with Instance Profile as fallback.

## AWS Credential Models for ServiceNow Cloud Discovery

<!-- Re-create the full table since Jekyll needs it in one block -->

<div class="credential-table-wrapper">
<table class="credential-table">
<thead>
<tr>
  <th>#</th>
  <th>Credential Model</th>
  <th>Runs On</th>
  <th>How It Works</th>
  <th>ServiceNow Support</th>
  <th>Trade-offs</th>
</tr>
</thead>
<tbody>
<tr class="row-static-keys">
  <td>1</td>
  <td><strong>AWS IAM User (Static Keys)</strong></td>
  <td>Anywhere</td>
  <td>Create an IAM user with programmatic access. Store Access Key ID and Secret Access Key in ServiceNow.</td>
  <td>Fully supported</td>
  <td><span class="trade-off-risk">&#9888;</span> <strong>Security risk</strong>: Long-lived credentials. Requires manual key rotation. Keys in ServiceNow add attack surface.</td>
</tr>
<tr class="row-instance-profile">
  <td>2</td>
  <td><strong>AWS EC2 Instance Profile</strong></td>
  <td>EC2 instance</td>
  <td>Attach an IAM role to the EC2 instance. ServiceNow uses credential-less discovery via IMDSv2. No keys stored.</td>
  <td>Fully supported</td>
  <td><span class="trade-off-warn">&#9881;</span> <strong>Management overhead</strong>: You own the EC2 lifecycle — OS patching, AMI hardening, capacity planning.</td>
</tr>
<tr class="row-irsa">
  <td>3</td>
  <td><strong>AWS IRSA</strong></td>
  <td>EKS standard mode</td>
  <td>Associate an IAM role with a K8s ServiceAccount via OIDC. Requires IMDS hop limit set to <code>2</code> on node group.</td>
  <td>Supported (with config)</td>
  <td><span class="trade-off-info">&#8505;</span> <strong>Node management</strong>: EKS standard mode requires managing node groups, AMIs, OS patching, kubelet upgrades.</td>
</tr>
<tr class="row-pod-identity">
  <td>4</td>
  <td><strong>AWS EKS Pod Identity</strong> <span class="badge-recommended">Most Secure</span> <span class="badge-maintenance">Patch Required</span></td>
  <td>EKS Auto Mode</td>
  <td>Associate an IAM role with a K8s ServiceAccount via Pod Identity. EKS injects credentials into the pod. Requires patching <code>mid.jar</code>.</td>
  <td>Not supported</td>
  <td><span class="trade-off-good">&#10003;</span> <strong>Most secure</strong>: Pod-scoped, auto-rotated, no static secrets. <span class="trade-off-warn">&#9881;</span> Requires unsupported JAR patch — re-patch on each MID Server upgrade.</td>
</tr>
</tbody>
</table>
</div>


## Why Pod Identity on EKS Auto Mode?

- EKS Auto Mode has no user-managed nodes, so EC2 Instance Profiles don't apply
- Pod Identity provides pod-scoped, temporary credentials with automatic rotation
- No static AWS keys to store, rotate, or leak
- The trade-off is the unsupported JAR patch — weigh this against your security and support requirements

## Architecture

The three-tier IAM role architecture mirrors ServiceNow's Model 3 (Accessor → Management → Member) discovery pattern. In production, these roles would be in separate AWS accounts. For this demo, all three live in the same account.

<div class="arch-diagram">
  <div class="arch-node arch-pod">
    <div class="arch-icon">&#9881;</div>
    <div class="arch-label">EKS Pod</div>
    <div class="arch-sublabel">MID Server</div>
  </div>
  <div class="arch-arrow">
    <div class="arch-arrow-line"></div>
    <div class="arch-arrow-text">EKS Pod Identity</div>
  </div>
  <div class="arch-node arch-role1">
    <div class="arch-icon">&#128273;</div>
    <div class="arch-label">Pod Identity Role</div>
    <div class="arch-sublabel">Accessor</div>
  </div>
  <div class="arch-arrow">
    <div class="arch-arrow-line"></div>
    <div class="arch-arrow-text">sts:AssumeRole</div>
  </div>
  <div class="arch-node arch-role2">
    <div class="arch-icon">&#128273;</div>
    <div class="arch-label">Management Role</div>
    <div class="arch-sublabel">Central Hub</div>
  </div>
  <div class="arch-arrow">
    <div class="arch-arrow-line"></div>
    <div class="arch-arrow-text">sts:AssumeRole</div>
  </div>
  <div class="arch-node arch-role3">
    <div class="arch-icon">&#128273;</div>
    <div class="arch-label">Discovery Role</div>
    <div class="arch-sublabel">Per Account</div>
  </div>
  <div class="arch-arrow">
    <div class="arch-arrow-line"></div>
    <div class="arch-arrow-text">Read-only APIs</div>
  </div>
  <div class="arch-node arch-resources">
    <div class="arch-icon">&#9729;</div>
    <div class="arch-label">AWS Resources</div>
    <div class="arch-sublabel">EC2, ECS, etc.</div>
  </div>
</div>

## What Gets Deployed

The CDK app deploys five stacks:

| Stack | Resources |
|-------|-----------|
| `EksMidServerEcrStack` | Private ECR repository with image scanning and lifecycle rules |
| `EksMidServerVpcStack` | VPC with 2 AZs, private subnets, NAT gateway |
| `EksMidServerClusterStack` | EKS Auto Mode cluster with control plane logging |
| `EksMidServerRolesStack` | Three-tier IAM roles: Pod Identity → Management → Discovery |
| `EksMidServerAppStack` | Namespace, ServiceAccount, Pod Identity association, ConfigMap, Secret, StatefulSet |

## Guide

The full step-by-step guide is split into two parts:

1. **[MID Server JAR Patching](https://github.com/ggund/servicenow-mid-server-eks/blob/main/servicenow/mid-server-jar-patching.md)** — Decompile `mid.jar`, add Pod Identity support, recompile, build Docker image, push to ECR
2. **[Deployment and Discovery Guide](https://github.com/ggund/servicenow-mid-server-eks/blob/main/servicenow/deployment-and-discovery-guide.md)** — Deploy CDK stacks, verify the MID Server, configure credential-less cloud discovery in ServiceNow

## Source Code

The complete CDK app, example Dockerfiles, and documentation are available in the [GitHub repository](https://github.com/ggund/servicenow-mid-server-eks).

---

*This is a demo/POC implementation. The `mid.jar` patching described here is unsupported by ServiceNow. See the [repository README](https://github.com/ggund/servicenow-mid-server-eks/blob/main/README.md) for full disclaimers.*
