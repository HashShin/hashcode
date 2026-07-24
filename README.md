# HASHCODE

Scanner for e‑commerce sites (Magento, WooCommerce, Shopify, etc.) to identify platform, payment methods, and checkout behavior.

## Install

### Android / Linux (one command)

```bash
curl -fsSL https://raw.githubusercontent.com/HashShin/hashcode/main/script/install.sh | sh
```

### Windows

Run in PowerShell:

```powershell
irm https://raw.githubusercontent.com/HashShin/hashcode/main/script/install.ps1 | iex
```

You can also download the latest binary from the
[releases page](https://github.com/HashShin/hashcode/releases/latest).


## Usage

1. Provide a text file with website URLs (one per line).
2. The tool scans each site for:

   * Platform type
   * Payment methods
   * Cart and checkout functionality
3. Results are saved to organized output files.

## Features

* Multi-threaded scanning
* Platform and payment detection
* Automatic retries on failures
* Resume from last progress
