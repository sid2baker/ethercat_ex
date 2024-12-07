# EthercatEx

This is a elixir wrapper for [EtherCAT](https://gitlab.com/etherlab.org/ethercat).

## Installation

### Ubuntu

```shell
export KEYRING=/usr/share/keyrings/etherlab.gpg
curl -fsSL https://download.opensuse.org/repositories/science:/EtherLab/Debian_12/Release.key | gpg --dearmor | sudo tee "$KEYRING" >/dev/null
echo "deb [signed-by=$KEYRING] https://download.opensuse.org/repositories/science:/EtherLab/Debian_12/ ./" | sudo tee /etc/apt/sources.list.d/etherlab.list > /dev/null
sudo apt-get update
sudo apt install ethercat-master libethercat-dev libfakeethercat-dev librtipc-dev
```

```shell
sudo ip link set <eth0> promisc on
sudo ip link set <eth0> up
sudo modprobe ec_master main_devices=<max-address>
sudo modprobe ec_generic
```
