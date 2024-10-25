# WordPress Deployment on AWS ECS

This repository contains the code and configuration files for deploying a scalable, secure, and highly available WordPress application using Docker on AWS ECS. The infrastructure is provisioned using Terraform, and the deployment process is automated with GitHub Actions.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Terraform Configuration](#terraform-configuration)
- [GitHub Actions Workflow](#github-actions-workflow)
- [Accessing WordPress](#accessing-wordpress)
- [Monitoring and Logging](#monitoring-and-logging)
- [Cleanup](#cleanup)
- [Contributing](#contributing)
- [License](#license)

## Overview

The goal of this project is to deploy a WordPress application on AWS ECS with the following features:

- **Scalability**: Automatically scales the application based on traffic.
- **High Availability**: Runs across multiple availability zones.
- **Security**: Uses AWS Secrets Manager for database credentials.
- **Monitoring**: Implements AWS CloudWatch for logging and health monitoring.
- **Load Balancing**: Uses an Application Load Balancer (ALB) for distributing traffic.

## Architecture

The architecture includes the following AWS services:

- **Amazon ECS**: Manages the containerized WordPress application.
- **Amazon RDS**: Hosts the MySQL database.
- **Amazon ECR**: Stores the Docker image for the WordPress application.
- **AWS Secrets Manager**: Manages database credentials.
- **AWS CloudWatch**: Provides logging and monitoring capabilities.
- **Application Load Balancer (ALB)**: Distributes incoming traffic to the ECS service.

## Prerequisites

Before you begin, ensure you have the following:

- An AWS account.
- AWS CLI installed and configured with appropriate permissions.
- GitHub account to access the repository and set up GitHub Actions.
- Terraform installed on your local machine.

## Getting Started

1. **Clone the repository:**

   ```bash
   git clone git@github.com:becash143/Wordpress-ECS.git
   cd Wordpress-ECS
