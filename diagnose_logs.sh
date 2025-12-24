#!/bin/bash
set -euo pipefail

# =============================================================================
# LOG DIAGNOSTIC TOOL
# Purpose: Analyze benchmark logs and show what data is missing
# =============================================================================

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <log_directory>"
    echo "Example: $0 benchmark_logs_server_20241222_083628"
    exit 1
fi

LOG_DIR="$1"

if [[ ! -d "$LOG_DIR" ]]; then
    echo "Error: Directory not found: $LOG_DIR"
    exit 1
fi

echo "========================================"
echo "BENCHMARK LOG DIAGNOSTICS"
echo "Directory: $LOG_DIR"
echo "========================================"
echo ""

# Function to check and display CSV contents
check_csv() {
    local file="$1"
    local description="$2"
    
    echo "--- $description ---"
    if [[ -f "$file" ]]; then
        echo "✓ File exists"
        echo "Contents:"
        cat "$file"
        echo ""
    else
        echo "✗ File missing: $file"
        echo ""
    fi
}

# Function to check JSON and extract key fields
check_json() {
    local file="$1"
    local description="$2"
    local operation="$3"  # read or write
    
    echo "--- $description ---"
    if [[ -f "$file" ]]; then
        echo "✓ File exists"
        echo ""
        echo "Extracted values:"
        
        # Try to extract IOPS
        echo -n "  IOPS: "
        grep -A50 "\"${operation}\" :" "$file" | grep '"iops" :' | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "NOT FOUND"
        
        # Try to extract bandwidth (in KBps)
        echo -n "  BW (KBps): "
        grep -A50 "\"${operation}\" :" "$file" | grep '"bw" :' | head -1 | grep -oE '[0-9]+' | head -1 || echo "NOT FOUND"
        
        # Try to extract latency
        echo -n "  Latency (ns): "
        grep -A50 '"lat_ns" :' "$file" | grep '"mean" :' | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "NOT FOUND"
        
        echo ""
        echo "First 30 lines of JSON structure:"
        head -30 "$file"
        echo ""
    else
        echo "✗ File missing: $file"
        echo ""
    fi
}

# Check system info
echo "========== SYSTEM INFO =========="
if [[ -f "$LOG_DIR/00_system_info.txt" ]]; then
    echo "✓ System info exists"
    grep -E "Hostname|CPU|Memory" "$LOG_DIR/00_system_info.txt" | head -5
else
    echo "✗ System info missing"
fi
echo ""

# Check CPU tests
echo "========== CPU TESTS =========="
check_csv "$LOG_DIR/01_cpu_multicore.csv" "CPU Multi-core"

if [[ -f "$LOG_DIR/01_cpu_multicore_raw.log" ]]; then
    echo "Raw stress-ng output:"
    echo ""
    grep -E "cpu|bogo" "$LOG_DIR/01_cpu_multicore_raw.log" | head -10
    echo ""
fi

check_csv "$LOG_DIR/02_cpu_singlecore.csv" "CPU Single-core"

if [[ -f "$LOG_DIR/02_cpu_singlecore_raw.log" ]]; then
    echo "Raw sysbench output:"
    echo ""
    grep -E "events|time" "$LOG_DIR/02_cpu_singlecore_raw.log" | head -5
    echo ""
fi

# Check RAM test
echo "========== RAM TEST =========="
check_csv "$LOG_DIR/03_ram.csv" "RAM Performance"

if [[ -f "$LOG_DIR/03_ram_raw.log" ]]; then
    echo "Raw stress-ng output:"
    echo ""
    tail -20 "$LOG_DIR/03_ram_raw.log"
    echo ""
fi

# Check disk tests
echo "========== DISK TESTS =========="
check_csv "$LOG_DIR/04_disk_seq_read.csv" "Disk Sequential Read (CSV)"
check_json "$LOG_DIR/04_disk_seq_read.json" "Disk Sequential Read (JSON)" "read"

check_csv "$LOG_DIR/05_disk_seq_write.csv" "Disk Sequential Write (CSV)"
check_json "$LOG_DIR/05_disk_seq_write.json" "Disk Sequential Write (JSON)" "write"

check_csv "$LOG_DIR/06_disk_rand_read.csv" "Disk Random Read (CSV)"
check_json "$LOG_DIR/06_disk_rand_read.json" "Disk Random Read (JSON)" "read"

check_csv "$LOG_DIR/07_disk_rand_write.csv" "Disk Random Write (CSV)"
check_json "$LOG_DIR/07_disk_rand_write.json" "Disk Random Write (JSON)" "write"

echo "========== SUMMARY =========="
echo "Files present:"
ls -lh "$LOG_DIR"/*.{csv,json,txt,log} 2>/dev/null | wc -l
echo ""
echo "Total directory size:"
du -sh "$LOG_DIR"
echo ""
echo "========================================"
echo "Diagnostic complete!"
echo "========================================"
