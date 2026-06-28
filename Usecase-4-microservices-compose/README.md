# Day 04 — Docker Compose for Local Microservices

> Building a production-inspired multi-service environment using Docker Compose — Flask, PostgreSQL, Redis, RabbitMQ, and Celery with health checks, secrets, and volume persistence.

---

## Overview

This project demonstrates how to orchestrate a complete local microservices environment using Docker Compose. The objective is to simulate a production-style setup where multiple interconnected services are managed through a single `docker-compose.yml` — with proper health checks, service dependencies, secrets management, and persistent volumes.

---

## Architecture

```
                User
                 │
                 ▼
          +-------------+
          |  Flask API  |
          +-------------+
           │     │     │
           ▼     ▼     ▼
      PostgreSQL Redis RabbitMQ
                         │
                         ▼
                  Celery Worker
```

---

## Services

| Service  | Technology    | Purpose                       |
|----------|---------------|-------------------------------|
| API      | Flask         | HTTP endpoints                |
| Database | PostgreSQL 17 | Persistent storage            |
| Cache    | Redis 8       | In-memory cache               |
| Queue    | RabbitMQ 4    | Message broker                |
| Worker   | Celery        | Background task processing    |

---

## Project Structure

```
microservices-compose/
├── api/
│   ├── app.py
│   ├── requirements.txt
│   └── Dockerfile
├── worker/
│   ├── worker.py
│   ├── requirements.txt
│   └── Dockerfile
├── secrets/
│   └── db_password.txt
├── docker-compose.yml
├── .env
└── README.md
```

# Without Docker Compose, every service must be wired up manually — network, volumes, images, and containers one by one.

```bash

# Network & volumes
docker network create microservices-network
docker volume create shared-data
docker volume create db-data

# Build images
docker build -t service-a ./service-a
docker build -t service-b ./service-b
docker build -t service-c ./service-c

# Run containers
docker run -d --name database --network microservices-network \
  -v db-data:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=password mysql:8

docker run -d --name service-a --network microservices-network \
  -v shared-data:/app/shared -p 8081:8080 service-a

docker run -d --name service-b --network microservices-network \
  -v shared-data:/app/shared -p 8082:8080 service-b

docker run -d --name service-c --network microservices-network \
  -v shared-data:/app/shared -p 8083:8080 service-c

# Verify
docker ps && docker network inspect microservices-network && docker volume ls

```
10 manual steps. Docker Compose replaces all of this with a single configuration file called docker-compose.yaml followed by docker compose up.
to make entire setup
---

#  Docker-compose.yaml

```bash
services:

  api:

    build: ./api

    ports:
      - "8080:5000"

    depends_on:  # Compose waits for dependencies.

      db:
        condition: service_healthy

      cache:
        condition: service_healthy

      queue:
        condition: service_healthy

    profiles:
      - app

    restart: always

  db:

    image: postgres:17

    environment:

      POSTGRES_USER: ${POSTGRES_USER}

      POSTGRES_DB: ${POSTGRES_DB}

      POSTGRES_PASSWORD_FILE:
        /run/secrets/db_password

    secrets:
      - db_password

    volumes:
      - postgres_data:/var/lib/postgresql/data

    healthcheck:

      test:
        [
          "CMD-SHELL",
          "pg_isready -U devuser -d appdb"
        ]

      interval: 10s

      retries: 5

      timeout: 5s

  cache:

    image: redis:8-alpine

    healthcheck:

      test:
        ["CMD","redis-cli","ping"]

      interval: 10s

      retries: 5

  queue:

    image: rabbitmq:4-management

    ports:

      - "15672:15672"

    healthcheck:

      test:
        [
          "CMD",
          "rabbitmq-diagnostics",
          "ping"
        ]

      interval: 10s

      retries: 5

  worker:

    build: ./worker

    depends_on:

      cache:
        condition: service_healthy

    restart: always

secrets:

  db_password:

    file: ./secrets/db_password.txt

volumes:

  postgres_data:
```
# Once docker file is written with required configuration then
bash
```
docker compose --profile app up 
```
<img width="2940" height="1148" alt="image" src="https://github.com/user-attachments/assets/4f121bff-278d-46f2-8cb3-7fcefbf6a03f" />

# Verification Steps

Verify Containers Started
bash
```
docker compose ps # check running services
```
<img width="2932" height="624" alt="image" src="https://github.com/user-attachments/assets/ccd1f11b-32bd-4b91-8eb7-e16d43421a47" />

Docker compose automatically provisioned a network
bash
```
docker network ls
```

<img width="2376" height="342" alt="image" src="https://github.com/user-attachments/assets/1cd2a034-3704-402b-be63-d1b0326a838b" />

Services are part of network created by docker compose.
```
docker network inspect network_name
```
<img width="1774" height="1478" alt="image" src="https://github.com/user-attachments/assets/0f42c3ac-efbe-4c7a-8faf-c55df1f9911b" />

