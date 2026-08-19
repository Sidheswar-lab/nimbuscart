# NimbusCart - DevOps Project Report

## 1. Project Overview

NimbusCart is a three-tier product catalog application built as part of the DevOps assignment.

The application consists of:

* **Frontend:** HTML, CSS and JavaScript
* **Backend API:** Node.js with Express.js
* **Database:** MySQL
* **Containerization:** Docker
* **Infrastructure:** AWS and Terraform

The Express.js REST API handles the application logic and communicates with the MySQL database.

## 2. Local Application Setup

The application was first developed and tested locally before moving to AWS.

The backend provides the following endpoints:

* `GET /health`
* `GET /api/items`
* `POST /api/items`

The API automatically creates the `products` table when the application starts if the table does not already exist.

The database contains the following table:

```text
products(
    id,
    name,
    price,
    stock
)
```

The local application was tested with:

```text
GET /health       → 200 OK
GET /api/items    → []
POST /api/items   → Product created
GET /api/items    → Created product returned
```

## 3. Dockerization

The Express.js API is packaged into a Docker image using a Dockerfile and runs as a single Docker container.

For local development and testing, MySQL is also containerized. The API and MySQL containers communicate with each other through a Docker network.

This setup was tested locally before starting the AWS infrastructure work.

## 4. Manual VPC Peering Experiment

### 4.1 VPC Configuration

Two temporary VPCs were created manually in AWS to understand VPC peering and routing.

**VPC-A (test-1)**

* CIDR: `10.0.0.0/16`
* Subnet: `10.0.1.0/24`
* EC2 private IP: `10.0.1.122`

**VPC-B (test-2)**

* CIDR: `10.1.0.0/16`
* Subnet: `10.1.1.0/24`
* EC2 private IP: `10.1.1.86`

Both EC2 instances were configured with Nginx on port 80 so that connectivity could be tested using `curl`.

### 4.2 VPC Peering

A VPC peering connection was created between VPC-A and VPC-B.

The required routes were then added to both route tables:

**VPC-A route table:**

```text
10.1.0.0/16 → VPC Peering Connection
```

**VPC-B route table:**

```text
10.0.0.0/16 → VPC Peering Connection
```

After configuring the routes and security group rules, connectivity was successfully verified in both directions.

From VPC-A:

```bash
curl http://10.1.1.86
```

The Nginx welcome page was returned successfully.

From VPC-B:

```bash
curl http://10.0.1.122
```

The Nginx welcome page was also returned successfully.

This confirmed that the two VPCs could communicate using their private IP addresses through the peering connection.

### 4.3 Missing Return Route

To demonstrate the importance of the return route, the following route was intentionally removed from VPC-B's route table:

```text
10.0.0.0/16 → VPC Peering Connection
```

After removing this route, a connection test was performed from VPC-A:

```bash
curl http://10.1.1.86
```

The connection failed with a timeout:

```text
curl: (28) Failed to connect to 10.1.1.86 port 80
```

The same test from VPC-B to VPC-A also failed because VPC-B no longer had a route to the `10.0.0.0/16` network.

The experiment showed that a VPC peering connection alone is not enough. Appropriate routes are required in the route tables of both VPCs. When the return route is missing, traffic cannot correctly travel back to the source.

The missing route was then restored and connectivity was verified again.

### 4.4 Why the Database Subnet Does Not Need a NAT Gateway

A NAT Gateway is used when resources in a private subnet need to initiate connections to the public internet.

The database does not need a NAT Gateway simply because the application tier in another VPC needs to access it.

In the final architecture, the application can connect to the database through private networking and VPC peering:

```text
App EC2
   |
   | Private connection
   |
VPC Peering
   |
   |
Database
```

The database does not need to initiate connections to the internet. Therefore, it can remain in an isolated private subnet without a NAT Gateway.

The important distinction is:

* **Reachable from another VPC:** The application can initiate a connection to the database through private routes.
* **Can initiate connections to the internet:** The database itself would need an outbound path such as a NAT Gateway if internet access were required.

Therefore, VPC peering provides the required private connectivity to the database without requiring a NAT Gateway in the data VPC.

## 5. Terraform-Based AWS Infrastructure

After completing the manual VPC peering experiment, the final NimbusCart infrastructure was created using Terraform.

Terraform was used to provision the AWS networking, compute, security, and supporting resources required for the application.

### 5.1 Application VPC

The application infrastructure is deployed inside the following VPC:

* CIDR: `10.0.0.0/16`

The VPC contains two subnets:

* Web subnet: `10.0.1.0/24`
* App subnet: `10.0.2.0/24`

The Web subnet contains the Nginx/frontend EC2 instance, while the App subnet contains the Dockerized Node.js API.

### 5.2 Data VPC

The database infrastructure is isolated in a separate VPC:

* CIDR: `10.1.0.0/16`
* Data subnet: `10.1.1.0/24`

The MySQL database runs on an EC2 instance inside the Data VPC.

### 5.3 EC2 Instances

Three EC2 instances are used in the final architecture:

| Tier | Private IP | Purpose |
|---|---|---|
| Web | `10.0.1.200` | Nginx and frontend |
| App | `10.0.2.125` | Dockerized Node.js API |
| Data | `10.1.1.111` | MySQL database |

The Web EC2 instance has a public IP through which users access the application.

## 6. VPC Peering and Routing

Terraform creates a VPC peering connection between the Application VPC and Data VPC.

The Application VPC contains a route for the Data VPC:

```text
10.1.0.0/16 → VPC Peering Connection