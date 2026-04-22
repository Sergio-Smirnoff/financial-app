# Financial App

Welcome to the Financial App project. This repository serves as the central configuration point for the microservices and frontend that make up the application ecosystem.

## 📚 Documentation

The project documentation has been organized into specific directories to help you find what you need quickly:

### 1. 🏗️ Architecture & Backend
Detailed guides on how the backend microservices are structured and interact.
*   **[Overall Architecture](docs/architecture/ARCHITECTURE.md)**: High-level overview of the system, Kafka events, and service layout.
*   **[Finances Service](docs/architecture/ms-finances.md)**: Deep dive into the transaction and category processing engine.
*   **[Banks Service](docs/architecture/BanksImplementation.md)**: Guide on the banking module, cards, accounts, and loans.

### 2. 🖥️ Frontend
Analyses and inventories of the React/Next.js UI.
*   **[Component Inventory (Detailed)](docs/frontend/inventory-components-detailed.md)**: Exhaustive list of custom UI components, their purpose, and design system properties.
*   **[Frontend Analysis Report](docs/frontend/frontend-analysis-report.md)**: Refactoring roadmap, color scheme notes, and optimizations applied to the UI.

### 3. 🚀 Setup & Deployment
Instructions for running the project locally and deploying it to production.
*   **[Server Deployment Guide](docs/setup/DEPLOYMENT.md)**: **START HERE** if you are deploying to a new server. Covers Git workflow, Nginx proxy, RAM limits, and extensive Troubleshooting.

## 🛠️ Scripts

All operational scripts are located in the `scripts/` directory:

*   **`./scripts/dev.sh`**: The swiss-army knife for local development. Run `./scripts/dev.sh help` to see all available commands for hot-reloading microservices and frontend.
*   **`./scripts/deploy.sh`**: Production script to clone/pull all GitHub repositories and interactively generate `.env` files for new environments.
*   **`./scripts/backup.sh`**: Maintenance script to safely dump the PostgreSQL database and compress MinIO object storage.

---
*Built with Spring Boot, Next.js, Apache Kafka, and PostgreSQL.*
