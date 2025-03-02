# Cost Analysis for n8n on AKS

This document provides a detailed breakdown of the estimated costs for running the n8n deployment on Azure Kubernetes Service (AKS). All prices are in USD and based on Azure's [Pay-As-You-Go pricing](https://azure.microsoft.com/en-us/pricing/) as of March 2025.

## Table of Contents

- [Summary](#summary)
- [AKS Cluster Costs](#aks-cluster-costs)
- [Storage Costs](#storage-costs)
- [Networking Costs](#networking-costs)
- [Optional Services](#optional-services)
- [Cost Optimization Strategies](#cost-optimization-strategies)
- [Scaling Considerations](#scaling-considerations)

## Summary

**Estimated Monthly Cost: $168.70 - $220.40**

| Component | Monthly Cost (USD) | Notes |
|-----------|-------------------|-------|
| AKS Cluster (2 nodes) | $146.00 | D2s v3 VMs |
| Managed Disk Storage | $14.20 | 3 disks (128GB total) |
| Networking | $8.50 | Load Balancer + Outbound data |
| **Total Base Cost** | **$168.70** | Minimum configuration |
| Optional Services | $10.00 - $51.70 | Monitoring, backups, etc. |
| **Total with Options** | **$178.70 - $220.40** | Depending on options selected |

## AKS Cluster Costs

The AKS cluster is the primary cost component. The current deployment uses:

- 2 nodes with D2s v3 VMs (2 vCPUs, a4 GB RAM each)
- Standard support tier
- No upfront commitment

### Compute Costs

| Resource | Quantity | Price per Unit | Monthly Cost |
|----------|----------|----------------|--------------|
| D2s v3 VM | 2 | $73.00/month | $146.00 |
| AKS management fee | Free for basic cluster | $0.00 | $0.00 |
| **Total Compute** | | | **$146.00** |

### Alternatives

| VM Type | vCPUs | RAM | Monthly Cost (per node) | Monthly Cost (2 nodes) | Notes |
|---------|-------|-----|-------------------------|-------------------------|-------|
| B2s (Burstable) | 2 | 4 GB | $30.40 | $60.80 | Good for development/testing |
| D2s v3 (Current) | 2 | 8 GB | $73.00 | $146.00 | Balanced performance |
| D4s v3 | 4 | 16 GB | $146.00 | $292.00 | Higher performance |
| E2s v3 | 2 | 16 GB | $91.25 | $182.50 | Memory-optimized |

> **Recommendation**: For production with moderate workflow volumes, D2s v3 offers good balance. For testing or light workloads, B2s can reduce costs by ~58%.

## Storage Costs

The deployment uses Azure managed disks for persistent storage.

### Disk Costs

| Storage | Size | Type | Price per GB | Monthly Cost |
|---------|------|------|--------------|--------------|
| PostgreSQL data disk | 64 GB | Premium SSD | $0.13/GB | $8.32 |
| Redis data disk | 32 GB | Premium SSD | $0.13/GB | $4.16 |
| Cluster OS disks | 32 GB | Standard SSD | $0.054/GB | $1.72 |
| **Total Storage** | 128 GB | | | **$14.20** |

## Networking Costs

### Load Balancer and Data Transfer

| Component | Usage | Price | Monthly Cost |
|-----------|-------|-------|--------------|
| Standard Load Balancer | 1 | $0.025/hour | $18.00 |
| Outbound data transfer | 100 GB | $0.085/GB | $8.50 |
| Inbound data transfer | 100 GB | Free | $0.00 |
| **Total Networking** | | | **$26.50** |

> **Note**: Outbound data transfer costs vary by region and volume. The estimate above assumes 100GB of outbound data from East US region.

## Optional Services

These services add additional costs but provide important features:

### Monitoring and Management

| Service | Usage | Monthly Cost | Notes |
|---------|-------|--------------|-------|
| Azure Monitor | Basic | $0.00 | Limited metrics and logs |
| Azure Monitor | Container Insights | $10.00 | Per node monitoring |
| Log Analytics | 5 GB data | $11.70 | For log retention and analysis |

### Backup and Disaster Recovery

| Service | Usage | Monthly Cost | Notes |
|---------|-------|--------------|-------|
| Azure Backup | 100 GB | $10.00 | Database backups |
| Geo-redundant storage | 100 GB | $20.00 | For disaster recovery |

## Cost Optimization Strategies

### Immediate Optimizations

1. **Right-size your nodes**:
   - Use B-series VMs for development/testing environments
   - Scale down to a single node for non-critical deployments

2. **Reserved Instances**:
   - Commit to 1-year RI: ~41% savings ($86.07/month instead of $146.00)
   - Commit to 3-year RI: ~65% savings ($51.10/month instead of $146.00)

3. **Disk Optimization**:
   - Use Standard SSD instead of Premium SSD for non-production: ~58% savings
   - Reduce disk sizes if you don't need 64GB for PostgreSQL

### Operational Optimizations

1. **Auto-scaling**:
   - Configure Horizontal Pod Autoscaler (HPA) to scale efficiently
   - Use Cluster Autoscaler to scale down nodes during off-hours

2. **Lifecycle Management**:
   - Implement dev/test environments that auto-shutdown during non-business hours
   - Use Azure Dev/Test subscription for non-production environments (offers discounted rates)

3. **Traffic Management**:
   - Implement caching to reduce data transfer costs
   - Optimize webhook payload sizes to minimize bandwidth usage

## Scaling Considerations

As your workflow volume increases, costs will scale primarily in these areas:

| Scale Factor | Cost Impact | Optimization Strategy |
|--------------|-------------|------------------------|
| More workers | Linear increase in node costs | Use worker node pools with smaller instances |
| More workflows | Increased storage costs | Implement workflow retention policies |
| Higher traffic | Increased data transfer costs | Add Redis caching layer for frequent operations |
| Global users | Multi-region deployment | Use Azure Front Door for intelligent routing |

### Cost Projection for Growth

| Deployment Size | Nodes | Storage | Monthly Estimate | Notes |
|-----------------|-------|---------|------------------|-------|
| Small (Current) | 2 | 128 GB | $168.70 | 2 worker replicas |
| Medium | 4 | 256 GB | $322.40 | 4 worker replicas |
| Large | 8 | 512 GB | $630.80 | 8 worker replicas, higher traffic |

## Additional Resources

- [Azure Pricing Calculator](https://azure.microsoft.com/en-us/pricing/calculator/)
- [AKS Cost Optimization Best Practices](https://docs.microsoft.com/en-us/azure/aks/concepts-clusters-workloads)
- [Azure Cost Management](https://docs.microsoft.com/en-us/azure/cost-management-billing/costs/quick-acm-cost-analysis)

---

*Disclaimer: Prices are estimates only and may vary based on region, specific usage patterns, and Azure pricing changes. This document should be used for planning purposes only.*