Verify the secrets we have added in docker compose in the service by entering into db service
```
docker compose exec db sh
```
<img width="2668" height="366" alt="image" src="https://github.com/user-attachments/assets/fc971734-04ae-44a8-a28f-b5ba18beb217" />

Verify postgresql
bash
```
docker compose exec db psql -U devuser -d appdb
```
<img width="2934" height="1170" alt="image" src="https://github.com/user-attachments/assets/ab8414be-f798-47cf-8884-278568f81ef8" />

verify Redis

```
docker compose exec cache redis-cli
```
<img width="2842" height="364" alt="image" src="https://github.com/user-attachments/assets/719691a2-a838-49b9-a7bc-a2cc52c3210b" />

Verify RabbitMQ

Open the browser

```
http://localhost:15672
```
<img width="2900" height="1694" alt="image" src="https://github.com/user-attachments/assets/014d5c99-65a5-4dac-8d2c-fdefe57d4264" />

verify flask API

```
http://localhost:8080
```

<img width="2868" height="474" alt="image" src="https://github.com/user-attachments/assets/907dabaa-9cb6-47db-be00-347597242c85" />

Verify Internal DNS

 Docker Compose automatically provides internal DNS, enabling containers to communicate with each other using service names instead of IP addresses.

<img width="2786" height="1196" alt="image" src="https://github.com/user-attachments/assets/b7c15722-1f0e-45da-8c08-fbe6c26c6bf0" />


Verify profiles 

Profiles: Docker Compose profiles allow you to selectively start specific services for different environments such as development, testing, or monitoring.

bash
```
docker compose config --profiles
```
<img width="2798" height="198" alt="image" src="https://github.com/user-attachments/assets/f0f7d27b-989b-456a-be15-88c7ece36472" />






## Startup Workflow

```
docker-compose.yml
        │
        ▼
Creates Network → Creates Volumes → Creates Secrets
        │
        ▼
Starts PostgreSQL  →  [healthcheck: pg_isready]
        │
        ▼
Starts Redis       →  [healthcheck: PING]
        │
        ▼
Starts RabbitMQ    →  [healthcheck: management API]
        │
        ▼
Starts Flask API   →  Starts Celery Worker
        │
        ▼
Application Ready
```

---

## Health Checks

Health checks prevent race conditions by ensuring downstream services wait until dependencies are actually ready.

**PostgreSQL**
```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U devuser -d appdb"]
  interval: 10s
  timeout: 5s
  retries: 5
```

**Redis**
```yaml
healthcheck:
  test: ["CMD", "redis-cli", "ping"]
  interval: 10s
  timeout: 3s
  retries: 3
```

---

## Docker Compose Concepts

| Concept          | Purpose                                  | Example                        |
|------------------|------------------------------------------|--------------------------------|
| `services`       | Defines containers managed by Compose    | api, db, cache, worker         |
| `volumes`        | Persist data across container restarts   | `postgres_data:`               |
| `secrets`        | Securely inject sensitive credentials    | db_password from file          |
| `networks`       | Auto DNS using service names             | `db`, `cache`, `queue`         |
| `depends_on`     | Controls startup order                   | `condition: service_healthy`   |
| `restart`        | Auto-recover from failures               | `restart: always`              |
| `healthcheck`    | Detect service readiness                 | `pg_isready` / `redis PING`    |
| `profiles`       | Selectively start services               | `profiles: [dev, prod]`        |

---


** Inspect Logs**
```bash
docker compose logs api
docker compose logs worker
docker compose logs --follow
```

---

## Commands Reference

| Command                  | Purpose                                      |
|--------------------------|----------------------------------------------|
| `docker compose up -d`   | Start all services in detached mode          |
| `docker compose down`    | Stop and remove containers                   |
| `docker compose down -v` | Stop containers and delete volumes           |
| `docker compose ps`      | Show container status                        |
| `docker compose logs`    | View service logs                            |
| `docker compose build`   | Rebuild images                               |
| `docker compose exec`    | Execute a command inside a running container |
| `docker compose config`  | Validate the Compose configuration           |

---

## Key Learnings

- Multi-container orchestration with a single declarative file
- Docker networking enables service discovery using service names as DNS
- Health checks with `depends_on` prevent race conditions at startup
- Persistent volumes ensure data survives container restarts
- Docker secrets provide secure injection of sensitive credentials
- Celery + RabbitMQ pattern decouples background work from the API
- Restart policies keep services running in production-like scenarios
- Profiles allow selective service startup per environment

---

## Features Implemented

`Docker Compose` `Multi-container Orchestration` `Service Discovery` `Internal Networking`
`PostgreSQL Volumes` `Redis Cache` `RabbitMQ Queue`  `Health Checks`
`depends_on` `Environment Variables` `Docker Secrets` `Restart Policies` `Profiles`

---

*Building in public ·

`#Docker` `#DockerCompose` `#DevOps` `#Microservices` `#CloudEngineering` `#PlatformEngineering`
