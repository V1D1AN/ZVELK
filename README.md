# ZVELK

# Prerequisites

Solution works with Linux <br />
⚠️ You must have on your system "docker" with "docker compose v2", and "jq" <br />
For Docker Compose v2, you must go on "https://docs.docker.com/compose/" <br />

On Linux, you must have in the "/etc/sysctl.conf" the line:

```
vm.max_map_count=262144
```

# Physical

You must have: 
* 4 Go Ram
* More than 20 Go of HDD in SSD ( Very Important for SSD )
* 4 cpu
* 1 network for management

# Installation

log in to your system as « root »

```
git clone https://github.com/V1D1AN/ZVELK.git
cd ZVELK
```

After, run the command:
```
bash 00_create_instance.sh
```

# Clean installation

log in to your system as « root »

```
cd ZVELK
bash 99_cleanup_all.sh
```
