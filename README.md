# Engelsystem - ETH DevCon Mumbai 2026 Edition

This repository holds the fully configured and branded **Engelsystem** deployment for **ETH DevCon Mumbai 2026** (November 3 - 6, 2026).

Engelsystem is the central portal for organizing, managing, and rewarding the incredible volunteers (Angels) who make the event possible. It handles shift scheduling, Angel Types, DECT phone integration, and T-shirt reward tracking.

## 🚀 Live Deployment
The production application is configured to auto-deploy via **Railway**. 
- **Production URL:** `https://angelsdevcon.up.railway.app`
- **Environment:** PHP 8.4-FPM + Nginx + MySQL 8.0

### Production Credentials
For initial setup testing, a default administrator is created:
- **User:** `admin`
- **Password:** `asdfasdf`
*(Please change this password immediately in production!)*

## 🛠 Features & Configuration
This specific fork has been heavily customized for ETH DevCon Mumbai 2026:
- **Branding Locked:** Deep database overrides force the "Engelsystem Pro" dark theme and strict "ETH DevCon Mumbai 2026" branding across the entire UI.
- **Automated Seeding:** On startup, the container automatically populates:
  - Official DevCon Dates: `2026-11-03` to `2026-11-06`
  - Global Configuration overrides
  - Standard Angel Types (Registration, Stage Tech, Info Desk, Workshop Support)
  - Pre-filled sample shifts for all 4 days.
- **Mumbai City Guide:** A comprehensive guide for volunteers is integrated directly at `/guide`, covering visas, neighborhoods, safety, and local tips.
- **MySQL Strict Mode Fix:** `ONLY_FULL_GROUP_BY` is disabled session-wide to support legacy aggregate queries without crashing under Railway's default strict MySQL 8.0 settings.

## 📚 Angel Guide
To understand how volunteers should interact with this system, refer to the official Chaos Angel Guide:
[Angel Guide (c3heaven.de)](https://angelguide.c3heaven.de)

## 💻 Local Development Setup

If you need to run this repository locally for testing or modifying Twig templates:

### Using Docker (Recommended)
1. Install Docker Desktop.
2. Clone this repository.
3. Run:
   ```bash
   cd docker
   docker compose up -d
   ```
4. Run migrations to initialize the database:
   ```bash
   docker compose exec es_server bin/migrate
   ```
5. Access the app at `http://localhost:8080`.

## 📜 Original License
This software is based on the open-source Engelsystem.
[![GPL](https://img.shields.io/github/license/engelsystem/engelsystem.svg?maxAge=2592000)](LICENSE)
