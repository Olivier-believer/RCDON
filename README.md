# Rwanda Community Development Organization (RCDO)
## Production Data Management, Ingestion Pipeline & Analytics Platform

[![FastAPI](https://img.shields.io/badge/FastAPI-0.110+-009688.svg?style=flat&logo=fastapi)](https://fastapi.tiangolo.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16+-336791.svg?style=flat&logo=postgresql)](https://www.postgresql.org)
[![SQLAlchemy](https://img.shields.io/badge/SQLAlchemy-2.0+-D71F00.svg?style=flat&logo=sqlalchemy)](https://www.sqlalchemy.org)
[![Python](https://img.shields.io/badge/Python-3.11+-3776AB.svg?style=flat&logo=python)](https://www.python.org)
[![Coverage](https://img.shields.io/badge/API_Tests-100%25_Passing-brightgreen.svg)]()

---

## 1. Executive Summary & Problem Context

The **Rwanda Community Development Organization (RCDO)** is a national development organization implementing evidence-driven programs across all 30 districts of Rwanda. RCDO operates six core thematic programs:

1. **Education Program (EDU)**: Foundational literacy, school feeding, and rural digital smart classrooms.
2. **Agriculture Program (AGR)**: Climate-smart agriculture, farmer field schools, seed/fertilizer inputs, and market cooperatives.
3. **Health & Nutrition Program (HNT)**: Maternal & child nutrition, community health workers (CHW) diagnostics, and MUAC screenings.
4. **Water, Sanitation & Hygiene (WASH) Program (WSH)**: Solar pumping stations, borehole rehabilitation, protected springs, and community water management.
5. **Youth Employment Program (YEM)**: Technical & vocational training (TVET), digital freelancing incubators, and startup micro-grants.
6. **Social Protection & Livelihood Program (SPL)**: Village savings and loan associations (VSLAs) and conditional cash transfers (VUP-style).

### The Core Architectural Problem Solved
Traditional NGO information systems suffer from **data fragmentation and artificial beneficiary inflation**: when the same vulnerable citizen participates in Agriculture, WASH, and Social Protection, they are counted 3 separate times across disconnected project spreadsheets.

RCDO's platform introduces a **Master Beneficiary Index (MBI)** that assigns a single system-wide identity (`beneficiary_id`) linked to multiple program enrollments and service delivery records without data redundancy, while supporting heterogeneous data ingestion (CSV, Excel, KoBo/ODK JSON, APIs) and automated data quality controls.

---

## 2. System Architecture & End-to-End Data Flow

```mermaid
graph TD
    subgraph Heterogeneous Data Sources
        DS1[KoBoToolbox / ODK JSON Surveys]
        DS2[Excel Field Reports .xlsx]
        DS3[CSV Beneficiary Lists]
        DS4[Google Sheets Trackers]
        DS5[Partner REST APIs]
    end

    subgraph Data Pipeline & Ingestion Engine (Python ETL)
        E1[Extract Handlers]
        E2[Schema & Data Type Validation]
        E3[Rwanda District / Admin Standardization]
        E4[Master Beneficiary Deduplication]
        E5[Rejection Logging & data/rejected/ CSVs]
        E6[Transactional Database Upserter]
    end

    subgraph Relational Database & Warehouse Layer (PostgreSQL / SQLite)
        subgraph OLTP Transactional Layer (3NF)
            T_GEO[Geography: 5 Provinces, 30 Districts, Sectors, Cells, Villages]
            T_ORG[Organization, Programs, Projects, Donors, Partners, Staff]
            T_BEN[Master Beneficiaries, Households, Cross-Program Enrollments]
            T_ACT[Activities, Trainings, Distributions, GPS Water Points]
            T_FIN[Budgets, Allocations & Expenditures]
            T_ME[Indicators & Results]
            T_AUDIT[Ingestion Batches, Error Logs & RBAC Users]
        end
        subgraph OLAP Analytical Layer
            V_KPI[Materialized Impact KPIs]
            V_OVERLAP[Cross-Program Overlap Matrix]
            V_BURN[Project Financial Burn-Rate Analytics]
            V_DEPTH[Multi-Program Depth Index]
        end
    end

    subgraph Backend REST API (FastAPI)
        API_AUTH[JWT Authentication & RBAC]
        API_PUB[Public Telemetry & Impact Endpoints]
        API_INT[Internal Operations, M&E & Financial Endpoints]
        API_INGEST[File Upload & Ingestion Pipeline Triggers]
    end

    subgraph User Interfaces
        UI_PUB[Public Impact Web Portal: Dynamic Counters, Program Explorer, National Map]
        UI_ADMIN[Internal Operations & Analytics Dashboard: KPI Cards, Charts, Overlap Matrix, Registry]
    end

    DS1 --> E1
    DS2 --> E1
    DS3 --> E1
    DS4 --> E1
    DS5 --> E1

    E1 --> E2
    E2 -->|Valid| E3
    E2 -->|Invalid| E5
    E3 --> E4
    E4 -->|Clean Data| E6
    E4 -->|Duplicate/Conflict| E5
    E6 --> OLTP Transactional Layer

    OLTP Transactional Layer --> OLAP Analytical Layer
    OLAP Analytical Layer --> Backend REST API
    OLTP Transactional Layer --> Backend REST API

    Backend REST API --> UI_PUB
    Backend REST API --> UI_ADMIN
```

---

## 3. Database Schema & Relational Design

The database contains 7 cohesive functional domains designed in 3NF:

| Domain | Key Entities | Purpose |
|---|---|---|
| **1. Geography** | `dim_provinces`, `dim_districts`, `dim_sectors`, `dim_cells`, `dim_villages` | Hierarchical administrative data for all 30 districts of Rwanda. |
| **2. Organization** | `organizations`, `programs`, `projects`, `donors`, `partner_organizations`, `staff_members` | Institutional governance, donor grant allocations, and project timelines. |
| **3. Beneficiaries** | `households`, `beneficiaries`, `beneficiary_program_enrollments` | Master Citizen Index (MBI), 16-digit Rwandan NID format, and N:M cross-program enrollments. |
| **4. Implementation** | `activities`, `trainings`, `service_distributions`, `water_points`, `activity_participants` | Field interventions, attendance logs, and GPS-tagged water infrastructure. |
| **5. Financials** | `budgets`, `expenditures` | Multi-year budget lines vs. actual disbursements and burn-rate tracking. |
| **6. M&E / Logframe** | `indicators`, `indicator_results` | Quantitative quarterly targets vs. actual disaggregated achievements. |
| **7. Governance & Audit**| `ingestion_batches`, `ingestion_errors`, `users` | Automated audit logs, row-level ingestion errors, and JWT role-based access control. |

---

## 4. Key Cross-Program Analytics & Queries

### 1. Unduplicated National Reach
```sql
SELECT COUNT(DISTINCT beneficiary_id) AS total_unique_citizens 
FROM beneficiary_program_enrollments 
WHERE status = 'Active';
```

### 2. Cross-Program Beneficiary Overlap Matrix
```sql
SELECT 
    p1.name AS program_a, 
    p2.name AS program_b, 
    COUNT(DISTINCT e1.beneficiary_id) AS overlapping_beneficiaries
FROM beneficiary_program_enrollments e1
JOIN beneficiary_program_enrollments e2 
    ON e1.beneficiary_id = e2.beneficiary_id AND e1.program_id < e2.program_id
JOIN programs p1 ON e1.program_id = p1.program_id
JOIN programs p2 ON e2.program_id = p2.program_id
WHERE e1.status = 'Active' AND e2.status = 'Active'
GROUP BY p1.name, p2.name 
ORDER BY overlapping_beneficiaries DESC;
```

### 3. Multi-Program Depth Index
```sql
WITH counts AS (
    SELECT beneficiary_id, COUNT(DISTINCT program_id) AS num_programs
    FROM beneficiary_program_enrollments
    WHERE status = 'Active'
    GROUP BY beneficiary_id
)
SELECT num_programs, COUNT(*) AS total_beneficiaries,
       ROUND((COUNT(*)::DECIMAL / (SELECT COUNT(*) FROM counts)) * 100, 2) AS pct
FROM counts
GROUP BY num_programs
ORDER BY num_programs ASC;
```

---

## 5. Quick Start & Local Execution

### Prerequisites
* Python 3.10+ (Tested on Python 3.13)
* Git

### Step 1: Clone & Install Dependencies
```bash
git clone <repository_url>
cd "Full stack website"

# Install Python requirements
pip install -r backend/requirements.txt
```

### Step 2: Initialize Database & Seed Synthetic Rwanda Data
```bash
python scripts/init_db.py
```
*Outputs: 5 Provinces, 30 Districts, 6 Programs, 18 Projects, 650 Households, 2,800+ Master Beneficiaries, 4,180 Cross-Program Enrollments, GPS Water Points, and Budgets.*

### Step 3: Run Automated Backend Test Suite
```bash
python -m pytest -v tests/test_api.py
```
*(Asserts health check, public impact telemetry, JWT auth, RBAC permissions, and analytics queries).*

### Step 4: Launch Backend & Frontend Server
```bash
python -m uvicorn backend.app.main:app --host 127.0.0.1 --port 8000
```

### Step 5: Access Web Portals
* **Public Web Portal**: [http://127.0.0.1:8000](http://127.0.0.1:8000)
* **Internal Analytics Dashboard**: [http://127.0.0.1:8000/dashboard](http://127.0.0.1:8000/dashboard)
* **Interactive OpenAPI Swagger Docs**: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)

---

## 6. Default Demo Credentials & User Roles

| Role | Email | Password | Access Scope |
|---|---|---|---|
| **Administrator** | `admin@rcdo.org.rw` | `Admin@RCDO2026!` | Full access: All data, user management, file ingestion, financials. |
| **Agri Program Manager** | `manager.agri@rcdo.org.rw` | `Agri@RCDO2026!` | Agriculture program operations, beneficiaries, and budget logs. |
| **WASH Program Manager** | `manager.wash@rcdo.org.rw` | `Wash@RCDO2026!` | WASH program operations, water points, and infrastructure data. |
| **Data Officer** | `data.officer@rcdo.org.rw` | `Data@RCDO2026!` | Field data entry, file upload ingestion, and beneficiary registry. |
| **Public Auditor** | `viewer@rcdo.org.rw` | `Viewer@RCDO2026!` | Read-only access to internal M&E and analytics dashboards. |

---

## 7. Data Ingestion & ETL Pipeline CLI

You can execute the ETL pipeline directly on raw CSV, Excel, or KoBoToolbox JSON files:

```bash
# Ingest Agriculture Cooperative CSV
python data_pipeline/run_pipeline.py data/raw/agriculture_farmers_coop.csv

# Ingest KoBoToolbox JSON Survey Export
python data_pipeline/run_pipeline.py data/raw/kobo_survey_youth.json

# Ingest WASH Community Excel Workbook
python data_pipeline/run_pipeline.py data/raw/wash_community_survey.xlsx
```

*Valid records are cleaned, deduplicated, and committed to PostgreSQL/SQLite.*
*Rejected records with errors are saved to `data/rejected/batch_<id>_rejected.csv` and logged to `ingestion_errors` table.*

---

## 8. Docker Deployment

To launch the complete platform in production with containerized PostgreSQL 16:

```bash
docker-compose up -d --build
```
