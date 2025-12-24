# v2p_benchmark
Performance Benchmarking Solution: Bare-Metal vs VPS

Quick Start
1. На каждом сервере (bare-metal и VPS)
bash# Скачать скрипты
chmod +x run.sh parse_results.sh

# Запустить тесты (требует sudo)
sudo ./run.sh
Время выполнения: ~10-15 минут
Результат: Директория benchmark_logs_<hostname>_<timestamp>/ с CSV логами

2. Собрать логи
bash# На bare-metal
tar czf baremetal_logs.tar.gz benchmark_logs_baremetal_*/

# На VPS
tar czf vps_logs.tar.gz benchmark_logs_vps_*/

# Скопировать на машину для анализа
scp user@baremetal:/path/baremetal_logs.tar.gz .
scp user@vps:/path/vps_logs.tar.gz .

3. Сравнить результаты
bash# Распаковать
tar xzf baremetal_logs.tar.gz
tar xzf vps_logs.tar.gz

# Парсить и сравнить
./parse_results.sh benchmark_logs_baremetal_* benchmark_logs_vps_*

Настройка параметров
Отредактируйте переменные в run.sh:
bashreadonly CPU_TEST_DURATION=60    # CPU stress duration (seconds)
readonly RAM_TEST_SIZE="4G"      # RAM allocation size
readonly DISK_TEST_SIZE="4G"     # Disk test file size
readonly DISK_TEST_DURATION=60   # Disk test duration
readonly FIO_IODEPTH=32          # I/O queue depth
Рекомендации:

RAM_TEST_SIZE: ~50% от общей RAM
DISK_TEST_SIZE: >= 2x RAM для точности
Увеличьте *_DURATION для стабильных метрик


Структура логов
benchmark_logs_<hostname>_<timestamp>/
├── 00_system_info.txt          # CPU/RAM/Disk info
├── 01_cpu_multicore.csv        # Multi-core stress
├── 02_cpu_singlecore.csv       # Single-core perf
├── 03_ram.csv                  # RAM + bandwidth
├── 04_disk_seq_read.csv        # Sequential read
├── 05_disk_seq_write.csv       # Sequential write
├── 06_disk_rand_read.csv       # Random read (4K)
├── 07_disk_rand_write.csv      # Random write (4K)
└── 08_network.csv              # Network placeholder
Каждый CSV содержит:
metric,value,unit
iops,12345,iops
bandwidth,678.90,MB/s

Критерии оценки
⚠️ Красные флаги (стоп-факторы)
МетрикаДеградацияРискCPU bogo ops/s>15%Throttling, noisy neighborsDisk random IOPS>30%Database performanceRAM bandwidth>20%Data processing tasks
✅ Приемлемые различия

CPU: ±10% (зависит от workload)
Sequential disk: ±15% (часто приемлемо)
RAM total/swap: без изменений


Network тестирование
Автоматический тест невозможен — требуется внешний endpoint.
Manual test:
На удалённом сервере:
bashiperf3 -s
На тестируемом сервере:
bash# TCP throughput
iperf3 -c <server_ip> -t 30 -i 1 -J > network_tcp.json

# UDP + jitter
iperf3 -c <server_ip> -u -b 1G -t 30 -J > network_udp.json
Парсинг:
bashgrep -A5 "sum_sent" network_tcp.json
grep "bits_per_second" network_tcp.json
Важные метрики:

Throughput (Mbps/Gbps)
Retransmits (TCP)
Jitter (UDP)
Packet loss


Troubleshooting
"Package not found"
bashapt-get update
apt-get install stress-ng fio iperf3 sysbench sysstat bc
"Permission denied"
bashsudo ./run.sh
"Disk space insufficient"
Уменьшите DISK_TEST_SIZE или очистите /tmp:
bashdf -h
rm -rf /tmp/fio*
Тесты fail с "throttled"
VPS может иметь CPU throttling — это важная метрика.
Проверьте в system_info.txt:
bashgrep "throttl" benchmark_logs_*/01_cpu_multicore_raw.log

Интерпретация результатов
Пример вывода парсера:
┌─ CPU PERFORMANCE ──────────────────────────────────────┐
Server               Workers    Bogo ops/s  Load Avg  Single ops/s
────────────────────────────────────────────────────────────────
baremetal                 16      45000.00     15.80      8500.00
vps                       16      38000.00     16.20      8100.00
────────────────────────────────────────────────────────────────
Difference                 -       -15.56%         -        -4.71%
└────────────────────────────────────────────────────────────────┘
Интерпретация:

-15.56% CPU: Критично если workload CPU-bound
Load > cores: нормально при stress-тесте
-4.71% single-core: приемлемо

Disk I/O:
Random Operations (4K):
Server               Read IOPS      Write IOPS
────────────────────────────────────────────
baremetal            12000.00        8000.00
vps                   4000.00        2500.00
────────────────────────────────────────────
Difference            -66.67%        -68.75%
Интерпретация:



50% деградация random IOPS: критично для БД


VPS обычно используют network-attached storage


Best Practices

Запускайте в off-peak hours — избегайте contention
Повторите тесты 3 раза — усредните результаты
Мониторьте во время тестов:

bash   watch -n 1 'mpstat 1 1; free -h; iostat -x 1 1'

Документируйте окружение:

RAID конфигурация (bare-metal)
Storage type (VPS: SAN/NAS/local SSD?)
Network: 1G/10G/25G?




Advanced: Multi-run aggregation
bash# 3 прогона на каждом сервере
for i in {1..3}; do
  sudo ./run.sh
  sleep 300  # 5 min cooldown
done

# Агрегация (требует доработки парсера)
./parse_results.sh benchmark_logs_baremetal_run1 \
                   benchmark_logs_baremetal_run2 \
                   benchmark_logs_baremetal_run3

Миграционное решение
GO для миграции если:

CPU: <10% деградация
Disk random: <20% (или workload не I/O intensive)
RAM: без swap pressure
Cost savings > performance loss

NO-GO если:

Databases with heavy random I/O
Real-time processing с CPU throttling
Критичная latency (check network!)

Hybrid подход:

Stateless apps → VPS
Databases → bare-metal
Batch jobs → spot/preemptible VPS


Support
Логи не парсятся?
bash# Проверьте формат
head -20 benchmark_logs_*/01_cpu_multicore.csv

# Должен быть CSV:
metric,value,unit
workers,16,cores
