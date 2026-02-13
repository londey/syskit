# Interfaces

*Interface Design Description (IDD) for <system name>*

This directory contains the interface specifications — the authoritative record of **contracts** between components and with external systems.

## System Overview

<Brief description of the system: what it is, what it does, and its operational context.>

## Document Description

<Brief overview of what this document covers and how it is organized.>

## Purpose

Each interface document defines a precise contract: data formats, protocols, APIs, or signal definitions that components agree on. Interfaces are the bridge between requirements (what) and design (how), ensuring components can be developed and tested independently.

Interface types:

- **Internal** — Defined by this project (register maps, packet formats, internal APIs)
- **External Standard** — Defined by an external spec (PNG, SPI, USB)
- **External Service** — Defined by an external service (REST API, cloud endpoint)

## Conventions

- **Naming:** `int_NNN_<name>.md` — 3-digit zero-padded number, lowercase, underscores
- **Create new:** `.syskit/scripts/new-int.sh <name>`
- **Cross-references:** Use `INT-NNN` identifiers (derived from filename)
- **Parties:** Each interface has a Provider and one or more Consumers

## Table of Contents

<!-- TOC-START -->
*Run `.syskit/scripts/toc-update.sh` to generate.*
<!-- TOC-END -->
